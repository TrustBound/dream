//// GET /parcels/:code: the parcel as JSON, from the carrier API in
//// services.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, require_string}
import dream/http/response.{json_response, text_response}
import dream/http/status
import gleam/json
import parcels/carrier.{CarrierFailed, UnknownParcel}
import parcels/services.{type Services}

const bad_gateway = 502

pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_string(request, "code") {
    Error(_) -> json_response(status.bad_request, error_json("No parcel code"))
    Ok(code) ->
      case carrier.track(services.carrier, code) {
        Ok(parcel) -> json_response(status.ok, parcel_json(parcel))
        Error(UnknownParcel(code:)) ->
          json_response(status.not_found, error_json("No parcel " <> code))
        // The body names the cause, so a failed test shows it
        Error(CarrierFailed(reason:)) ->
          text_response(bad_gateway, "The carrier API failed:\n" <> reason)
      }
  }
}

fn parcel_json(parcel: carrier.Parcel) -> String {
  json.object([
    #("code", json.string(parcel.code)),
    #("status", json.string(parcel.status)),
    #("eta", json.string(parcel.eta)),
  ])
  |> json.to_string
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))]) |> json.to_string
}
