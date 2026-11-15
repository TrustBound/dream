//// Example for the doc comment of `dream/dream.create`: the builder that
//// most applications use instead.

import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{route, router}
import dream/servers/mist/server

pub type MyContext {
  MyContext
}

pub type MyServices {
  MyServices
}

fn home(_request, _context, _services) {
  text_response(status.ok, "Home")
}

pub fn my_router() {
  router()
  |> route(method: Get, path: "/", controller: home, middleware: [])
}

pub fn create_server() {
  server.new()
  |> server.context(MyContext)
  |> server.services(MyServices)
  |> server.router(my_router())
  |> server.max_body_size(10_000_000)
  |> server.bind("0.0.0.0")
}
