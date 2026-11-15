//// Deployment guide: health check, router and server
////
//// Shown in excerpts in docs/guides/deployment.md.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, ok, service_unavailable, text_response,
}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server

pub type Services {
  Services(check_database: fn() -> Result(Nil, String))
}

pub fn health_check(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case services.check_database() {
    Ok(Nil) -> text_response(ok, "OK")
    Error(_reason) -> text_response(service_unavailable, "Database unavailable")
  }
}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/health",
    controller: health_check,
    middleware: [],
  )
}

pub fn create_server(services: Services) {
  server.new()
  |> server.services(services)
  |> server.router(create_router())
  // Listen on all interfaces
  |> server.bind("0.0.0.0")
}

pub fn start_server(services: Services, port: Int) {
  create_server(services)
  |> server.listen(port)
}
