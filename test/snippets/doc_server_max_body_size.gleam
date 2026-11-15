//// Doc comment example: dream/servers/mist/server.max_body_size

import dream/http.{bad_request, ok, text_response}
import dream/http/request.{type Request, Post, body_as_string}
import dream/router.{route, router}
import dream/servers/mist/server

pub fn main() {
  // Limit request bodies to 10MB
  server.new()
  |> server.services(my_services())
  |> server.router(my_router())
  |> server.max_body_size(10_000_000)
  |> server.listen(3000)
}

pub type Services {
  Services(greeting: String)
}

pub fn my_services() -> Services {
  Services(greeting: "Received")
}

pub fn my_router() {
  router()
  |> route(method: Post, path: "/upload", controller: upload, middleware: [])
}

fn upload(request: Request, _context, services: Services) {
  case body_as_string(request) {
    Ok(body) -> text_response(ok, services.greeting <> " " <> body)
    Error(Nil) -> text_response(bad_request, "Request body is not text")
  }
}
