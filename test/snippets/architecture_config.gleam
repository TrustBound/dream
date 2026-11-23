//// Architecture reference: dream_config
////
//// Loads the app configuration from the environment and an optional .env
//// file.

import dream_config/loader
import gleam/result

pub type AppConfig {
  AppConfig(database_url: String, port: Int)
}

pub fn load_config() -> Result(AppConfig, String) {
  use _ <- result.try(
    loader.load_dotenv() |> result.map_error(loader.describe_load_error),
  )
  use database_url <- result.try(
    loader.get_required("DATABASE_URL") |> result.map_error(loader.describe),
  )
  let port = loader.get_int("PORT") |> result.unwrap(3000)
  Ok(AppConfig(database_url: database_url, port: port))
}
