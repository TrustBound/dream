//// REST API guide: CORS
////
//// A middleware that adds CORS headers to every response, as shown in
//// docs/guides/api-patterns.md.

import dream/context.{type AppContext}
import dream/http/header.{Header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response}

pub type Services {
  Services
}

pub fn cors_middleware(
  request: Request,
  context: AppContext,
  services: Services,
  next: fn(Request, AppContext, Services) -> Response,
) -> Response {
  let response = next(request, context, services)

  add_cors_headers(response)
}

fn add_cors_headers(response: Response) -> Response {
  Response(..response, headers: [
    Header("Access-Control-Allow-Origin", "*"),
    Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"),
    Header("Access-Control-Allow-Headers", "Content-Type, Authorization"),
    ..response.headers
  ])
}
