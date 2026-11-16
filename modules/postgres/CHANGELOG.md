# Changelog

All notable changes to `dream_postgres` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed (breaking)
- `postgres.from_url()` now returns `Result(Connection, FromUrlError)`.
  Before, it returned `Connection` and stopped the calling process with a
  `let assert` when the pool did not start, so a caller could not handle the
  failure.
  - Before: `pub fn from_url(url: String) -> Connection`
  - After: `pub fn from_url(url: String) -> Result(Connection, FromUrlError)`
  - Upgrade: handle the `Result`, for example
    `case postgres.from_url(url) { Ok(db) -> ... Error(error) -> ... }`.
- `postgres.from_url()` now returns `Error(InvalidUrl(UrlError))` for a URL it
  cannot read. Before, it used default values for the parts it could not
  find. URLs with a query parameter other than `sslmode` or
  `application_name`, a `sslmode` other than `disable`, `require`,
  `verify-ca` or `verify-full`, a fragment, no host or no database now give
  an error. Upgrade: remove the unsupported parts from the URL, or use the
  builder functions for those settings.

### Added
- `postgres.parse_config(pool_name, url) -> Result(Config, UrlError)` reads
  a connection URL into a `Config` and does not connect.
- `UrlError` says what is wrong with a URL: `MalformedUrl`, `MissingScheme`,
  `UnsupportedScheme`, `MissingHost`, `InvalidPort`, `MissingDatabase`,
  `InvalidDatabase`, `MissingUser`, `InvalidUserEncoding`,
  `InvalidPasswordEncoding`, `InvalidDatabaseEncoding`,
  `UnsupportedParameter`, `UnsupportedSslMode` and `UnsupportedFragment`.
- `FromUrlError` holds a `UrlError` or the reason the pool did not start:
  `InvalidUrl`, `PoolStartTimedOut`, `PoolStartFailed` and `PoolStartExited`.
  No error value holds the password.
- The `sslmode` query parameter sets the SSL mode, and `application_name`
  sets the PostgreSQL connection parameter with that name. An IPv6 host such
  as `[::1]` sets IPv6.

### Fixed
- `postgres.from_url()` read the user and the password wrongly. For
  `postgresql://user:pass@localhost:5432/myapp` it used the user `postgres`
  and no password. It now reads the URL with `gleam/uri` and gets the user
  `user` and the password `pass`. The user, the password and the database
  are percent-decoded.
- `postgres.from_url()` kept the query string in the database name. For
  `.../myapp?sslmode=require` the database was `myapp?sslmode=require`. The
  database is now `myapp`, and `sslmode` sets the SSL mode.

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
- Builder pattern for PostgreSQL connection configuration
- `postgres.from_url()` - Connect from PostgreSQL connection URL
- `query.first_row()` - Extract first row from query result
- `query.all_rows()` - Extract all rows from query result
- Simplified error handling with `QueryError` type
- Integration with Pog for connection pooling

