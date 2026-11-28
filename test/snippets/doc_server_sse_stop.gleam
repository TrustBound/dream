//// Example for the doc of `sse.stop_connection`.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/option.{type Option, None}

pub type Tick {
  Tick
}

pub type Countdown {
  Countdown(subject: Subject(Tick), count: Int)
}

pub fn countdown(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: start_countdown,
    on_message: count_down,
  )
}

fn start_countdown(
  subject: Subject(Tick),
  _dependencies: Nil,
) -> #(Countdown, Option(Selector(Tick))) {
  process.send(subject, Tick)
  #(Countdown(subject: subject, count: 3), None)
}

fn count_down(
  countdown: Countdown,
  _message: Tick,
  connection: sse.SSEConnection,
  _dependencies: Nil,
) -> sse.Action(Countdown, Tick) {
  case countdown.count {
    // Stop after "1": the actor ends and the server closes the stream
    0 -> sse.stop_connection()
    _ -> send_count(countdown, connection)
  }
}

fn send_count(
  countdown: Countdown,
  connection: sse.SSEConnection,
) -> sse.Action(Countdown, Tick) {
  case sse.send_event(connection, sse.event(int.to_string(countdown.count))) {
    Ok(Nil) -> {
      process.send(countdown.subject, Tick)
      sse.continue_connection(
        Countdown(..countdown, count: countdown.count - 1),
      )
    }
    Error(Nil) -> sse.stop_connection()
  }
}
