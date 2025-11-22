<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
  
  <a href="https://hexdocs.pm/dream_postgres">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
</div>

# dream_postgres

**PostgreSQL utilities for Gleam with type-safe query helpers.**

A standalone module providing clean interfaces for PostgreSQL operations using [Pog](https://hex.pm/packages/pog). Includes query result helpers and a builder pattern for connection management. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ Builder pattern for connection configuration
- ✅ Type-safe query result extraction
- ✅ Simplified error handling
- ✅ Connection pooling via Pog
- ✅ Zero dependencies on Dream or other frameworks

## Installation

```bash
gleam add dream_postgres
```

## Quick Start

### Connection Setup

```gleam
import dream_postgres/client as postgres
import gleam/erlang/process

let pool_name = process.new_name("db_pool")
let assert Ok(db) = postgres.new(pool_name)
  |> postgres.host("localhost")
  |> postgres.port(5432)
  |> postgres.database("myapp")
  |> postgres.user("postgres")
  |> postgres.password("secret")
  |> postgres.pool_size(15)
  |> postgres.connect()
```

### Or from URL

```gleam
import dream_postgres/client as postgres

let db = postgres.from_url("postgresql://user:pass@localhost:5432/myapp")
```

### Query Execution

Use with [Squirrel](https://hex.pm/packages/squirrel) or Pog directly:

```gleam
import dream_postgres/query
import user/sql  // Your Squirrel-generated queries

// Get first row
case sql.get_user(db, id) |> query.first_row() {
  Ok(user) -> decode_user(user)
  Error(query.NotFound) -> handle_not_found()
  Error(query.DatabaseError) -> handle_error()
}

// Get all rows
case sql.list_users(db) |> query.all_rows() {
  Ok(users) -> list.map(users, decode_user)
  Error(query.DatabaseError) -> handle_error()
}
```

## Usage

### Connection Builder Pattern

Configure your database connection step by step:

```gleam
import dream_postgres/client as postgres
import gleam/erlang/process

let pool_name = process.new_name("my_db_pool")
let config = postgres.new(pool_name)
  |> postgres.host("localhost")
  |> postgres.port(5432)
  |> postgres.database("myapp_prod")
  |> postgres.user("postgres")
  |> postgres.password("secret")
  |> postgres.pool_size(20)  // Max 20 connections

let assert Ok(db) = postgres.connect(config)
```

### Query Result Helpers

The `query` module provides simple helpers for extracting data from Pog results:

```gleam
import dream_postgres/query

// First row (for "get by ID" queries)
case sql.get_user(db, id) |> query.first_row() {
  Ok(row) -> {
    // Decode row to your type
    decode_user(row)
  }
  Error(query.NotFound) -> {
    // Query succeeded but no rows returned
    Error("User not found")
  }
  Error(query.DatabaseError) -> {
    // Query failed (connection error, SQL error, etc.)
    Error("Database error")
  }
}

// All rows (for "list" queries)
case sql.list_users(db) |> query.all_rows() {
  Ok(rows) -> {
    // Process all rows
    list.map(rows, decode_user)
  }
  Error(query.DatabaseError) -> {
    Error("Database error")
  }
}
```

### Error Handling

The `QueryError` type simplifies error handling:

```gleam
pub type QueryError {
  NotFound          // Query succeeded but no rows
  DatabaseError     // Query failed (connection, SQL, etc.)
}
```

This is much simpler than Pog's error types, making it easier to handle common cases.

## API Reference

### Client Configuration

- `postgres.new(pool_name)` - Create new config
- `postgres.host(config, host)` - Set database host
- `postgres.port(config, port)` - Set database port
- `postgres.database(config, name)` - Set database name
- `postgres.user(config, user)` - Set database user
- `postgres.password(config, password)` - Set database password
- `postgres.pool_size(config, size)` - Set connection pool size
- `postgres.connect(config)` - Start connection pool
- `postgres.from_url(url)` - Connect from PostgreSQL URL

### Query Helpers

- `query.first_row(result)` - Extract first row or `NotFound`
- `query.all_rows(result)` - Extract all rows (empty list if none)

## Design Principles

This module follows the same quality standards as [Dream](https://github.com/TrustBound/dream):

- **No nested cases** - Clear, flat control flow
- **No anonymous functions** - Named functions for clarity
- **Builder pattern** - Consistent, composable APIs
- **Type safety** - `Result` types force error handling
- **Quality testing** - Comprehensive test coverage

## About Dream

This module was originally built for the [Dream](https://github.com/TrustBound/dream) web toolkit, but it's completely standalone and can be used in any Gleam project. It follows Dream's design principles and will be maintained as part of the Dream ecosystem.

## License

MIT License - see LICENSE file for details.
