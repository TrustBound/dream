//// BEAM guide: slow work in a request, and the same work in a worker

import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/erlang/process.{type Subject}
import gleam/option
import gleam/otp/actor

pub type Services {
  Services(send_email: fn(String) -> Nil, mailer: Subject(String))
}

/// Wrong: the client waits until the email is sent
pub fn signup_and_wait(
  request: Request,
  _context,
  services: Services,
) -> Response {
  let address = get_query_param(request.query, "email") |> option.unwrap("")
  services.send_email(address)
  text_response(status.ok, "Welcome!")
}

/// Fix: give the email to the mailer process and answer at once
pub fn signup(request: Request, _context, services: Services) -> Response {
  let address = get_query_param(request.query, "email") |> option.unwrap("")
  process.send(services.mailer, address)
  text_response(status.accepted, "Welcome! Look for our email.")
}

/// The mailer process: it sends one email for each address it gets
pub fn start_mailer(
  send_email: fn(String) -> Nil,
) -> actor.StartResult(Subject(String)) {
  actor.new(Nil)
  |> actor.on_message(fn(state, address) {
    send_email(address)
    actor.continue(state)
  })
  |> actor.start
}
