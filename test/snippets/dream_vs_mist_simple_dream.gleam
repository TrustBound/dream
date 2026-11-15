import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn show_home(_request: Request, _context, _services) -> Response {
  text_response(ok, "Hello, World!")
}

pub fn create_router() {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
}

pub fn main() {
  server.new()
  |> server.router(create_router())
  |> server.listen(3000)
}
