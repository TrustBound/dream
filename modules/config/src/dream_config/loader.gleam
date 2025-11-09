//// Configuration loading from environment variables and .env files

import dot_env
import envoy
import gleam/int
import gleam/result

/// Load .env file if it exists
/// Returns Ok(Nil) if file doesn't exist or loads successfully  
/// Only returns Error if file exists but has invalid format
pub fn load_dotenv() -> Result(Nil, String) {
  let _ = dot_env.load_default()
  Ok(Nil)
}

/// Load .env file from specific path
pub fn load_dotenv_from(path: String) -> Result(Nil, String) {
  let opts = dot_env.new_with_path(path)
  let _ = dot_env.load(opts)
  Ok(Nil)
}

/// Get required environment variable
/// Returns Error if not set
pub fn get_required(name: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Required environment variable not set: " <> name)
  }
}

/// Get optional environment variable
pub fn get(name: String) -> Result(String, Nil) {
  envoy.get(name)
}

/// Get environment variable as Int
pub fn get_int(name: String) -> Result(Int, Nil) {
  case envoy.get(name) {
    Ok(value) -> int.parse(value) |> result.replace_error(Nil)
    Error(_) -> Error(Nil)
  }
}

/// Get required environment variable as Int
pub fn get_required_int(name: String) -> Result(Int, String) {
  use value <- result.try(get_required(name))
  
  int.parse(value)
  |> result.replace_error(
    "Environment variable " <> name <> " must be an integer",
  )
}

/// Get environment variable as Bool
/// Treats "true", "1", "yes" as True
/// Everything else as False
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

