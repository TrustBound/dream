# dream_json

**JSON encoding utilities for Gleam applications.**

A standalone module providing convenience functions for encoding optional values and timestamps to JSON. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ Encode optional values to JSON (`null` if `None`)
- ✅ Timestamp encoding helpers
- ✅ Support for strings, integers, floats, and booleans
- ✅ Zero runtime dependencies on Dream (can be used independently)

## Installation

```bash
gleam add dream_json
```

## Quick Start

```gleam
import dream_json/json_encoders as encoders
import gleam/json
import gleam/option
import gleam/time/timestamp

let user_json = json.object([
  #("name", json.string("Alice")),
  #("email", encoders.optional_string(option.Some("alice@example.com"))),
  #("age", encoders.optional_int(option.None)),  // Encodes as null
  #("created_at", encoders.timestamp(option.Some(timestamp.now()))),
])
```

## Usage

### Optional Values

All `optional_*` functions convert `Option` types to JSON, encoding `Some(value)` as the JSON value and `None` as `null`:

```gleam
import dream_json/json_encoders as encoders
import gleam/json
import gleam/option

json.object([
  #("name", json.string("Alice")),
  #("middle_name", encoders.optional_string(option.None)),  // null
  #("nickname", encoders.optional_string(option.Some("Al"))),  // "Al"
  #("age", encoders.optional_int(option.Some(30))),  // 30
  #("score", encoders.optional_float(option.None)),  // null
  #("is_active", encoders.optional_bool(option.Some(True))),  // true
])
```

### Timestamps

Encode timestamps as ISO 8601 strings:

```gleam
import dream_json/json_encoders as encoders
import gleam/json
import gleam/time/timestamp

let now = timestamp.now()
let json = json.object([
  #("created_at", encoders.timestamp(option.Some(now))),
  #("deleted_at", encoders.timestamp(option.None)),  // null
])
```

## API Reference

### Optional Value Encoders

- `optional_string(value: Option(String)) -> Json` - Encode optional string
- `optional_int(value: Option(Int)) -> Json` - Encode optional integer
- `optional_float(value: Option(Float)) -> Json` - Encode optional float
- `optional_bool(value: Option(Bool)) -> Json` - Encode optional boolean

### Timestamp Encoders

- `timestamp(ts: Option(Timestamp)) -> Json` - Encode optional timestamp
- `timestamp_to_string(ts: Timestamp) -> String` - Convert timestamp to string

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
