# Changelog

All notable changes to `dream_postgres` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - 2025-11-20

### Added
- Initial beta release
- Builder pattern for PostgreSQL connection configuration
- `postgres.from_url()` - Connect from PostgreSQL connection URL
- `query.first_row()` - Extract first row from query result
- `query.all_rows()` - Extract all rows from query result
- Simplified error handling with `QueryError` type
- Integration with Pog for connection pooling

