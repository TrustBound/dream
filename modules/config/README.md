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

## Quick Start <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/readme_quick_start.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_config/loader as config
import gleam/result

pub type Settings {
  Settings(database_url: String, port: Int, debug_mode: Bool, api_key: String)
}

pub fn load_settings() -> Result(Settings, String) {
  // Load .env file (optional, a missing file is not an error)
  use _ <- result.try(config.load_dotenv())

  // Get required configuration
  use database_url <- result.try(config.get_required("DATABASE_URL"))
  use port <- result.try(config.get_required_int("PORT"))

  // Get optional configuration with defaults
  let debug_mode = config.get_bool("DEBUG")
  let api_key = config.get("API_KEY") |> result.unwrap("default-key")

  Ok(Settings(database_url:, port:, debug_mode:, api_key:))
}
```

## Usage

### Loading `.env` Files <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/readme_load_env_files.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_config/loader as config
import gleam/result

pub fn load_env_files(env_file_path: String) -> Result(Nil, String) {
  // Load from default location (current directory)
  use _ <- result.try(config.load_dotenv())

  // Load from specific path, for example "/etc/myapp/.env"
  config.load_dotenv_from(env_file_path)
}
```

### Required Values

Use `get_required*` functions for values your application cannot run without:

#### Load required settings <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/readme_required_values.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_config/loader as config
import gleam/result

pub type AppConfig {
  AppConfig(database_url: String, port: Int)
}

pub fn load_config() -> Result(AppConfig, String) {
  use database_url <- result.try(config.get_required("DATABASE_URL"))
  use port <- result.try(config.get_required_int("PORT"))

  Ok(AppConfig(database_url: database_url, port: port))
}
```

### Optional Values

Use `get*` functions for values with sensible defaults:

#### Read optional settings <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/readme_optional_values.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_config/loader as config
import gleam/option
import gleam/result

pub fn read_optional_values() -> #(option.Option(String), Int) {
  let api_key = config.get("API_KEY") |> option.from_result

  // Default to 3000
  let port = config.get_int("PORT") |> result.unwrap(3000)

  #(api_key, port)
}
```

### Boolean Values

The `get_bool()` function treats these as `True` (case-insensitive):
- `"true"`
- `"1"`
- `"yes"`

Everything else (including unset) is `False`:

#### Pick a log level from DEBUG <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/readme_boolean_values.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_config/loader as config

pub fn log_level() -> String {
  let debug_mode = config.get_bool("DEBUG")
  case debug_mode {
    True -> "debug"
    False -> "info"
  }
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
