# Changelog

All notable changes to `dream_ets` will be documented in this file.

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
- Type-safe ETS table interface
- Builder pattern for table configuration
- CRUD operations:
  - `operations.set()` - Insert or update key-value pair
  - `operations.get()` - Lookup value by key
  - `operations.delete()` - Delete key
  - `operations.member()` - Check if key exists
  - `operations.insert_new()` - Insert only if key doesn't exist
  - `operations.take()` - Get and delete atomically
- Collection operations:
  - `operations.keys()` - Get all keys
  - `operations.values()` - Get all values
  - `operations.to_list()` - Get all key-value pairs
  - `operations.size()` - Get table size
- Counter helpers:
  - `helpers.increment()` - Increment counter
  - `helpers.increment_by()` - Increment by amount
  - `helpers.decrement()` - Decrement counter
  - `helpers.decrement_by()` - Decrement by amount
- Convenience functions:
  - `ets.new_counter()` - Create counter table
  - `ets.new_string_table()` - Create string-to-string table
- Table persistence:
  - `operations.save_to_file()` - Save table to disk
  - `operations.load_from_file()` - Load table from disk
- Advanced features:
  - Pattern matching (`operations.match()`)
  - Match objects (`operations.match_object()`)
  - Select with match specifications (`operations.select()`)

