# frozen_string_literal: true

RSpec.describe Faraday::Adapter::NetHttp do
  features :request_body_on_query_methods,
           :reason_phrase_parse,
           :compression,
           :streaming,
           :trace_method

  it_behaves_like 'an adapter'

  context 'checking http' do
    let(:url) { URI('http://example.com') }
    let(:adapter) { described_class.new }
    let(:ssl) { Faraday::SSLOptions.new }
    let(:http) { adapter.send(:connection, url: url, request: {}, ssl: ssl) }

    it { expect(http.port).to eq(80) }

    it { expect(http).not_to be_use_ssl }

    it { expect(http.cert_store).to be_nil }

    it 'sets max_retries to 0' do
      adapter.send(:configure_request, http, {})

      expect(http.max_retries).to eq(0) if http.respond_to?(:max_retries=)
    end

    it 'supports write_timeout' do
      adapter.send(:configure_request, http, write_timeout: 10)

      expect(http.write_timeout).to eq(10) if http.respond_to?(:write_timeout=)
    end

    it 'supports open_timeout' do
      adapter.send(:configure_request, http, open_timeout: 10)

      expect(http.open_timeout).to eq(10)
    end

    it 'supports read_timeout' do
      adapter.send(:configure_request, http, read_timeout: 10)

      expect(http.read_timeout).to eq(10)
    end

    context 'with https url' do
      let(:url) { URI('https://example.com') }
      let(:ssl) do
        Faraday::SSLOptions.new.tap do |ssl|
          ssl.verify_hostname = true if ssl.respond_to?(:verify_hostname=)
        end
      end

      it { expect(http.port).to eq(443) }

      it { expect(http).to be_use_ssl }

      it { expect(http.cert_store).not_to be_nil }

      if Gem::Version.new(Faraday::VERSION) > Gem::Version.new('2.3.0') &&
         Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
        it 'supports verify_hostname option' do
          adapter.send(:configure_ssl, http, ssl)

          expect(http.verify_hostname).to eq(true)
        end
      end
    end

    context 'with http url including port' do
      let(:url) { URI('https://example.com:1234') }

      it { expect(http.port).to eq(1234) }
    end

    context 'with custom adapter config' do
      let(:adapter) do
        described_class.new do |http|
          http.continue_timeout = 123
        end
      end

      it do
        adapter.send(:configure_request, http, {})
        expect(http.continue_timeout).to eq(123)
      end
    end
  end

  context 'encoding' do
    let(:connection) do
      Faraday.new('http://example.com') { |conn| conn.adapter :net_http }
    end

    before do
      stub_request(:get, 'http://example.com')
        .to_return(
          status: 200,
          body: String.new('<msg>不在白名单内，请联系自我游</msg>', encoding: 'ASCII-8BIT'),
          headers: headers
        )
    end

    subject(:response) { connection.get }

    context 'when Content-Type charset is UTF-8' do
      let(:headers) { { 'Content-Type' => 'text/xml; charset=UTF-8' } }

      it { expect(response.body.encoding).to eq(::Encoding::UTF_8) }
    end

    context 'when Content-Type charset is ISO-8859-1' do
      let(:headers) { { 'Content-Type' => 'text/html; charset=ISO-8859-1' } }

      it { expect(response.body.encoding).to eq(::Encoding::ISO_8859_1) }
    end

    context 'when Content-Type charset is Shift_JIS' do
      let(:headers) { { 'Content-Type' => 'text/html; charset=Shift_JIS' } }

      it { expect(response.body.encoding).to eq(::Encoding::Shift_JIS) }
    end

    context 'when Content-Type is not given' do
      let(:headers) { {} }

      it { expect(response.body.encoding).to eq(::Encoding::ASCII_8BIT) }
    end

    context 'when Content-Type charset is unknown' do
      let(:headers) { { 'Content-Type' => 'text/xml; charset=BLABLA-8BIT' } }

      it { expect(response.body.encoding).to eq(::Encoding::ASCII_8BIT) }
    end

    context 'when Content-Type is empty' do
      let(:headers) { { 'Content-Type' => '' } }

      it { expect(response.body.encoding).to eq(::Encoding::ASCII_8BIT) }
    end

    context 'when Content-Type charset is UTF-8 and space' do
      let(:headers) { { 'Content-Type' => 'text/xml; charset= UTF-8 ' } }

      it { expect(response.body.encoding).to eq(::Encoding::UTF_8) }
    end
  end

  context 'when the response has no body and no Content-Type' do
    let(:adapter) { described_class.new }
    let(:http_response) do
      instance_double(Net::HTTPResponse, body: nil).tap do |response|
        allow(response).to receive(:[]).with('Content-Type').and_return(nil)
      end
    end

    it 'returns a mutable (non-frozen) body' do
      expect(adapter.send(:encoded_body, http_response)).not_to be_frozen
    end
  end

  context 'client certificate' do
    let(:adapter) { described_class.new }
    let(:url) { URI('https://example.com') }
    let(:http) { adapter.send(:connection, url: url, request: {}, ssl: ssl_options) }

    before do
      stub_request(:any, 'https://example.com')
    end

    context 'when client_cert is provided as an array' do
      let(:cert_array) { [OpenSSL::X509::Certificate.new, OpenSSL::X509::Certificate.new] }
      let(:ssl_options) do
        Faraday::SSLOptions.new.tap do |ssl_options|
          ssl_options.client_cert = cert_array
        end
      end

      it 'sets the first cert as cert and the rest as extra_chain_cert' do
        adapter.send(:configure_ssl, http, ssl_options)
      end

      it { expect(http.cert).to eq(cert_array.first) }

      it { expect(http.extra_chain_cert).to eq(cert_array[1..]) }
    end

    context 'when client_cert is provided as a single cert' do
      let(:cert) { OpenSSL::X509::Certificate.new }
      let(:ssl_options) do
        Faraday::SSLOptions.new.tap do |ssl_options|
          ssl_options.client_cert = cert
        end
      end

      it 'sets the cert as cert' do
        adapter.send(:configure_ssl, http, ssl_options)
      end

      it { expect(http.cert).to eq(cert) }

      it { expect(http.extra_chain_cert).to be_nil }
    end
  end

  context 'http proxy' do
    let(:adapter) { described_class.new }
    let(:url) { URI('https://example.com') }
    let(:proxy) { URI('http://proxy.example.com') }
    let(:proxy_options) do
      {
        uri: proxy,
        user: 'proxy_user',
        password: 'proxy_pass'
      }
    end
    let(:http) { adapter.send(:connection, url: url, request: { proxy: proxy_options }) }

    it { expect(http.proxy_address).to eq 'proxy.example.com' }

    it { expect(http.proxy_port).to be 80 }

    it { expect(http.proxy_user).to eq 'proxy_user' }

    it { expect(http.proxy_pass).to eq 'proxy_pass' }

    it { expect(http.instance_variable_get(:@proxy_use_ssl)).to be false }
  end

  context 'socks proxy' do
    let(:adapter) { described_class.new }
    let(:url) { URI('https://example.com') }
    let(:proxy_options) do
      {
        uri: URI('socks://proxy.example.com:1080'),
        user: 'proxy_user',
        password: 'proxy_pass'
      }
    end
    let(:http) { adapter.send(:connection, url: url, request: { proxy: proxy_options }) }

    it { expect(http).to be_a(Net::HTTP) }

    it { expect(http.class.socks_server).to eq 'proxy.example.com' }

    it { expect(http.class.socks_port).to eq 1080 }

    it { expect(http.class.socks_username).to eq 'proxy_user' }

    it { expect(http.class.socks_password).to eq 'proxy_pass' }

    it { expect(http.address).to be_a(TCPSocket::SOCKSConnectionPeerAddress) }

    it { expect(http.address.to_s).to eq 'example.com' }

    it 'does not share settings between proxies' do
      first = http
      second = adapter.send(:connection,
                            url: url,
                            request: { proxy: { uri: URI('socks://other.example.com:1081') } })

      expect(first.class).not_to eq(second.class)
      expect(first.class.socks_server).to eq 'proxy.example.com'
      expect(first.class.socks_username).to eq 'proxy_user'
      expect(second.class.socks_server).to eq 'other.example.com'
      expect(second.class.socks_username).to be_nil
    end

    it 'does not alter plain Net::HTTP' do
      http

      expect(Net::HTTP).not_to be_respond_to(:socks_server)
    end

    context 'when the SOCKS server rejects the connection' do
      let(:server) { TCPServer.new('127.0.0.1', 0) }
      let(:proxy_url) { "socks://127.0.0.1:#{server.addr[1]}" }
      let(:connection) do
        Faraday.new('http://localhost', proxy: proxy_url) { |conn| conn.adapter :net_http }
      end

      after { server.close }

      def serve_socks
        Thread.new do
          client = server.accept
          yield client
        ensure
          client&.close
        end
      end

      it 'raises Faraday::ConnectionFailed on a rejected destination' do
        serve_socks do |client|
          client.read(3) # version, method count, one method
          client.write([5, 0].pack('C2'))
          client.read(4 + 1 + 'localhost'.bytesize + 2)
          client.write([5, 5, 0, 1, 0, 0, 0, 0, 0, 0].pack('C10')) # connection refused
        end

        expect { connection.get }.to raise_error(Faraday::ConnectionFailed, /refused/i)
      end

      context 'with credentials' do
        let(:proxy_url) { "socks://user:pass@127.0.0.1:#{server.addr[1]}" }

        it 'raises Faraday::ConnectionFailed on an authentication failure' do
          serve_socks do |client|
            client.read(3) # version, method count, one method
            client.write([5, 2].pack('C2'))
            client.read(3 + 'user'.bytesize + 'pass'.bytesize)
            client.write([1, 1].pack('C2')) # authentication failed
          end

          expect { connection.get }.to raise_error(Faraday::ConnectionFailed, /authentication failed/i)
        end
      end
    end

    context 'when socksify is not loaded' do
      before { allow(Net::HTTP).to receive(:respond_to?).and_call_original }

      it 'raises a helpful error' do
        allow(Net::HTTP).to receive(:respond_to?).with(:socks_proxy).and_return(false)

        expect { http }.to raise_error(RuntimeError, /requires the socksify gem/)
      end
    end
  end

  context 'https proxy' do
    let(:adapter) { described_class.new }
    let(:url) { URI('https://example.com') }
    let(:proxy) { URI('https://proxy.example.com') }
    let(:proxy_options) do
      {
        uri: proxy,
        user: 'proxy_user',
        password: 'proxy_pass'
      }
    end
    let(:http) { adapter.send(:connection, url: url, request: { proxy: proxy_options }) }

    it { expect(http.proxy_address).to eq 'proxy.example.com' }

    it { expect(http.proxy_port).to be 443 }

    it { expect(http.proxy_user).to eq 'proxy_user' }

    it { expect(http.proxy_pass).to eq 'proxy_pass' }

    it { expect(http.instance_variable_get(:@proxy_use_ssl)).to be true }
  end
end
