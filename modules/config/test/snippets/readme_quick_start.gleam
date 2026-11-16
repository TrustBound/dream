//// README: Quick Start
////
//// Loads required and optional settings from the environment.

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
