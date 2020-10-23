# frozen_string_literal: true

RSpec.describe Faraday::NetHttp do
  it 'has a version number' do
    expect(Faraday::NetHttp::VERSION).to be_a(String)
  end
end
