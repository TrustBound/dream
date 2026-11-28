//// README: Loading .env Files
////
//// Loads the .env file in the current directory, then a second file.

import dream_config/loader as config
import gleam/result

pub fn load_env_files(env_file_path: String) -> Result(Nil, String) {
  // Load from default location (current directory)
  use _ <- result.try(config.load_dotenv())

  // Load from specific path, for example "/etc/myapp/.env"
  config.load_dotenv_from(env_file_path)
}
