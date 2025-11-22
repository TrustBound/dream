# Changelog

All notable changes to `dream_http_client` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.2 - 2025-11-21

### Changed
- Added HexDocs documentation badge to README

## 1.0.1 - 2025-11-22

### Fixed
- Fixed logo display on hex.pm by using full GitHub URL
- Added Dream logo to README

## 1.0.0 - 2025-11-21

### Added
- Initial stable release
- Builder pattern for HTTP request configuration
- `fetch.request()` - Non-streaming HTTP requests
- `stream.stream_request()` - Streaming HTTP requests with yielder
- Support for all HTTP methods (GET, POST, PUT, DELETE, etc.)
- HTTPS support via Erlang's httpc
- Header management (add, replace)
- Query string support
- Request body support

