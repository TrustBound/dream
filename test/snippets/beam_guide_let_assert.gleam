//// BEAM guide: `let assert` on user input, and where it belongs

import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/int
import gleam/option.{None, Some}

/// Wrong: a page number that is not a number crashes the request
pub fn page_or_crash(request: Request, _context, _services) -> Response {
  let assert Ok(page) = case get_query_param(request.query, "page") {
    Some(text) -> int.parse(text)
    None -> Ok(1)
  }
  text_response(status.ok, "Page " <> int.to_string(page))
}

/// Fix: bad input from a client is an expected case, so answer 400
pub fn page(request: Request, _context, _services) -> Response {
  let parsed = case get_query_param(request.query, "page") {
    Some(text) -> int.parse(text)
    None -> Ok(1)
  }
  case parsed {
    Ok(page) -> text_response(status.ok, "Page " <> int.to_string(page))
    Error(Nil) ->
      text_response(status.bad_request, "page must be a whole number")
  }
}

/// Right: at startup, a bad setting is a bug in the deployment. The
/// program stops at once, with a message that says why.
pub fn port_setting(text: String) -> Int {
  let assert Ok(port) = int.parse(text) as "PORT must be a whole number"
  port
}
