//// Doc comment: loader.get_required
////
//// Reads a value that the application cannot start without.

import dream_config/loader as config

pub fn database_url() -> Result(String, String) {
  case config.get_required("DATABASE_URL") {
    Ok(url) -> Ok(url)
    Error(message) -> Error("Cannot start the application: " <> message)
  }
}
