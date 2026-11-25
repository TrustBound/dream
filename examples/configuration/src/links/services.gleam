//// What the controllers of the links app need, made one time from the
//// configuration.

import gleam/uri.{type Uri}
import links/configuration.{type Configuration}
import links/signing_key.{type SigningKey}

pub type Services {
  Services(site_url: Uri, signing_key: SigningKey)
}

/// The services of the app. The port is for the server, not for a
/// controller, so the services do not hold it.
pub fn from_configuration(configuration: Configuration) -> Services {
  Services(
    site_url: configuration.site_url,
    signing_key: configuration.signing_key,
  )
}
