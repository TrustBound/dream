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

### Connection Setup <a href="https://github.com/TrustBound/dream/blob/dream_postgres-2.0.0/modules/postgres/test/snippets/readme_connection_setup.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_postgres/client as postgres
import gleam/erlang/process
import gleam/otp/actor

pub fn database_config() -> postgres.Config {
  let pool_name = process.new_name("db_pool")
  postgres.new(pool_name)
  |> postgres.host("localhost")
  |> postgres.port(5432)
  |> postgres.database("myapp")
  |> postgres.user("postgres")
  |> postgres.password("secret")
  |> postgres.pool_size(15)
}

pub fn connect_database() -> Result(postgres.Connection, actor.StartError) {
  database_config()
  |> postgres.connect()
}
```

### Or from URL <a href="https://github.com/TrustBound/dream/blob/dream_postgres-2.0.0/modules/postgres/test/snippets/readme_connection_from_url.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_postgres/client as postgres
import gleam/erlang/process
import gleam/string

pub fn describe_url(url: String) -> String {
  let pool_name = process.new_name("db_pool")
  case postgres.parse_config(pool_name, url) {
    Ok(config) -> "Database " <> config.database <> " on " <> config.host
    Error(postgres.UnsupportedParameter(name)) ->
      "Unsupported parameter: " <> name
    Error(error) -> "Invalid URL: " <> string.inspect(error)
  }
}

pub fn connect_from_url() -> Result(postgres.Connection, postgres.FromUrlError) {
  postgres.from_url("postgresql://user:pass@localhost:5432/myapp")
}
```

`parse_config` reads the URL into a `Config` and does not connect. `from_url` reads the URL, sets a pool size of 15 and starts the pool. Both return a `Result`: a bad URL gives a `UrlError` value that says what is wrong, and no error holds the password.

The URL format is `postgresql://user:password@host:port/database`:

- The scheme is `postgresql` or `postgres`. The host and the database are required.
- The port defaults to 5432. Without a user, the default user `postgres` is kept.
- The user, the password and the database are percent-decoded. Encode `@`, `:` and `/` in a password as `%40`, `%3A` and `%2F`.
- Two query parameters are supported: `sslmode` (`disable`, `require`, `verify-ca` or `verify-full`) and `application_name`. Any other parameter gives `UnsupportedParameter`.

The pool connects to the database in the background. When no database listens at the URL, `from_url` still returns `Ok`, and each query returns `Error(pog.ConnectionUnavailable)`.

### Query Execution

Use with [Squirrel](https://hex.pm/packages/squirrel) or Pog directly:

#### Run a query with Pog <a href="https://github.com/TrustBound/dream/blob/dream_postgres-2.0.0/modules/postgres/test/snippets/readme_query_execution.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_postgres/client as postgres
import dream_postgres/query
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string
import pog

pub type User {
  User(id: Int, name: String)
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  decode.success(User(id:, name:))
}

pub fn find_user(
  db: postgres.Connection,
  id: Int,
) -> Result(postgres.Returned(User), postgres.QueryError) {
  pog.query("SELECT id, name FROM users WHERE id = $1")
  |> pog.parameter(pog.int(id))
  |> pog.returning(user_decoder())
  |> pog.execute(db)
}

pub fn list_users(
  db: postgres.Connection,
) -> Result(postgres.Returned(User), postgres.QueryError) {
  pog.query("SELECT id, name FROM users")
  |> pog.returning(user_decoder())
  |> pog.execute(db)
}

// Get first row
pub fn describe_user(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> String {
  case query.first_row(result) {
    Ok(user) -> "User " <> int.to_string(user.id) <> ": " <> user.name
    Error(query.NotFound) -> "No such user"
    Error(query.DatabaseError) -> "The database query failed"
  }
}

// Get all rows
pub fn describe_user_count(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> String {
  case query.all_rows(result) {
    Ok(users) -> int.to_string(list.length(users)) <> " users"
    Error(error) -> "The database query failed: " <> string.inspect(error)
  }
}
```

## Usage

### Connection Builder Pattern

Configure your database connection step by step:

#### Build a production config <a href="https://github.com/TrustBound/dream/blob/dream_postgres-2.0.0/modules/postgres/test/snippets/readme_connection_builder.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_postgres/client as postgres
import gleam/erlang/process
import gleam/otp/actor

pub fn production_config() -> postgres.Config {
  let pool_name = process.new_name("my_db_pool")
  postgres.new(pool_name)
  |> postgres.host("localhost")
  |> postgres.port(5432)
  |> postgres.database("myapp_prod")
  |> postgres.user("postgres")
  |> postgres.password("secret")
  // Max 20 connections
  |> postgres.pool_size(20)
}

pub fn connect_production() -> Result(postgres.Connection, actor.StartError) {
  production_config()
  |> postgres.connect()
}
```

### Query Result Helpers

The `query` module provides simple helpers for extracting data from Pog results:

#### Turn results into values <a href="https://github.com/TrustBound/dream/blob/dream_postgres-2.0.0/modules/postgres/test/snippets/readme_query_result_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_postgres/client as postgres
import dream_postgres/query
import gleam/list
import gleam/string

pub type User {
  User(id: Int, name: String)
}

// First row (for "get by ID" queries)
pub fn user_from_result(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> Result(User, String) {
  case query.first_row(result) {
    Ok(user) -> {
      // pog.returning already decoded the row to your type
      Ok(user)
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
}

// All rows (for "list" queries)
pub fn user_names_from_result(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> Result(List(String), String) {
  case query.all_rows(result) {
    Ok(users) -> {
      // Process all rows
      Ok(list.map(users, fn(user) { user.name }))
    }
    Error(error) -> {
      Error("Database error: " <> string.inspect(error))
    }
  }
}
```

### Error Handling

The `QueryError` type simplifies error handling:

#### Handle each QueryError <a href="https://github.com/TrustBound/dream/blob/dream_postgres-2.0.0/modules/postgres/test/snippets/readme_error_handling.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_postgres/query

pub fn explain_query_error(error: query.QueryError) -> String {
  case error {
    // Query succeeded but no rows
    query.NotFound -> "The query returned no rows"
    // Query failed (connection, SQL, etc.)
    query.DatabaseError -> "The query failed"
  }
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
- `postgres.parse_config(pool_name, url)` - Read a PostgreSQL URL into a config, or return a `UrlError`
- `postgres.from_url(url)` - Start a connection pool from a PostgreSQL URL, or return a `FromUrlError`

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
