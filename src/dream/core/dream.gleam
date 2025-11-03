//// Core Dream server type and shared functionality
////
//// This module provides the generic Dream server type and core routing
//// functionality that is shared across all server implementations.

import dream/core/http/statuses.{convert_client_error_to_status, not_found}
import dream/core/http/transaction
import dream/core/router.{type Router, find_route}
import gleam/list
import gleam/option
import gleam/string

/// Generic Dream server type parameterized over the server implementation
pub type Dream(server) {
  Dream(server: server, router: Router, max_body_size: Int)
}

/// Route a request using the provided router and return a response
pub fn route_request(
  router_instance: Router,
  request: transaction.Request,
) -> transaction.Response {
  case find_route(router_instance, request) {
    option.Some(#(route, params)) -> {
      let request_with_params = transaction.Request(..request, params: params)
      route.handler(request_with_params)
    }
    option.None ->
      transaction.text_response(
        convert_client_error_to_status(not_found()),
        "Route not found",
      )
  }
}

/// Parse cookies from headers
pub fn parse_cookies_from_headers(
  headers: List(transaction.Header),
) -> List(transaction.Cookie) {
  let cookie_header =
    list.find(headers, fn(header) {
      string.lowercase(transaction.header_name(header)) == "cookie"
    })

  case cookie_header {
    Ok(header) -> {
      let cookie_string = transaction.header_value(header)
      parse_cookie_string(cookie_string)
    }
    Error(_) -> []
  }
}

/// Parse a cookie header string into Cookie list
pub fn parse_cookie_string(cookie_string: String) -> List(transaction.Cookie) {
  cookie_string
  |> string.split(";")
  |> list.map(fn(cookie_pair) {
    case string.split(cookie_pair, "=") {
      [name, value] -> {
        let name = string.trim(name)
        let value = string.trim(value)
        transaction.simple_cookie(name, value)
      }
      _ -> {
        let name = string.trim(cookie_pair)
        transaction.simple_cookie(name, "")
      }
    }
  })
}
