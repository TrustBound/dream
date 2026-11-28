//// The client of the carrier API: where is a parcel, and when does it
//// arrive. Each function takes the base request of the API as its first
//// parameter, so a test can give it a base request with a recorder.

import dream_http_client/client.{type ClientRequest}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/result
import gleam/string

pub type Parcel {
  Parcel(code: String, status: String, eta: String)
}

pub type CarrierError {
  UnknownParcel(code: String)
  CarrierFailed(reason: String)
}

/// The parcel with `code`, from `GET /v1/parcels/<code>`.
pub fn track(
  carrier: ClientRequest,
  code: String,
) -> Result(Parcel, CarrierError) {
  case carrier |> client.path("/v1/parcels/" <> code) |> client.send() {
    Ok(response) -> decode_parcel(response.body)
    Error(client.ResponseError(response:)) if response.status == 404 ->
      Error(UnknownParcel(code))
    Error(client.ResponseError(response:)) ->
      Error(CarrierFailed("HTTP " <> int.to_string(response.status)))
    Error(client.RequestError(error:)) ->
      Error(CarrierFailed(client.transport_error_to_string(error)))
  }
}

fn decode_parcel(body: BitArray) -> Result(Parcel, CarrierError) {
  let decoder = {
    use code <- decode.field("code", decode.string)
    use status <- decode.field("status", decode.string)
    use eta <- decode.field("eta", decode.string)
    decode.success(Parcel(code:, status:, eta:))
  }
  json.parse_bits(body, decoder)
  |> result.map_error(fn(error) { CarrierFailed(string.inspect(error)) })
}
