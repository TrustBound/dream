<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
</div>

<div align="center">
  <a href="https://hex.pm/packages/dream_ets">
    <img src="https://img.shields.io/hexpm/v/dream_ets" alt="Hex Package">
  </a>
  <a href="https://hexdocs.pm/dream_ets">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
  <a href="https://github.com/TrustBound/dream/blob/main/modules/ets/LICENSE.md">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
  <a href="https://gleam.run">
    <img src="https://img.shields.io/badge/gleam-%E2%9C%A8-ffaff3" alt="Gleam">
  </a>
</div>

# dream_ets

**Type-safe ETS (Erlang Term Storage) for Gleam.**

A standalone module providing a type-safe interface to Erlang's ETS in-memory storage. Features a builder pattern for table configuration, type-safe operations, and comprehensive error handling. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ **Type-safe** - Keys and values are typed at compile time
- ✅ **Result-based errors** - All operations return `Result` for explicit error handling
- ✅ **Builder pattern** - Composable, fluent table configuration
- ✅ **Atomic operations** - `insert_new()`, `take()` for race-free operations
- ✅ **Custom types** - Store any type with custom encoders (JSON, tuples, etc.)
- ✅ **Pattern matching** - Advanced ETS queries and match specifications
- ✅ **Table persistence** - Save/load tables to disk
- ✅ **100% tested** - Comprehensive test coverage with verified examples
- ✅ **Zero dependencies** - No Dream or framework requirements

## Installation

```bash
gleam add dream_ets
```

## Quick Start

### Creating a Table

```gleam
import dream_ets/config
import dream_ets/operations
import gleam/option
import gleam/result

pub fn create_string_table() -> Result(String, table.EtsError) {
  // Create a table using the builder pattern
  use cache <- result.try(
    config.new("user_cache")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Use it
  use _ <- result.try(operations.set(cache, "alice", "Alice"))
  use value <- result.try(operations.get(cache, "alice"))

  case value {
    option.Some(name) -> Ok(name)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

<sub>🧪 [Tested source](test/snippets/creating_tables.gleam)</sub>

### Basic Operations

```gleam
import dream_ets/helpers
import dream_ets/operations
import gleam/option
import gleam/result

pub fn store_and_retrieve() -> Result(String, table.EtsError) {
  use cache <- result.try(helpers.new_string_table("cache"))

  // Store a value
  use _ <- result.try(operations.set(cache, "greeting", "Hello, World!"))

  // Retrieve it
  use value <- result.try(operations.get(cache, "greeting"))

  case value {
    option.Some(greeting) -> Ok(greeting)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

<sub>🧪 [Tested source](test/snippets/basic_operations.gleam)</sub>

### Counter Tables

```gleam
import dream_ets/helpers
import gleam/result

pub fn increment_page_views() -> Result(Int, table.EtsError) {
  use counter <- result.try(helpers.new_counter("page_views"))

  // Track multiple page views
  use _ <- result.try(helpers.increment(counter, "homepage"))
  use _ <- result.try(helpers.increment(counter, "homepage"))
  use count <- result.try(helpers.increment(counter, "homepage"))

  Ok(count)  // Returns 3
}
```

<sub>🧪 [Tested source](test/snippets/counter_tables.gleam)</sub>

## Core Features

### Custom Types with JSON

Store your own types using JSON encoding:

```gleam
import dream_ets/config
import dream_ets/internal
import dream_ets/operations
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result

pub type User {
  User(name: String, email: String)
}

fn encode_user(user: User) -> dynamic.Dynamic {
  json.object([
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
  |> json.to_string
  |> internal.to_dynamic
}

fn decode_user() -> decode.Decoder(User) {
  decode.string
  |> decode.then(fn(json_str) {
    case json.parse(json_str, user_from_json()) {
      Ok(user) -> decode.success(user)
      Error(_) -> decode.failure(User("", ""), "User")
    }
  })
}

fn user_from_json() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(name: name, email: email))
}

pub fn store_custom_type() -> Result(String, table.EtsError) {
  use users <- result.try(
    config.new("users")
    |> config.key_string()
    |> config.value(encode_user, decode_user())
    |> config.create(),
  )

  let user = User(name: "Alice", email: "alice@example.com")
  use _ <- result.try(operations.set(users, "alice", user))

  use retrieved <- result.try(operations.get(users, "alice"))

  case retrieved {
    option.Some(u) -> Ok(u.name <> " <" <> u.email <> ">")
    option.None -> Error(table.OperationFailed("User not found"))
  }
}
```

<sub>🧪 [Tested source](test/snippets/custom_types.gleam)</sub>

### Preventing Duplicates

Use `insert_new()` for atomic "check and insert" operations:

```gleam
import dream_ets/helpers
import dream_ets/operations
import gleam/result

pub fn register_user() -> Result(Bool, table.EtsError) {
  use registrations <- result.try(helpers.new_string_table("registrations"))

  // Try to register username
  use registered <- result.try(operations.insert_new(
    registrations,
    "alice",
    "alice@example.com",
  ))

  case registered {
    True -> Ok(True)   // Username available
    False -> Ok(False) // Username already taken
  }
}
```

<sub>🧪 [Tested source](test/snippets/insert_new.gleam)</sub>

### Atomic Operations

```gleam
import dream_ets/helpers
import dream_ets/operations
import gleam/option
import gleam/result

pub fn atomic_take() -> Result(String, table.EtsError) {
  use queue <- result.try(helpers.new_string_table("jobs"))

  // Add a job
  use _ <- result.try(operations.set(queue, "job:123", "send_email"))

  // Take and remove atomically (no race conditions)
  use job <- result.try(operations.take(queue, "job:123"))

  case job {
    option.Some(task) -> Ok(task)
    option.None -> Error(table.OperationFailed("Job not found"))
  }
}
```

<sub>🧪 [Tested source](test/snippets/advanced_operations.gleam)</sub>

### Table Configuration

Optimize tables for your workload:

```gleam
import dream_ets/config
import dream_ets/operations
import gleam/option
import gleam/result

pub fn configure_table() -> Result(String, table.EtsError) {
  // Create table with read concurrency enabled
  // Use this when multiple processes will read simultaneously
  use cache <- result.try(
    config.new("cache")
    |> config.read_concurrency(True)
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  use _ <- result.try(operations.set(cache, "key", "value"))
  use value <- result.try(operations.get(cache, "key"))

  case value {
    option.Some(v) -> Ok(v)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

<sub>🧪 [Tested source](test/snippets/table_configuration.gleam)</sub>

**Configuration Options:**

- `read_concurrency(Bool)` - Optimize for concurrent reads
- `write_concurrency(Bool)` - Optimize for concurrent writes
- `compressed(Bool)` - Compress data to save memory
- `table_type(Set | OrderedSet | Bag | DuplicateBag)` - Key handling
- `access(Public | Protected | Private)` - Process access control

### Type Safety

```gleam
import dream_ets/helpers
import dream_ets/operations
import gleam/option
import gleam/result

pub fn type_safe_storage() -> Result(String, table.EtsError) {
  // String table enforces types at compile time
  use cache <- result.try(helpers.new_string_table("cache"))

  // ✅ This works
  use _ <- result.try(operations.set(cache, "key", "value"))

  // ❌ This would be a compile error:
  // operations.set(cache, 123, "value")
  // Error: Expected String, found Int

  use value <- result.try(operations.get(cache, "key"))

  case value {
    option.Some(v) -> Ok(v)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

<sub>🧪 [Tested source](test/snippets/type_safe_operations.gleam)</sub>

### Persistence

```gleam
import dream_ets/helpers
import dream_ets/operations
import gleam/option
import gleam/result

pub fn save_to_disk() -> Result(String, table.EtsError) {
  use table <- result.try(helpers.new_string_table("data"))

  use _ <- result.try(operations.set(table, "key", "important data"))

  // Save to disk
  use _ <- result.try(operations.save_to_file(table, "/tmp/backup.ets"))

  // Verify it's still there
  use value <- result.try(operations.get(table, "key"))

  case value {
    option.Some(data) -> Ok(data)
    option.None -> Error(table.OperationFailed("Data lost"))
  }
}
```

<sub>🧪 [Tested source](test/snippets/table_persistence.gleam)</sub>

## Complete API Reference

### Table Creation

- `config.new(name)` - Create table configuration
- `config.key_string(config)` - Set string keys
- `config.value_string(config)` - Set string values
- `config.key(config, encoder, decoder)` - Set custom key encoding
- `config.value(config, encoder, decoder)` - Set custom value encoding
- `config.counter(config)` - Configure counter table (String keys, Int values)
- `config.create(config)` - Create table from configuration
- `helpers.new_counter(name)` - Convenience: create counter table
- `helpers.new_string_table(name)` - Convenience: create string table

### Basic Operations

- `operations.set(table, key, value)` - Insert or update value
- `operations.get(table, key)` - Retrieve value (returns `Option`)
- `operations.delete(table, key)` - Remove key-value pair
- `operations.member(table, key)` - Check if key exists (fast)
- `operations.delete_table(table)` - Delete entire table
- `operations.delete_all_objects(table)` - Clear all entries

### Atomic Operations

- `operations.insert_new(table, key, value)` - Insert only if key doesn't exist (atomic)
- `operations.take(table, key)` - Get and remove atomically (for queues)

### Bulk Operations

**Note:** These now return `Result` to handle decode errors properly:

- `operations.keys(table)` - Get all keys → `Result(List(k), EtsError)`
- `operations.values(table)` - Get all values → `Result(List(v), EtsError)`
- `operations.to_list(table)` - Get all pairs → `Result(List(#(k, v)), EtsError)`
- `operations.size(table)` - Count entries → `Result(Int, EtsError)`

### Counter Operations

- `helpers.increment(counter, key)` - Increment by 1
- `helpers.increment_by(counter, key, amount)` - Increment by amount
- `helpers.decrement(counter, key)` - Decrement by 1
- `helpers.decrement_by(counter, key, amount)` - Decrement by amount

### Advanced (Low-level)

- `operations.update_element(table, key, pos, value)` - Update tuple element
- `operations.match(table, pattern)` - Pattern matching
- `operations.match_object(table, pattern)` - Object matching
- `operations.select(table, match_spec)` - SQL-like queries

### Persistence

- `operations.save_to_file(table, filename)` - Save table to disk
- `operations.load_from_file(filename)` - Load table from disk

## Error Handling

All operations return `Result` types. Common errors:

- `TableNotFound` - Table was deleted
- `TableAlreadyExists` - Tried to create duplicate table
- `InvalidKey` / `InvalidValue` - Encoding/decoding failed
- `DecodeError(details)` - Failed to decode data (corruption or encoder mismatch)
- `OperationFailed(message)` - General operation failure

**Example:**

```gleam
case operations.get(table, "user:123") {
  Ok(option.Some(user)) -> process_user(user)
  Ok(option.None) -> create_user()
  Error(table.DecodeError(err)) -> log_corruption(err)
  Error(table.TableNotFound) -> recreate_table()
  Error(other) -> handle_error(other)
}
```

## Use Cases

### Session Cache

```gleam
use sessions <- result.try(
  config.new("sessions")
  |> config.key_string()
  |> config.value_string()
  |> config.create(),
)

use _ <- result.try(operations.set(sessions, "session:abc", "user:alice"))
```

### Page View Analytics

```gleam
use counter <- result.try(helpers.new_counter("analytics"))
use views <- result.try(helpers.increment(counter, "homepage"))
```

### Distributed Locks

```gleam
case operations.insert_new(locks, resource_id, owner_id) {
  Ok(True) -> Ok("Lock acquired")
  Ok(False) -> Error("Resource already locked")
  Error(err) -> Error("Lock system error")
}
```

### Work Queue

```gleam
case operations.take(queue, "next_job") {
  Ok(option.Some(job)) -> process_job(job)  // Atomically claimed
  Ok(option.None) -> wait_for_jobs()
  Error(err) -> handle_error(err)
}
```

## Performance Notes

- **Basic ops** (`set`, `get`, `delete`, `member`) - O(1) constant time
- **Bulk ops** (`keys`, `values`, `to_list`, `size`) - O(n) iterates entire table
- **Concurrency** - Enable `read_concurrency` for read-heavy workloads
- **Compression** - Enable for large values to trade CPU for memory

## Design Principles

This module follows the same quality standards as [Dream](https://github.com/TrustBound/dream):

- **Explicit over implicit** - No hidden behavior, no magic
- **Result-based errors** - All operations return `Result` to force error handling
- **No closures** - All dependencies are explicit parameters
- **Simple over clever** - Code should be obvious and boring
- **Type-safe** - Leverage Gleam's type system fully
- **Black-box testing** - Test public interfaces, 100% coverage

## All Examples Are Tested

Every code example in this README comes from `test/snippets/` and is verified by our test suite. You can run them yourself:

```bash
cd modules/ets
gleam test
```

See [test/snippets/](test/snippets/) for complete, runnable examples.

## About Dream

This module was originally built for the [Dream](https://github.com/TrustBound/dream) web toolkit, but it's completely standalone and can be used in any Gleam project. It follows Dream's design principles and will be maintained as part of the Dream ecosystem.

## License

MIT License - see LICENSE file for details.
