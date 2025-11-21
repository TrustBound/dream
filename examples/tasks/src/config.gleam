//// Configuration management

import dream_config/loader
import gleam/int
import gleam/result

pub type Config {
  Config(database_url: String, host: String, port: Int)
}

/// Load configuration from environment variables
pub fn load() -> Result(Config, String) {
  // Load .env file if present
  let _ = loader.load_dotenv()

  // Get required DATABASE_URL
  use database_url <- result.try(loader.get_required("DATABASE_URL"))

  // Get optional values with defaults
  let host = loader.get("HOST") |> result.unwrap("0.0.0.0")
  let port =
    loader.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(3000)

  Ok(Config(database_url: database_url, host: host, port: port))
}
