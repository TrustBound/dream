//// Configuration loading from environment variables and .env files
////
//// This module provides a clean interface for loading configuration from
//// environment variables and `.env` files. It handles common patterns like
//// required vs optional values, type conversion, and boolean parsing.
////
//// ## Quick Start
////
//// ### Load settings at startup <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/readme_quick_start.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_config/loader as config
//// import gleam/result
////
//// pub type Settings {
////   Settings(database_url: String, port: Int, debug_mode: Bool, api_key: String)
//// }
////
//// pub fn load_settings() -> Result(Settings, String) {
////   // Load .env file (optional, a missing file is not an error)
////   use _ <- result.try(config.load_dotenv())
////
////   // Get required configuration
////   use database_url <- result.try(config.get_required("DATABASE_URL"))
////   use port <- result.try(config.get_required_int("PORT"))
////
////   // Get optional configuration with defaults
////   let debug_mode = config.get_bool("DEBUG")
////   let api_key = config.get("API_KEY") |> result.unwrap("default-key")
////
////   Ok(Settings(database_url:, port:, debug_mode:, api_key:))
//// }
//// ```
////
//// ## Loading .env Files
////
//// Call `load_dotenv()` at application startup to load variables from a `.env`
//// file in the current working directory. This is useful for local
//// development. A missing `.env` file is not an error. A `.env` file that
//// cannot be read or has an invalid line is an error.
////
//// For production, set environment variables directly (via systemd, Docker, etc.)
//// and skip `.env` loading.
////
//// ## Type Safety
////
//// All functions return `Result` types, forcing you to handle missing or invalid
//// values. Use `get_required*` functions for values that must be present, and
//// `get*` functions for optional values.

import dream_config/internal/dotenv.{type ParseError, type Variable}
import envoy
import gleam/int
import gleam/list
import gleam/result
import gleam/string

const default_dotenv_path = ".env"

/// Why a file could not be read as text. The Erlang FFI returns it.
type ReadError {
  FileNotFound
  FileNotUtf8
  FileNotReadable(reason: String)
}

@external(erlang, "dream_config_ffi", "read_text_file")
fn read_text_file(path: String) -> Result(String, ReadError)

/// Load `.env` file from the default location
///
/// Reads the `.env` file in the current working directory and sets each
/// variable in it in the environment. A variable that is already set gets the
/// value from the file. This is typically called at application startup.
///
/// The file format is `NAME=VALUE`, one variable on each line. Lines that
/// start with `#` are comments. Values can be in double quotes, single quotes
/// or backticks. Names are changed to upper case.
///
/// The file is optional, so that the same code runs where the environment
/// variables are set directly (for example in production).
///
/// Returns `Ok(Nil)` if:
/// - The file does not exist (nothing is set)
/// - The file exists and all its variables are set
///
/// Returns `Error(String)` with the path and the reason if the file exists but
/// cannot be read (for example no permission, a directory, or not UTF-8), or if
/// a line is not valid (the message gives the line number). On an error, no
/// variable from the file is set.
///
/// ## Example
///
/// ### Load the .env file at startup <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/doc_load_dotenv.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_config/loader as config
/// import gleam/result
///
/// pub fn database_url_at_startup() -> Result(String, String) {
///   // A missing .env file is not an error, a malformed one is
///   use _ <- result.try(config.load_dotenv())
///   config.get_required("DATABASE_URL")
/// }
/// ```
pub fn load_dotenv() -> Result(Nil, String) {
  case read_text_file(default_dotenv_path) {
    Ok(text) -> set_variables_from_text(default_dotenv_path, text)
    Error(FileNotFound) -> Ok(Nil)
    Error(error) -> Error(format_read_error(default_dotenv_path, error))
  }
}

/// Load `.env` file from a specific path
///
/// Reads the `.env` file at the specified path and sets each variable in it
/// in the environment, in the same format as `load_dotenv`. Useful when your
/// `.env` file is in a non-standard location.
///
/// ## Parameters
///
/// - `path`: The file path to the `.env` file
///
/// ## Returns
///
/// - `Ok(Nil)`: The file was read and all its variables are set
/// - `Error(String)`: The file does not exist, cannot be read, or has a line
///   that is not valid. The message gives the path and the reason. On an
///   error, no variable from the file is set.
///
/// ## Example
///
/// ### Load a .env file from a path <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/doc_load_dotenv_from.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_config/loader as config
///
/// pub fn load_settings_file(path: String) -> Result(Nil, String) {
///   // For example "/etc/myapp/.env". A missing file is an error.
///   config.load_dotenv_from(path)
/// }
/// ```
pub fn load_dotenv_from(path: String) -> Result(Nil, String) {
  use text <- result.try(
    read_text_file(path) |> result.map_error(format_read_error(path, _)),
  )
  set_variables_from_text(path, text)
}

fn set_variables_from_text(path: String, text: String) -> Result(Nil, String) {
  use variables <- result.try(
    dotenv.parse(text) |> result.map_error(format_parse_error(path, _)),
  )
  list.each(variables, set_variable)
  Ok(Nil)
}

fn set_variable(variable: Variable) -> Nil {
  envoy.set(variable.name, variable.value)
}

fn format_read_error(path: String, error: ReadError) -> String {
  let reason = case error {
    FileNotFound -> "the file does not exist"
    FileNotUtf8 -> "the file is not valid UTF-8"
    FileNotReadable(reason) -> reason
  }
  "Cannot load .env file at " <> path <> ": " <> reason
}

fn format_parse_error(path: String, error: ParseError) -> String {
  "Cannot load .env file at "
  <> path
  <> ": line "
  <> int.to_string(error.line)
  <> ": "
  <> error.reason
}

/// Get a required environment variable
///
/// Returns the value of the environment variable if it exists, or an error
/// if it's not set. Use this for configuration values that your application
/// cannot run without.
///
/// ## Parameters
///
/// - `name`: The name of the environment variable
///
/// ## Returns
///
/// - `Ok(String)`: The variable value
/// - `Error(String)`: The variable is not set (includes variable name in message)
///
/// ## Example
///
/// ### Read a required value <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/doc_get_required.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_config/loader as config
///
/// pub fn database_url() -> Result(String, String) {
///   case config.get_required("DATABASE_URL") {
///     Ok(url) -> Ok(url)
///     Error(message) -> Error("Cannot start the application: " <> message)
///   }
/// }
/// ```
pub fn get_required(name: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Required environment variable not set: " <> name)
  }
}

/// Get an optional environment variable
///
/// Returns the value if the variable is set, or `Error(Nil)` if it's not.
/// Use this for configuration values that have sensible defaults or are
/// truly optional.
///
/// ## Parameters
///
/// - `name`: The name of the environment variable
///
/// ## Returns
///
/// - `Ok(String)`: The variable value
/// - `Error(Nil)`: The variable is not set
///
/// ## Example
///
/// ### Read an optional value <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/doc_get.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_config/loader as config
/// import gleam/option.{type Option}
///
/// pub fn api_key() -> Option(String) {
///   case config.get("API_KEY") {
///     Ok(key) -> option.Some(key)
///     Error(_) -> option.None
///   }
/// }
/// ```
pub fn get(name: String) -> Result(String, Nil) {
  envoy.get(name)
}

/// Get an environment variable as an integer
///
/// Attempts to parse the environment variable as an integer. Returns an error
/// if the variable is not set or cannot be parsed as an integer.
///
/// ## Parameters
///
/// - `name`: The name of the environment variable
///
/// ## Returns
///
/// - `Ok(Int)`: The parsed integer value
/// - `Error(Nil)`: Variable not set or not a valid integer
///
/// ## Example
///
/// ### Read an optional integer with a default <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/doc_get_int.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_config/loader as config
///
/// pub fn server_port() -> Int {
///   case config.get_int("PORT") {
///     Ok(port) -> port
///     // Default port
///     Error(_) -> 3000
///   }
/// }
/// ```
pub fn get_int(name: String) -> Result(Int, Nil) {
  case envoy.get(name) {
    Ok(value) -> int.parse(value) |> result.replace_error(Nil)
    Error(_) -> Error(Nil)
  }
}

/// Get a required environment variable as an integer
///
/// Returns the parsed integer value if the variable is set and valid, or an
/// error if it's missing or cannot be parsed. Use this for required numeric
/// configuration like port numbers or timeouts.
///
/// ## Parameters
///
/// - `name`: The name of the environment variable
///
/// ## Returns
///
/// - `Ok(Int)`: The parsed integer value
/// - `Error(String)`: Variable not set or not a valid integer (includes helpful message)
///
/// ## Example
///
/// ### Read a required integer <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/doc_get_required_int.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_config/loader as config
/// import gleam/int
/// import gleam/result
///
/// pub fn listen_address() -> Result(String, String) {
///   use port <- result.try(config.get_required_int("PORT"))
///   Ok("0.0.0.0:" <> int.to_string(port))
/// }
/// ```
pub fn get_required_int(name: String) -> Result(Int, String) {
  use value <- result.try(get_required(name))

  int.parse(value)
  |> result.replace_error(
    "Environment variable " <> name <> " must be an integer",
  )
}

/// Get an environment variable as a boolean
///
/// Parses the environment variable as a boolean. The following values are
/// treated as `True`, in any mix of upper and lower case (for example `tRUE`
/// or `Yes`):
/// - `"true"`
/// - `"1"`
/// - `"yes"`
///
/// All other values (including unset variables, and values with spaces around
/// them) are treated as `False`.
///
/// ## Parameters
///
/// - `name`: The name of the environment variable
///
/// ## Returns
///
/// - `True`: Variable is set to a truthy value
/// - `False`: Variable is not set or set to a falsy value
///
/// ## Example
///
/// ### Pick a log level from DEBUG <a href="https://github.com/TrustBound/dream/blob/dream_config-1.0.2/modules/config/test/snippets/readme_boolean_values.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_config/loader as config
///
/// pub fn log_level() -> String {
///   let debug_mode = config.get_bool("DEBUG")
///   case debug_mode {
///     True -> "debug"
///     False -> "info"
///   }
/// }
/// ```
pub fn get_bool(name: String) -> Bool {
  case envoy.get(name) {
    Ok(value) -> is_true_value(string.lowercase(value))
    Error(_) -> False
  }
}

fn is_true_value(lowercase_value: String) -> Bool {
  case lowercase_value {
    "true" | "1" | "yes" -> True
    _ -> False
  }
}
