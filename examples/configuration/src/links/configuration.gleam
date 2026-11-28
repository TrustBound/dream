//// The settings of the links app. `load` reads them one time, at startup,
//// and gives one typed value. No other module reads the environment.

import dream_config/loader.{type ConfigError, type LoadError}
import gleam/int
import gleam/option.{Some}
import gleam/result
import gleam/uri.{type Uri}
import links/signing_key.{type SigningKey, TooShort}

pub type Configuration {
  Configuration(port: Int, site_url: Uri, signing_key: SigningKey)
}

/// Why the app cannot start. No variant holds the value of a setting, so
/// an error message cannot leak a secret.
pub type ConfigurationError {
  EnvFileInvalid(error: LoadError)
  SettingInvalid(error: ConfigError)
  PortOutOfRange(port: Int)
  SiteUrlInvalid
  SigningKeyTooShort(length: Int)
}

/// The port when `PORT` is not set.
pub const default_port = 3000

/// Loads `.env` (when the file exists), then reads every setting.
pub fn load() -> Result(Configuration, ConfigurationError) {
  use _ <- result.try(loader.load_dotenv() |> result.map_error(EnvFileInvalid))
  use port <- result.try(read_port())
  use site_url <- result.try(read_site_url())
  use signing_key <- result.try(read_signing_key())
  Ok(Configuration(port:, site_url:, signing_key:))
}

/// `PORT` is optional. When it is set, it must be a port number.
fn read_port() -> Result(Int, ConfigurationError) {
  case loader.get_int("PORT") {
    Ok(port) -> check_port(port)
    Error(loader.NotSet(_)) -> Ok(default_port)
    Error(error) -> Error(SettingInvalid(error))
  }
}

fn check_port(port: Int) -> Result(Int, ConfigurationError) {
  case port >= 1 && port <= 65_535 {
    True -> Ok(port)
    False -> Error(PortOutOfRange(port:))
  }
}

/// `SITE_URL` is required: the address that starts each share link.
fn read_site_url() -> Result(Uri, ConfigurationError) {
  use text <- result.try(
    loader.get_required("SITE_URL") |> result.map_error(SettingInvalid),
  )
  uri.parse(text)
  |> result.replace_error(SiteUrlInvalid)
  |> result.try(check_site_url)
}

/// The URL must have an http or https scheme, a host, and no path.
fn check_site_url(site_url: Uri) -> Result(Uri, ConfigurationError) {
  case site_url.scheme, site_url.host, site_url.path {
    Some("https"), Some(_), "" | Some("https"), Some(_), "/" -> Ok(site_url)
    Some("http"), Some(_), "" | Some("http"), Some(_), "/" -> Ok(site_url)
    _, _, _ -> Error(SiteUrlInvalid)
  }
}

/// `SIGNING_KEY` is required, and it is a secret.
fn read_signing_key() -> Result(SigningKey, ConfigurationError) {
  use text <- result.try(
    loader.get_required("SIGNING_KEY") |> result.map_error(SettingInvalid),
  )
  signing_key.new(text)
  |> result.map_error(fn(error) {
    let TooShort(length:) = error
    SigningKeyTooShort(length:)
  })
}

/// The message for an error. It names the setting, never its value.
pub fn describe_error(error: ConfigurationError) -> String {
  case error {
    EnvFileInvalid(error:) -> loader.describe_load_error(error)
    SettingInvalid(error:) -> loader.describe(error)
    PortOutOfRange(port:) ->
      "PORT must be from 1 to 65535, not " <> int.to_string(port)
    SiteUrlInvalid ->
      "SITE_URL must be an http or https URL with a host and no path"
    SigningKeyTooShort(length:) ->
      "SIGNING_KEY must have at least "
      <> int.to_string(signing_key.minimum_length)
      <> " characters, not "
      <> int.to_string(length)
  }
}

/// The settings for the startup log. The signing key shows as `[hidden]`.
pub fn describe(configuration: Configuration) -> String {
  "port: "
  <> int.to_string(configuration.port)
  <> ", site URL: "
  <> uri.to_string(configuration.site_url)
  <> ", signing key: [hidden]"
}
