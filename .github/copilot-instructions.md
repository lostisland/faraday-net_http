# Copilot Instructions

## Commands

- Install development dependencies: `bin/setup` (installs Bundler and runs `bundle install`).
- Run the normal local check: `bin/test`. It runs `bundle exec rubocop -a --format progress` followed by `bundle exec rspec`; the lint step can modify files.
- Run CI-equivalent linting without auto-correction: `bundle exec rubocop --format progress`.
- Lint one file: `bundle exec rubocop lib/faraday/adapter/net_http.rb`.
- Run all specs: `bundle exec rspec`.
- Run one file or example: `bundle exec rspec spec/faraday/adapter/net_http_spec.rb` or `bundle exec rspec spec/faraday/adapter/net_http_spec.rb:32`.
- Build the gem: `bundle exec rake build`.

CI lints once and tests against Ruby 3.0 through 3.4. The gemspec requires Ruby 3.0+ and pins the runtime `net-http` dependency to `~> 0.5`.

## Architecture

This repository is the standalone Faraday adapter gem for Ruby's `Net::HTTP`.

- `lib/faraday/net_http.rb` is the public entry point. It loads the implementation and registers `:net_http` with Faraday's adapter middleware registry, so users select it with `f.adapter :net_http`.
- `lib/faraday/adapter/net_http.rb` contains the adapter. `Faraday::Adapter::NetHttp` translates the Faraday request environment into `Net::HTTP`: it builds direct or proxied connections, applies SSL/request options, creates `Net::HTTPGenericRequest` instances, executes them (including streamed responses), then writes status, headers, reason phrase, and body back to the Faraday environment.
- The adapter maps transport failures to Faraday exceptions: SSL errors become `Faraday::SSLError`, supported Net::HTTP/socket errors become `Faraday::ConnectionFailed`, and timeout errors become `Faraday::TimeoutError`.
- `lib/faraday/net_http/version.rb` is the single version source used by the gemspec and release process. Releases are published from matching GitHub Releases after updating this constant.

## Repository Conventions

- Keep compatibility with the Ruby/Net::HTTP matrix: guard optional Net::HTTP and SSL APIs with `respond_to?` or `defined?`, as existing timeout, retry, hostname-verification, and OpenSSL handling does.
- Preserve the adapter's Faraday lifecycle: call `super` before performing the request, use `save_response` for response metadata, set `env.response_body`, and call `env.response.finish(env)`. Streaming requests must use `env.stream_response` and clear the raw Net::HTTP response body afterward.
- Execute requests through `Net::HTTP#start` with a block. The adapter deliberately does this so the TCP socket is closed correctly.
- Treat response bodies as mutable. Files use `# frozen_string_literal: true`; the empty-body fallback is `+''`, and encoded bodies are duplicated before `force_encoding`.
- Specs use RSpec's `expect` syntax with random order and load `spec_helper` automatically through `.rspec`. Adapter behavior is covered both by Faraday's shared `'an adapter'` contract and focused tests in `spec/faraday/adapter/net_http_spec.rb`; use WebMock for HTTP interactions.
- Follow `.rubocop.yml`: target Ruby 3.0 and use the configured `rubocop-packaging` and `rubocop-performance` rules. Existing complexity limits allow the adapter's compatibility logic to remain in one class.
