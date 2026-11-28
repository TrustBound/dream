//// Example for the doc of `static.default_config`.

import dream/controllers/static.{type Config, default_config}

pub fn asset_config() -> Config(context, services) {
  // serve_index: True, allow_directory_listing: False, not_found_handler: None
  default_config()
}
