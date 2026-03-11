import dream/context.{type EmptyContext}
import dream/http/header.{Header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response}
import dream/http/status
import services.{type Services}

pub fn cors(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let response = next(request, context, services)
  Response(..response, headers: [
    Header("Access-Control-Allow-Origin", "*"),
    Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
    ..response.headers
  ])
}

pub fn reject_unauthorized(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
  _next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  response.text_response(status.unauthorized, "Forbidden")
}

pub fn security_headers(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let response = next(request, context, services)
  Response(..response, headers: [
    Header("X-Content-Type-Options", "nosniff"),
    Header("X-Frame-Options", "DENY"),
    ..response.headers
  ])
}
