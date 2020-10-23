# frozen_string_literal: true

require 'faraday'
require 'faraday/adapter/net_http'
require 'faraday/net_http/version'

module Faraday
  module NetHttp
  end
end

Faraday::Adapter.register_middleware(net_http: Faraday::Adapter::NetHttp)
