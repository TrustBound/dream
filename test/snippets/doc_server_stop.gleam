//// Doc comment example: dream/servers/mist/server.stop

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server
import gleam/otp/actor
import gleam/result

pub fn test_server(port: Int) -> Result(Nil, actor.StartError) {
  let started =
    server.new()
    |> server.router(test_router())
    |> server.listen_with_handle(port)

  // ... use server ...

  // Optional - server will be cleaned up automatically when test exits
  result.map(started, server.stop)
}

fn test_router() {
  router()
  |> route(method: Get, path: "/test", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(ok, "test passed")
}
