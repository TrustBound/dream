import dream/http/header.{Header}
import dream/http/response.{type Response, Response, Text}
import dream/http/status
import gleam/option.{Some}

// Using builder (recommended)
pub fn with_builder(user_json: String) -> Response {
  response.json_response(status.ok, user_json)
}

// Constructing directly (not recommended)
pub fn by_hand(user_json: String) -> Response {
  Response(
    status: 200,
    body: Text(user_json),
    headers: [Header("Content-Type", "application/json; charset=utf-8")],
    cookies: [],
    content_type: Some("application/json; charset=utf-8"),
  )
}
