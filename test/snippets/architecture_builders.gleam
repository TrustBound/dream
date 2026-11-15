//// Architecture reference: the builder pattern
////
//// The server, the router and the HTTP client all use the same builder
//// pattern.

import dream/context.{type EmptyContext}
import dream/dream.{type Dream}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status.{ok}
import dream/router.{type EmptyServices, type Router, route, router}
import dream/servers/mist/server
import dream_http_client/client.{
  type ClientRequest, type HttpResponse, type SendError,
}
import gleam/http
import mist.{type Builder, type Connection, type ResponseData}

fn show_home(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Home")
}

fn show_about(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "About")
}

// Server
pub fn create_server() -> Dream(
  Builder(Connection, ResponseData),
  EmptyContext,
  EmptyServices,
) {
  server.new()
  |> server.router(create_router())
  |> server.bind("localhost")
}

// Router
pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  |> route(method: Get, path: "/about", controller: show_about, middleware: [])
}

// HTTP client
pub fn create_users_request() -> ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.timeout(5000)
}

pub fn fetch_users() -> Result(HttpResponse, SendError) {
  create_users_request()
  |> client.send()
}
