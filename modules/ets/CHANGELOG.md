# Changelog

All notable changes to `dream_ets` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 3.0.0 - Unreleased

### Fixed

- An operation on a table that was deleted raised the ETS `badarg` error and
  crashed the calling process, although the docs and `EtsError` said it
  returns `Error(TableNotFound)`. The FFI now catches `badarg`, checks that
  the table is gone, and returns `Error(TableNotFound)`. This applies to
  `set`, `get`, `delete`, `member`, `delete_table` (on a table that is
  already deleted), `size`, `keys`, `values`, `to_list`, `insert_new`,
  `take`, `update_element`, `delete_all_objects`, `match`, `match_object`,
  `select`, `save_to_file` (it returned `Error(OperationFailed("badtab"))`)
  and the counter helpers `increment`, `increment_by`, `decrement` and
  `decrement_by`. A `badarg` with another cause, on a table that exists (for
  example a bad match specification), is raised again as before.

### Breaking Changes

- `operations.member()` now returns `Result(Bool, EtsError)` instead of
  `Bool`, so that a deleted table is `Error(TableNotFound)` and not `False`.
- `operations.match()`, `operations.match_object()` and `operations.select()`
  now return `Result(List(Dynamic), EtsError)` instead of `List(Dynamic)`.
- In the `dream_ets/internal` module, `EtsFfiError` has a new
  `TableNotFound` variant, and `insert`, `delete_table`, `delete_key`,
  `delete_object`, `delete_all_objects`, `member`, `insert_new`, `match`,
  `match_object` and `select` (and their `ets_*` FFI functions) now return
  `Result(_, EtsFfiError)`.

**Upgrading:** where you used the `Bool` from `member()`, match on
`Ok(True)`, `Ok(False)` and `Error(_)`, or use it with
`use exists <- result.try(operations.member(table, key))`. Where you used the
list from `match()`, `match_object()` or `select()`, handle the `Result` in
the same way. Code that matched on `EtsFfiError` must handle
`TableNotFound`.

### Documentation

- The `member()` and `insert_new()` doc comment examples are now tested
  snippets, and the README's error-handling example has a test for its
  `TableNotFound` branch.

### Testing

- 104 tests, 0 failed, in about 0.3 seconds. Apple M1 Max, 10 cores, 64 GB, macOS 26.5.1, OTP 29, Gleam 1.17.0.

## 2.0.0 - 2025-12-08

### Breaking Changes

- `operations.keys()` now returns `Result(List(k), EtsError)` instead of `List(k)`
- `operations.values()` now returns `Result(List(v), EtsError)` instead of `List(v)`
- `operations.to_list()` now returns `Result(List(#(k,v)), EtsError)` instead of `List(#(k,v))`
- `operations.size()` now returns `Result(Int, EtsError)` instead of `Int`

**Migration Guide:**

```gleam
// Before (1.x):
let all_keys = operations.keys(table)

// After (2.x):
case operations.keys(table) {
  Ok(all_keys) -> use_keys(all_keys)
  Error(err) -> handle_error(err)
}
```

### Fixed

- **Critical:** Fixed `save_to_file()` FFI bug - filenames now properly converted from binary to charlist
- **Critical:** Fixed `load_from_file()` FFI bug - same charlist conversion issue
- **Critical:** Fixed `update_element()` FFI bug - now returns `{ok, nil}` instead of `ok`
- **Critical:** Fixed error handling in `keys()`, `values()`, `to_list()` - no more panics on decode errors
- Fixed error mapping in table creation to handle all `EtsFfiError` variants
- Fixed `ets_first()` FFI to return `empty_table` instead of `empty`

### Added

- **Documentation:** World-class hexdocs for every public function and type
- **Documentation:** Comprehensive examples showing real-world patterns (locks, queues, caching)
- **Documentation:** Performance notes and concurrency guidance throughout
- **Tests:** 100% test coverage of public API (77 tests across 10 suites)
- **Tests:** New test suites for persistence, encoders, helpers, advanced operations
- **Tests:** 9 verified, tested code snippets ready for documentation
- **Examples:** Custom type encoding with JSON
- **Examples:** Preventing duplicates with `insert_new()`
- **Examples:** Atomic operations for work queues
- Complete test coverage for:
  - `save_to_file()` / `load_from_file()` (previously untested!)
  - `update_element()`, `match()`, `match_object()`, `select()` (previously untested!)
  - Bool and float encoders (previously untested!)
  - Config options: `keypos()`, `table_type_bag()`, `table_type_duplicate_bag()` (previously untested!)

### Improved

- README completely rewritten with tested examples and proper error handling
- All error paths now properly handled - no more `Error(_)` patterns
- Better error messages for concurrent operations (e.g., "Key disappeared during iteration")
- Documentation examples now use proper Result-based error handling

### Internal

- Added `map_internal_error_to_ets()` helper for consistent error mapping
- Refactored collection functions to handle errors properly without panic
- Added `format_error()` in FFI to convert Erlang errors to strings

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
