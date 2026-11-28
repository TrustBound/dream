//// The auth middleware that the testing guide's middleware test tests.
////
//// It only checks that a bearer token is present. A real application also
//// verifies the token.

import dream/context.{type AppContext}
import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, json_response}
import dream/http/status.{unauthorized}
import dream/router.{type EmptyServices}
import gleam/option.{type Option, Some}
import gleam/string

pub fn middleware(
  request: Request,
  context: AppContext,
  services: EmptyServices,
  next: fn(Request, AppContext, EmptyServices) -> Response,
) -> Response {
  case has_bearer_token(get_header(request.headers, "Authorization")) {
    True -> next(request, context, services)
    False -> json_response(unauthorized, "{\"error\":\"Unauthorized\"}")
  }
}

fn has_bearer_token(authorization: Option(String)) -> Bool {
  case authorization {
    Some(value) -> string.starts_with(value, "Bearer ")
    _ -> False
  }
}
