//// Naming conventions: Configuration (Builder Pattern Exception)
////
//// The server builder uses short verbs such as `bind` and `listen`, because
//// the builder gives the context.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router
import dream/servers/mist/server

pub fn start(port: Int) {
  server.new()
  |> server.router(app_router())
  |> server.bind("localhost")
  |> server.listen_with_handle(port)
}

fn app_router() {
  router.router()
  |> router.route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(ok, "Home")
}
