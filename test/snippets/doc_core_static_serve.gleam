//// Example for the doc comment of `dream/controllers/static.serve`.

import dream/controllers/static.{default_config, serve}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, json_response}
import dream/http/status.{bad_request}
import gleam/json

pub fn serve_public(request: Request, context, services) -> Response {
  case get_param(request, "filepath") {
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

fn error_json(message: String) -> String {
  json.to_string(json.object([#("error", json.string(message))]))
}
