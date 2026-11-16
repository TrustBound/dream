//// Doc comment: loader.get
////
//// Reads an optional value as an Option.

import dream_config/loader as config
import gleam/option.{type Option}

pub fn api_key() -> Option(String) {
  case config.get("API_KEY") {
    Ok(key) -> option.Some(key)
    Error(_) -> option.None
  }
}
