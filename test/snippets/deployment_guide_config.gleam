// config.gleam
import envoy
import gleam/int
import gleam/result.{replace_error, try}

pub type Config {
  Config(database_url: String, port: Int, secret_key: String)
}

pub fn load() -> Result(Config, String) {
  use database_url <- try(
    envoy.get("DATABASE_URL")
    |> replace_error("DATABASE_URL not set"),
  )

  use port <- try(read_port())

  use secret_key <- try(
    envoy.get("SECRET_KEY")
    |> replace_error("SECRET_KEY not set"),
  )

  Ok(Config(database_url:, port:, secret_key:))
}

// PORT is optional, but a PORT that is not a number is an error
fn read_port() -> Result(Int, String) {
  case envoy.get("PORT") {
    Error(Nil) -> Ok(3000)
    Ok(value) ->
      int.parse(value)
      |> replace_error("PORT must be a number, got: " <> value)
  }
}
