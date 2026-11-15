import dream/http/response.{json_response}
import dream/http/status.{ok}
import gleam/json

pub fn show_user(_request, _context, _services) {
  let user_json =
    json.object([
      #("id", json.int(123)),
      #("name", json.string("Alice")),
    ])

  json_response(ok, json.to_string(user_json))
}
