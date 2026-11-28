//// Doc comment: loader.get_int
////
//// Reads an optional integer with a default.

import dream_config/loader as config

pub fn server_port() -> Int {
  case config.get_int("PORT") {
    Ok(port) -> port
    // Default port
    Error(_) -> 3000
  }
}
