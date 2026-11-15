import dream/http/response.{type Response, json_response}
import dream/http/status.{bad_request, ok}
import dream/http/transaction.{type Request, get_int_param}
import gleam/json

pub fn show_user(request: Request, _context, _services) -> Response {
  let result = get_int_param(request, "id")

  case result {
    Ok(id) -> json_response(ok, user_to_json(id))
    Error(message) -> json_response(bad_request, error_json(message))
  }
}

fn user_to_json(id: Int) -> String {
  json.to_string(json.object([#("id", json.int(id))]))
}

fn error_json(message: String) -> String {
  json.to_string(json.object([#("error", json.string(message))]))
}
