//// Example for the doc of `sse.continue_connection_with_selector`.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process.{type Selector, type Subject}
import gleam/option.{type Option, None}

pub type Message {
  Start
  Greeting(String)
}

pub fn greetings(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: start,
    on_message: handle_message,
  )
}

fn start(
  subject: Subject(Message),
  _dependencies: Nil,
) -> #(Nil, Option(Selector(Message))) {
  process.send(subject, Start)
  #(Nil, None)
}

fn handle_message(
  state: Nil,
  message: Message,
  connection: sse.SSEConnection,
  _dependencies: Nil,
) -> sse.Action(Nil, Message) {
  case message {
    Start -> listen_for_greetings(state)
    Greeting(text) -> send_greeting(state, connection, text)
  }
}

fn listen_for_greetings(state: Nil) -> sse.Action(Nil, Message) {
  let greetings = process.new_subject()
  process.send(greetings, "hello")
  // From now on the actor receives the messages sent to greetings
  let selector =
    process.new_selector()
    |> process.select_map(greetings, Greeting)
  sse.continue_connection_with_selector(state, selector)
}

fn send_greeting(
  state: Nil,
  connection: sse.SSEConnection,
  text: String,
) -> sse.Action(Nil, Message) {
  case sse.send_event(connection, sse.event(text)) {
    Ok(Nil) -> sse.continue_connection(state)
    Error(Nil) -> sse.stop_connection()
  }
}
