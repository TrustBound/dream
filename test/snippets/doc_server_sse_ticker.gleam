//// Doc comment example: dream/servers/mist/sse, module "Example (ticker)".

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process
import gleam/int
import gleam/option.{None}

pub type Dependencies {
  Dependencies
}

pub type Tick {
  Tick
}

pub type Ticker {
  Ticker(subject: process.Subject(Tick), count: Int)
}

pub fn handle_events(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Dependencies,
    on_init: handle_init,
    on_message: handle_message,
  )
}

fn handle_init(
  subject: process.Subject(Tick),
  _dependencies: Dependencies,
) -> #(Ticker, option.Option(process.Selector(Tick))) {
  process.send(subject, Tick)
  #(Ticker(subject:, count: 0), None)
}

fn handle_message(
  ticker: Ticker,
  _message: Tick,
  connection: sse.SSEConnection,
  _dependencies: Dependencies,
) -> sse.Action(Ticker, Tick) {
  let count = int.to_string(ticker.count)
  let event =
    sse.event(count)
    |> sse.event_name("tick")
    |> sse.event_id(count)
  case sse.send_event(connection, event) {
    Ok(Nil) -> {
      // The actor receives messages sent to its subject, and messages
      // from the selector that on_init returns
      process.send_after(ticker.subject, 1000, Tick)
      sse.continue_connection(Ticker(..ticker, count: ticker.count + 1))
    }
    Error(Nil) -> sse.stop_connection()
  }
}
