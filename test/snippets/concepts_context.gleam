//// Concepts: a custom context and an auth middleware that enriches it

import dream/http.{
  type Request, type Response, get_header, text_response, unauthorized,
}
import gleam/option.{type Option, None, Some}

pub type User {
  User(id: Int, name: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}

pub fn auth_middleware(request: Request, context, services, next) {
  case get_header(request.headers, "Authorization") {
    None -> unauthorized_response()
    Some(token) -> handle_token(request, context, services, next, token)
  }
}

fn handle_token(request, context, services, next, token) {
  case validate_token(token) {
    Ok(user) -> {
      // Enrich context with authenticated user
      let enriched = AuthContext(..context, user: Some(user))
      // Controller receives enriched context
      next(request, enriched, services)
    }
    Error(_) -> unauthorized_response()
  }
}

fn validate_token(token: String) -> Result(User, Nil) {
  case token {
    "Bearer ada-token" -> Ok(User(id: 1, name: "Ada", role: "admin"))
    "Bearer bo-token" -> Ok(User(id: 2, name: "Bo", role: "member"))
    _ -> Error(Nil)
  }
}

fn unauthorized_response() -> Response {
  text_response(unauthorized, "Unauthorized")
}
