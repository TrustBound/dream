//// BEAM guide: each connection runs in its own process

import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, route, router}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/string

pub type Services {
  Services(arrivals: Subject(#(Pid, Subject(Nil))))
}

/// Answers with the process that runs the request
pub fn whoami(_request: Request, _context, _services: Services) -> Response {
  text_response(status.ok, string.inspect(process.self()))
}

/// Tells `arrivals` which process runs the request, then waits for a go
/// before it answers. Two requests that wait here run at the same time.
pub fn wait_for_go(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  let go = process.new_subject()
  process.send(services.arrivals, #(process.self(), go))
  case process.receive(go, within: 5000) {
    Ok(Nil) -> text_response(status.ok, string.inspect(process.self()))
    Error(Nil) -> text_response(status.service_unavailable, "No go")
  }
}

/// Fails on every request
pub fn crash(_request: Request, _context, _services: Services) -> Response {
  panic as "this controller always fails"
}

pub fn app_router() -> Router(context, Services) {
  router()
  |> route(method: Get, path: "/", controller: whoami, middleware: [])
  |> route(method: Get, path: "/wait", controller: wait_for_go, middleware: [])
  |> route(method: Get, path: "/crash", controller: crash, middleware: [])
}
