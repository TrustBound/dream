//// Example for the doc of `static.without_index`.

import dream/controllers/static.{type Config, default_config, without_index}

pub fn no_index_config() -> Config(context, services) {
  // serve_index: False
  default_config()
  |> without_index()
}
