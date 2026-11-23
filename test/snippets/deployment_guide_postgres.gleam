import gleam/erlang/process
import pog

pub fn create_database_config() -> pog.Config {
  pog.default_config(pool_name: process.new_name("app_database"))
  // Adjust based on load
  |> pog.pool_size(15)
}
