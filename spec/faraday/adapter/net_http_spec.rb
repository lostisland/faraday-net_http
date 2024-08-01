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
end
