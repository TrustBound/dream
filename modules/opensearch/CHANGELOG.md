# Changelog

All notable changes to `dream_opensearch` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.1.0 - 2026-02-16

### Changed

- Updated to `dream_http_client` 5.0.0.
- `send_request` now properly routes HTTP error responses (4xx/5xx) to `Error(body)` instead of `Ok(body)`. The error string contains the response body, which typically includes error details from OpenSearch.
- Updated dependency constraint: `dream_http_client >= 5.0.0 and < 6.0.0`.

## 2.0.0

### Breaking Changes

- Bumped to match dream_http_client 4.x API changes.

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
- `client.new()` - Create OpenSearch client
- `document.index()` - Index documents
- `document.search()` - Search documents
- `document.delete()` - Delete documents
- `document.create_index()` - Create index with mapping
- `document.delete_index()` - Delete index
- `document.bulk()` - Bulk index operations
- Query builder helpers:
  - `query.match_all()` - Match all documents
  - `query.match()` - Full-text search
  - `query.term()` - Exact term match
  - `query.range()` - Range queries

