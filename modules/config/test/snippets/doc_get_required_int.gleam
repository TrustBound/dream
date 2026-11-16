//// Doc comment: loader.get_required_int
////
//// Reads a required integer and uses it.

import dream_config/loader as config
import gleam/int
import gleam/result

pub fn listen_address() -> Result(String, String) {
  use port <- result.try(config.get_required_int("PORT"))
  Ok("0.0.0.0:" <> int.to_string(port))
}
