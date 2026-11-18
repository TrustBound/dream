//// README: Optional Values
////
//// Reads values that can be missing.

import dream_config/loader as config
import gleam/option
import gleam/result

pub fn read_optional_values() -> #(option.Option(String), Int) {
  let api_key = config.get("API_KEY") |> option.from_result

  // Default to 3000
  let port = config.get_int("PORT") |> result.unwrap(3000)

  #(api_key, port)
}
