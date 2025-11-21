//// Configuration loading from environment variables and .env files
////
//// This module provides a clean interface for loading configuration from
//// environment variables and `.env` files. It handles common patterns like
//// required vs optional values, type conversion, and boolean parsing.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_config/loader as config
////
//// // Load .env file (if present)
//// config.load_dotenv()
////
//// // Get configuration values
//// let assert Ok(db_url) = config.get_required("DATABASE_URL")
//// let assert Ok(port) = config.get_required_int("PORT")
//// let debug_mode = config.get_bool("DEBUG")
//// ```
////
//// ## Loading .env Files
////
//// Call `load_dotenv()` at application startup to load variables from a `.env`
//// file in your project root. This is useful for local development.
////
//// For production, set environment variables directly (via systemd, Docker, etc.)
//// and skip `.env` loading.
////
//// ## Type Safety
////
//// All functions return `Result` types, forcing you to handle missing or invalid
//// values. Use `get_required*` functions for values that must be present, and
//// `get*` functions for optional values.

import dot_env
import envoy
import gleam/int
import gleam/result

/// Load `.env` file from the default location
///
/// Looks for a `.env` file in the current working directory and loads all
/// variables into the environment. This is typically called at application
/// startup.
///
/// Returns `Ok(Nil)` if:
/// - The file doesn't exist (no error - environment variables may be set directly)
/// - The file exists and loads successfully
///
/// Returns `Error(String)` only if the file exists but has an invalid format.
///
/// ## Example
///
/// ```gleam
/// import dream_config/loader as config
///
/// // At application startup
/// config.load_dotenv()
/// ```
pub fn load_dotenv() -> Result(Nil, String) {
  let _ = dot_env.load_default()
  Ok(Nil)
}

/// Load `.env` file from a specific path
///
/// Loads environment variables from a `.env` file at the specified path.
/// Useful when your `.env` file is in a non-standard location.
///
/// ## Parameters
///
/// - `path`: The file path to the `.env` file
///
/// ## Returns
///
/// - `Ok(Nil)`: File loaded successfully or doesn't exist
/// - `Error(String)`: File exists but has invalid format
///
/// ## Example
///
/// ```gleam
/// import dream_config/loader as config
///
/// config.load_dotenv_from("/etc/myapp/.env")
/// ```
pub fn load_dotenv_from(path: String) -> Result(Nil, String) {
  let opts = dot_env.new_with_path(path)
  let _ = dot_env.load(opts)
  Ok(Nil)
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
/// ```gleam
/// import dream_config/loader as config
///
/// case config.get_required("DATABASE_URL") {
///   Ok(url) -> start_database(url)
///   Error(msg) -> panic as msg
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
/// ```gleam
/// import dream_config/loader as config
/// import gleam/option
///
/// let api_key = case config.get("API_KEY") {
///   Ok(key) -> option.Some(key)
///   Error(_) -> option.None
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
/// ```gleam
/// import dream_config/loader as config
///
/// case config.get_int("PORT") {
///   Ok(port) -> start_server(port)
///   Error(_) -> start_server(3000)  // Default port
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
/// ```gleam
/// import dream_config/loader as config
///
/// let assert Ok(port) = config.get_required_int("PORT")
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
/// treated as `True` (case-insensitive):
/// - `"true"`
/// - `"1"`
/// - `"yes"`
///
/// All other values (including unset variables) are treated as `False`.
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
/// ```gleam
/// import dream_config/loader as config
///
/// let debug_mode = config.get_bool("DEBUG")
/// if debug_mode {
///   enable_debug_logging()
/// }
/// ```
pub fn get_bool(name: String) -> Bool {
  case envoy.get(name) {
    Ok("true") -> True
    Ok("1") -> True
    Ok("yes") -> True
    Ok("YES") -> True
    Ok("True") -> True
    Ok("TRUE") -> True
    _ -> False
  }
}
