//// Doc comment example: dream/servers/mist/server.bind

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

pub fn main() {
  // Only accept local connections
  let assert Ok(Nil) =
    server.new()
    |> server.services(my_services())
    |> server.router(my_router())
    |> server.bind("localhost")
    |> server.listen(3000)
}

pub type Services {
  Services(greeting: String)
}

pub fn my_services() -> Services {
  Services(greeting: "Hello from localhost")
}

pub fn my_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, services: Services) {
  text_response(ok, services.greeting)
}
