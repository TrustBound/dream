# Changelog

All notable changes to `dream_mock_server` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 - 2025-11-24

### Added

**Initial Release**
- General-purpose HTTP mock server for testing HTTP clients
- Programmatic control with `start(port)` and `stop(handle)` functions
- Comprehensive HexDocs documentation
- Full Cucumber integration test suite

**Non-Streaming Endpoints**
- `GET /` - Info page with endpoint documentation
- `GET /get` - Echo query parameters
- `POST /post` - Echo request body
- `GET /status/:code` - Return specified HTTP status code (200-599)
- `GET /json` - Sample JSON response
- `GET /text` - Plain text response
- `GET /uuid` - Generate and return UUID
- `GET /large` - Large response (1MB) for memory/performance testing
- `GET /empty` - Empty response body
- `GET /slow` - Delayed response (2 seconds) for timeout testing

**Streaming Endpoints**
- `GET /stream/fast` - 10 chunks at 100ms intervals
- `GET /stream/slow` - 5 chunks at 2s intervals
- `GET /stream/burst` - Random burst pattern (5-10 chunks, 100-500ms delays)
- `GET /stream/huge` - 100 chunks for memory/performance testing

### Design Decisions

**Port Management**
- Explicit port required via `start(port)` - no random port assignment
- Follows Dream's "explicit over implicit" philosophy
- Ensures predictable test behavior

**Standalone Mode**
- Standalone server entry point at `src/standalone.gleam` (not `main.gleam`)
- Avoids module name conflicts with example applications
- Hardcoded to port 3004 for manual testing

**Error Simulation**
- No transport-layer error simulation (connection drops, timeouts)
- Transport failures belong in a different testing layer
- Mock server focuses on HTTP protocol testing

### Notes

This module was created to eliminate external test dependencies (httpbin.org) and provide a reliable, fast, local testing environment for HTTP clients.


