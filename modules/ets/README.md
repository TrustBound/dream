<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
  
  <a href="https://hexdocs.pm/dream_ets">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
</div>

# dream_ets

**Type-safe ETS (Erlang Term Storage) for Gleam.**

A standalone module providing a type-safe interface to Erlang's ETS in-memory storage. Features a builder pattern for table configuration, type-safe operations, and comprehensive error handling. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ Type-safe key-value storage
- ✅ Builder pattern for table configuration
- ✅ CRUD operations (get, set, delete, etc.)
- ✅ Atomic operations (insert_new, take)
- ✅ Pattern matching and advanced queries
- ✅ Table persistence (save/load to disk)
- ✅ Zero dependencies on Dream or other frameworks

## Installation

```bash
gleam add dream_ets
```

## Quick Start

### Creating Tables

```gleam
import dream_ets as ets

// Using the builder pattern
let assert Ok(table) = ets.new("my_table")
  |> ets.key_string()
  |> ets.value_string()
  |> ets.create()

// Or use convenience functions
let assert Ok(counter) = ets.new_counter("user_counts")
let assert Ok(cache) = ets.new_string_table("cache")
```

### Basic Operations

```gleam
import dream_ets/operations

// Set a value
operations.set(table, "user:123", "Alice")

// Get a value
case operations.get(table, "user:123") {
  Ok(option.Some(name)) -> io.println("Found: " <> name)
  Ok(option.None) -> io.println("Not found")
  Error(err) -> handle_error(err)
}

// Delete a key
operations.delete(table, "user:123")

// Check existence
if operations.member(table, "user:123") {
  io.println("Key exists")
}
```

### Counter Tables

```gleam
import dream_ets/helpers

let assert Ok(counter) = ets.new_counter("page_views")

// Increment
case helpers.increment(counter, "homepage") {
  Ok(new_value) -> io.println("Views: " <> int.to_string(new_value))
  Error(err) -> handle_error(err)
}

// Increment by amount
helpers.increment_by(counter, "homepage", 5)

// Decrement
helpers.decrement(counter, "homepage")
```

## Usage

### Table Configuration

Use the builder pattern to configure tables:

```gleam
import dream_ets as ets

let assert Ok(table) = ets.new("users")
  |> ets.table_type(ets.table_type_set())  // or ordered_set, bag, duplicate_bag
  |> ets.access(ets.access_public())  // or protected, private
  |> ets.read_concurrency(True)
  |> ets.write_concurrency(False)
  |> ets.compressed(False)
  |> ets.key_string()
  |> ets.value_string()
  |> ets.create()
```

### Type-Safe Operations

Tables are parameterized over key and value types:

```gleam
import dream_ets/operations

// String-to-String table
let assert Ok(table) = ets.new_string_table("cache")

// Type-safe operations
operations.set(table, "key", "value")  // ✅ Compiles
// operations.set(table, 123, "value")  // ❌ Type error

case operations.get(table, "key") {
  Ok(option.Some(value)) -> {
    // value is String type
    io.println(value)
  }
  Ok(option.None) -> {}
  Error(err) -> handle_error(err)
}
```

### Advanced Operations

```gleam
import dream_ets/operations

// Insert only if key doesn't exist
case operations.insert_new(table, "key", "value") {
  Ok(True) -> io.println("Inserted")
  Ok(False) -> io.println("Already exists")
  Error(err) -> handle_error(err)
}

// Get and delete atomically
case operations.take(table, "key") {
  Ok(option.Some(value)) -> {
    // Key is now deleted
    process_value(value)
  }
  Ok(option.None) -> {}
  Error(err) -> handle_error(err)
}

// Get all keys/values
let all_keys = operations.keys(table)
let all_values = operations.values(table)
let all_pairs = operations.to_list(table)
```

### Table Persistence

```gleam
import dream_ets/operations

// Save table to disk
case operations.save_to_file(table, "/tmp/my_table.ets") {
  Ok(_) -> io.println("Saved")
  Error(err) -> handle_error(err)
}

// Load table from disk (advanced - returns raw reference)
case operations.load_from_file("/tmp/my_table.ets") {
  Ok(table_ref) -> {
    // Use table_ref with internal APIs
  }
  Error(err) -> handle_error(err)
}
```

## API Reference

### Table Creation

- `ets.new(name)` - Create table config
- `ets.key_string(config)` - Configure string keys
- `ets.value_string(config)` - Configure string values
- `ets.counter(config)` - Configure counter table (String keys, Int values)
- `ets.create(config)` - Create table from config
- `ets.new_counter(name)` - Convenience: create counter table
- `ets.new_string_table(name)` - Convenience: create string-to-string table

### Operations

- `operations.set(table, key, value)` - Insert or update
- `operations.get(table, key)` - Lookup value
- `operations.delete(table, key)` - Delete key
- `operations.member(table, key)` - Check if key exists
- `operations.insert_new(table, key, value)` - Insert only if new
- `operations.take(table, key)` - Get and delete atomically
- `operations.keys(table)` - Get all keys
- `operations.values(table)` - Get all values
- `operations.to_list(table)` - Get all key-value pairs
- `operations.size(table)` - Get table size
- `operations.delete_table(table)` - Delete entire table

### Counter Helpers

- `helpers.increment(table, key)` - Increment by 1
- `helpers.increment_by(table, key, amount)` - Increment by amount
- `helpers.decrement(table, key)` - Decrement by 1
- `helpers.decrement_by(table, key, amount)` - Decrement by amount

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

