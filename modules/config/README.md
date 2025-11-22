<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
  
  <a href="https://hexdocs.pm/dream_config">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
</div>

# dream_config

**Type-safe configuration management for Gleam applications.**

A standalone module for loading configuration from environment variables and `.env` files. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ Load from environment variables or `.env` files
- ✅ Type-safe with `Result` types (no silent failures)
- ✅ Support for strings, integers, and booleans
- ✅ Required vs optional configuration values
- ✅ Zero dependencies on Dream or other frameworks

## Installation

```bash
gleam add dream_config
```

## Quick Start

```gleam
import dream_config/loader as config

// Load .env file (optional, fails silently if missing)
config.load_dotenv()

// Get required configuration
let assert Ok(database_url) = config.get_required("DATABASE_URL")
let assert Ok(port) = config.get_required_int("PORT")

// Get optional configuration with defaults
let debug_mode = config.get_bool("DEBUG")
let api_key = case config.get("API_KEY") {
  Ok(key) -> key
  Error(_) -> "default-key"
}
```

## Usage

### Loading `.env` Files

```gleam
import dream_config/loader as config

// Load from default location (current directory)
config.load_dotenv()

// Load from specific path
config.load_dotenv_from("/etc/myapp/.env")
```

### Required Values

Use `get_required*` functions for values your application cannot run without:

```gleam
import dream_config/loader as config
import gleam/result

pub fn load_config() -> Result(AppConfig, String) {
  use db_url <- result.try(config.get_required("DATABASE_URL"))
  use port <- result.try(config.get_required_int("PORT"))
  
  Ok(AppConfig(database_url: db_url, port: port))
}
```

### Optional Values

Use `get*` functions for values with sensible defaults:

```gleam
import dream_config/loader as config
import gleam/option

let api_key = case config.get("API_KEY") {
  Ok(key) -> option.Some(key)
  Error(_) -> option.None
}

let port = config.get_int("PORT") 
  |> result.unwrap(3000)  // Default to 3000
```

### Boolean Values

The `get_bool()` function treats these as `True` (case-insensitive):
- `"true"`
- `"1"`
- `"yes"`

Everything else (including unset) is `False`:

```gleam
let debug_mode = config.get_bool("DEBUG")
if debug_mode {
  enable_debug_logging()
}
```

## API Reference

### Loading `.env` Files

- `load_dotenv() -> Result(Nil, String)` - Load from default location
- `load_dotenv_from(path: String) -> Result(Nil, String)` - Load from specific path

### Getting Values

- `get_required(name: String) -> Result(String, String)` - Required string
- `get(name: String) -> Result(String, Nil)` - Optional string
- `get_required_int(name: String) -> Result(Int, String)` - Required integer
- `get_int(name: String) -> Result(Int, Nil)` - Optional integer
- `get_bool(name: String) -> Bool` - Boolean (defaults to `False`)

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
