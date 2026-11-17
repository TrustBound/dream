<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
  
  <a href="https://hexdocs.pm/dream_json">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
</div>

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

## Quick Start <a href="https://github.com/TrustBound/dream/blob/dream_json-1.0.3/modules/json/test/snippets/quick_start.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_json/json_encoders as encoders
import gleam/json
import gleam/option
import gleam/time/timestamp.{type Timestamp}

pub fn user_json(created_at: Timestamp) -> String {
  json.object([
    #("name", json.string("Alice")),
    #("email", encoders.optional_string(option.Some("alice@example.com"))),
    // Encodes as null
    #("age", encoders.optional_int(option.None)),
    #("created_at", encoders.timestamp(option.Some(created_at))),
  ])
  |> json.to_string()
}
```

## Usage

### Optional Values

All `optional_*` functions convert `Option` types to JSON, encoding `Some(value)` as the JSON value and `None` as `null`:

#### Encode optional fields <a href="https://github.com/TrustBound/dream/blob/dream_json-1.0.3/modules/json/test/snippets/optional_values.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_json/json_encoders as encoders
import gleam/json
import gleam/option

pub fn profile_json() -> String {
  json.object([
    #("name", json.string("Alice")),
    // null
    #("middle_name", encoders.optional_string(option.None)),
    // "Al"
    #("nickname", encoders.optional_string(option.Some("Al"))),
    // 30
    #("age", encoders.optional_int(option.Some(30))),
    // null
    #("score", encoders.optional_float(option.None)),
    // true
    #("is_active", encoders.optional_bool(option.Some(True))),
  ])
  |> json.to_string()
}
```

### Timestamps

Encode timestamps as ISO 8601 strings:

#### Encode a timestamp <a href="https://github.com/TrustBound/dream/blob/dream_json-1.0.3/modules/json/test/snippets/timestamps.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_json/json_encoders as encoders
import gleam/json
import gleam/option
import gleam/time/timestamp.{type Timestamp}

pub fn audit_json(created_at: Timestamp) -> String {
  json.object([
    #("created_at", encoders.timestamp(option.Some(created_at))),
    // null
    #("deleted_at", encoders.timestamp(option.None)),
  ])
  |> json.to_string()
}
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
