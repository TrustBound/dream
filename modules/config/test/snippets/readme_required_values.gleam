//// README: Required Values
////
//// Fails when a value the application needs is not set.

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
