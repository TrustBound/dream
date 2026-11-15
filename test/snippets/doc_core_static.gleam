//// Example for the `dream/controllers/static` module doc.

import dream/controllers/static.{default_config, serve}
import dream/http/request.{type Request, Get, get_param}
import dream/http/response.{type Response, json_response}
import dream/http/status.{bad_request}
import dream/router.{route, router}
import gleam/json

pub fn serve_assets(request: Request, context, services) -> Response {
  case get_param(request, "path") {
    // param.raw keeps the file extension
    Ok(param) ->
      serve(
        request: request,
        context: context,
        services: services,
        root: "./public",
        filepath: param.raw,
        config: default_config(),
      )
    Error(message) -> json_response(bad_request, error_json(message))
  }
}

// In your router:
pub fn asset_router() {
  router()
  |> route(
    method: Get,
    path: "/assets/**path",
    controller: serve_assets,
    middleware: [],
  )
}

fn error_json(message: String) -> String {
  json.to_string(json.object([#("error", json.string(message))]))
}
