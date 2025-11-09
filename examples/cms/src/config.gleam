//// Configuration loading
////
//// Loads configuration from environment variables and .env files.

import dream_config/loader
import gleam/result

pub type Config {
  Config(
    database_url: String,
    opensearch_url: String,
    port: Int,
    host: String,
  )
}

pub fn load() -> Result(Config, String) {
  let _ = loader.load_dotenv()
  
  use db_url <- result.try(loader.get_required("DATABASE_URL"))
  use opensearch_url <- result.try(loader.get_required("OPENSEARCH_URL"))
  
  let port = loader.get_int("PORT") |> result.unwrap(3000)
  let host = loader.get("HOST") |> result.unwrap("localhost")
  
  Ok(Config(
    database_url: db_url,
    opensearch_url: opensearch_url,
    port: port,
    host: host,
  ))
}

