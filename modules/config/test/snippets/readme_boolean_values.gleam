//// README: Boolean Values
////
//// Picks a log level from the DEBUG flag.

import dream_config/loader as config

pub fn log_level() -> String {
  let debug_mode = config.get_bool("DEBUG")
  case debug_mode {
    True -> "debug"
    False -> "info"
  }
}
