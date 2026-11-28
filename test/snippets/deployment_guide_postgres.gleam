import dream_postgres_client
import gleam/erlang/process

pub fn create_database_config() -> dream_postgres_client.Config {
  dream_postgres_client.default_config(pool_name: process.new_name(
    "app_database",
  ))
  // Adjust based on load
  |> dream_postgres_client.pool_size(15)
}
