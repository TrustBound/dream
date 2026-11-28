//// Doc comment: loader.load_dotenv_from
////
//// Loads a .env file from a given path.

import dream_config/loader as config

pub fn load_settings_file(path: String) -> Result(Nil, String) {
  // For example "/etc/myapp/.env". A missing file is an error.
  config.load_dotenv_from(path)
}
