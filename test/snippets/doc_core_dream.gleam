//// Examples for the doc comments of the `dream/dream` functions.

import dream/dream.{
  parse_cookie_string, parse_cookies_from_headers, route_request,
}
import dream/http/cookie.{type Cookie}
import dream/http/header.{Header}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{route, router}
import dream/servers/mist/server
import gleam/option.{type Option, None, Some}
import mist.{type Connection, type ResponseData}

pub type MyContext {
  MyContext(user: Option(String))
}

pub type MyServices {
  MyServices(database_url: String)
}

fn home(_request, _context, _services) {
  text_response(status.ok, "Home")
}

pub fn my_router() {
  router()
  |> route(method: Get, path: "/", controller: home, middleware: [])
}

pub fn my_services() -> MyServices {
  MyServices(database_url: "postgres://localhost/app")
}

pub fn raw_server(app) -> mist.Builder(Connection, ResponseData) {
  // You must explicitly acknowledge the risks
  let mist_server = dream.get_server(app, risks_understood: True)
  // Now you have raw Mist types - your code is coupled to Mist
  mist_server
}

pub fn router_status() -> String {
  let app = server.new() |> server.router(my_router())
  case dream.get_router(app) {
    Some(_router) -> "Router is configured"
    None -> "No router yet"
  }
}

pub fn configured_context() -> MyContext {
  let app = server.new() |> server.context(MyContext(user: None))
  let context = dream.get_context(app)
  context
}

pub fn services_status() -> String {
  let app = server.new() |> server.services(my_services())
  case dream.get_services(app) {
    Some(_services) -> "Services are configured"
    None -> "No services yet"
  }
}

pub fn configured_max_body_size() -> Int {
  let app = server.new() |> server.max_body_size(5_000_000)
  dream.get_max_body_size(app)
  // Returns 5_000_000
}

pub fn bind_status() -> String {
  let app = server.new() |> server.bind("0.0.0.0")
  case dream.get_bind_interface(app) {
    Some(interface) -> "Will bind to " <> interface
    None -> "Will use the default interface"
  }
}

pub fn handle(
  my_router,
  incoming_request: Request,
  request_context,
  my_services,
) -> Response {
  // Internal use - normally called by the request handler
  let response =
    route_request(my_router, incoming_request, request_context, my_services)
  response
}

pub fn request_cookies() -> List(Cookie) {
  let headers = [
    Header("Content-Type", "application/json"),
    Header("Cookie", "session=abc123; theme=dark"),
  ]

  let cookies = parse_cookies_from_headers(headers)
  // Returns: [
  //   Cookie(name: "session", value: "abc123", ...),
  //   Cookie(name: "theme", value: "dark", ...)
  // ]
  cookies
}

pub fn cookie_string_cookies() -> List(Cookie) {
  let cookie_header = "session=abc123; theme=dark; lang=en"
  let cookies = parse_cookie_string(cookie_header)
  // Returns: [
  //   simple_cookie("session", "abc123"),
  //   simple_cookie("theme", "dark"),
  //   simple_cookie("lang", "en")
  // ]
  cookies
}
