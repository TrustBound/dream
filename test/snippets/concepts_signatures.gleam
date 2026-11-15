//// Concepts: the shape of a controller action and of a middleware

import dream/context.{type AppContext as Context}
import dream/http.{type Request, type Response, ok, text_response}
import dream/http/header.{Header}
import dream/http/response.{Response}
import dream/router.{type EmptyServices as Services}

pub type Action =
  fn(Request, Context, Services) -> Response

pub type Middleware =
  fn(Request, Context, Services, fn(Request, Context, Services) -> Response) ->
    Response

pub fn say_hello(
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  text_response(ok, "Hello!")
}

pub fn add_server_header(
  request: Request,
  context: Context,
  services: Services,
  next: Action,
) -> Response {
  let response = next(request, context, services)
  Response(..response, headers: [Header("Server", "Dream"), ..response.headers])
}
