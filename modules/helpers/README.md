# dream_helpers

Optional convenience utilities for Dream applications.

> **Note:** Most functionality has moved to Dream core. This module now contains
> only optional JSON encoding helpers. For response builders, status constants,
> and validation, use `dream/http/response`, `dream/http/status`, and
> `dream/http/validation`.

## Provides

- JSON encoders for optional values and timestamps

## Usage

```gleam
import dream_helpers/json_encoders
import gleam/json
import gleam/option
import gleam/time/timestamp

// Encode optional values
json.object([
  #("name", json.string("John")),
  #("email", json_encoders.optional_string(option.Some("john@example.com"))),
  #("age", json_encoders.optional_int(option.None)),
  #("created_at", json_encoders.timestamp(option.Some(timestamp.now()))),
])
```

