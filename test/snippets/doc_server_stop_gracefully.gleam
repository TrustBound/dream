//// Doc comment example: dream/servers/mist/server.stop_gracefully

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server
import gleam/otp/actor
import gleam/result

pub fn serve_then_stop(port: Int) -> Result(Nil, actor.StartError) {
  let started =
    server.new()
    |> server.router(app_router())
    |> server.listen_with_handle(port)

  // Let running requests finish, but wait at most 30 seconds
  result.map(started, server.stop_gracefully(_, within: 30_000))
}

fn app_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(ok, "Hello")
}
