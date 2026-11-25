//// The services of the parcels app: the base request of the carrier API.

import dream_http_client/client.{type ClientRequest}
import envoy
import gleam/http
import gleam/result

pub type Services {
  Services(carrier: ClientRequest)
}

/// The services of the running app: the carrier API at its real address,
/// with the token from the environment variable `CARRIER_TOKEN`.
pub fn initialize_services() -> Result(Services, String) {
  use token <- result.try(
    envoy.get("CARRIER_TOKEN")
    |> result.replace_error("Set CARRIER_TOKEN to the token of the carrier API"),
  )
  let carrier =
    client.new()
    |> client.scheme(http.Https)
    |> client.host("api.carrier.example")
    |> client.add_header("authorization", "Bearer " <> token)
  Ok(Services(carrier:))
}
