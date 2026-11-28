//// Example for the doc of `static.with_directory_listing`.

import dream/controllers/static.{
  type Config, default_config, with_directory_listing,
}

pub fn listing_config() -> Config(context, services) {
  // allow_directory_listing: True
  default_config()
  |> with_directory_listing()
}
