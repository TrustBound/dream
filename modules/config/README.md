# dream_config

Configuration management for Dream applications.

Provides utilities for loading configuration from environment variables and .env files.

## Usage

```gleam
import dream_config/loader

pub type AppConfig {
  AppConfig(
    database_url: String,
    port: Int,
    host: String,
  )
}

pub fn load_config() -> Result(AppConfig, String) {
  // Load .env file (optional, fails silently)
  loader.load_dotenv()
  
  // Get required values
  use db_url <- result.try(loader.get_required("DATABASE_URL"))
  
  // Get optional values with defaults
  let port = loader.get_int("PORT") |> result.unwrap(3000)
  let host = loader.get("HOST") |> result.unwrap("localhost")
  
  Ok(AppConfig(database_url: db_url, port: port, host: host))
}
```

