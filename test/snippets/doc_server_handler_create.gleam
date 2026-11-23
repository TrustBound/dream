//// Example for the doc of `handler.create`.

import dream/context.{type AppContext, AppContext}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status.{ok}
import dream/router.{route, router}
import dream/servers/mist/handler
import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor
import mist

fn hello(_request: Request, _context: AppContext, _services: Nil) -> Response {
  text_response(ok, "Hello")
}

fn with_request_id(_context: AppContext, request_id: String) -> AppContext {
  AppContext(request_id: request_id)
}

pub fn start(
  port: Int,
) -> Result(actor.Started(static_supervisor.Supervisor), actor.StartError) {
  let app_router =
    router()
    |> route(method: Get, path: "/", controller: hello, middleware: [])
  // A Mist handler: each request gets a fresh AppContext, then the router
  let mist_handler =
    handler.create(
      app_router,
      1_000_000,
      AppContext(request_id: ""),
      Nil,
      with_request_id,
    )
  mist.new(mist_handler)
  |> mist.bind("127.0.0.1")
  |> mist.port(port)
  |> mist.start
}

pub fn stop(started: actor.Started(static_supervisor.Supervisor)) -> Nil {
  process.send_exit(started.pid)
}
