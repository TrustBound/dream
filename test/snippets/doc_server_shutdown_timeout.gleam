//// Doc comment example: dream/servers/mist/server.shutdown_timeout

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

pub fn main() {
  let assert Ok(Nil) = server.listen(app(), 3000)
}

pub fn app() {
  server.new()
  |> server.router(my_router())
  // Docker waits 10 seconds after SIGTERM before it kills the app
  |> server.shutdown_timeout(8000)
}

fn my_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(ok, "Hello")
}
