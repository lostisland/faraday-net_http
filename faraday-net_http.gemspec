# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'faraday/net_http/version'

Gem::Specification.new do |spec|
  spec.name = 'faraday-net_http'
  spec.version = Faraday::NetHttp::VERSION
  spec.authors = ['Jan van der Pas']
  spec.email = ['janvanderpas@gmail.com']

  spec.summary = 'Faraday adapter for Net::HTTP'
  spec.description = 'Faraday adapter for Net::HTTP'
  spec.homepage = 'https://github.com/lostisland/faraday-net_http'
  spec.license = 'MIT'

  spec.required_ruby_version = Gem::Requirement.new('>= 2.4.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/lostisland/faraday-net_http'
  spec.metadata['changelog_uri'] = "https://github.com/lostisland/faraday-net_http/releases/tag/v#{spec.version}"

  spec.files = Dir.glob('lib/**/*') + %w[README.md LICENSE.md]
  spec.require_paths = ['lib']

  spec.add_development_dependency 'faraday', '>= 1.0'
end
