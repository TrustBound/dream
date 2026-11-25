//// BEAM guide: a mailbox that grows

import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import snippets/beam_guide_bottleneck.{type PriceMessage, GetPrice}

pub type LogMessage {
  Log(line: String)
  LogAndReply(line: String, reply: Subject(Nil))
}

/// A logger process that writes each line with `write`
pub fn start_logger(
  write: fn(String) -> Nil,
) -> actor.StartResult(Subject(LogMessage)) {
  actor.new(Nil)
  |> actor.on_message(fn(state, message) {
    case message {
      Log(line) -> write(line)
      LogAndReply(line, reply) -> {
        write(line)
        process.send(reply, Nil)
      }
    }
    actor.continue(state)
  })
  |> actor.start
}

/// Wrong: returns at once. When requests log faster than the logger
/// writes, the lines wait in the logger's mailbox, with no limit.
pub fn log(logger: Subject(LogMessage), line: String) -> Nil {
  process.send(logger, Log(line))
}

/// Fix: waits until the logger wrote the line. A request can never get
/// ahead of the logger, so the mailbox holds at most one line for each
/// request that logs at the same time.
pub fn log_and_wait(logger: Subject(LogMessage), line: String) -> Nil {
  process.call(logger, waiting: 1000, sending: LogAndReply(line, _))
}

/// Wrong: after the timeout, a late reply comes to this process and
/// stays in its mailbox, because nothing receives it
pub fn price_with_own_timeout(
  prices: Subject(PriceMessage),
  sku: String,
  timeout: Int,
) -> Result(Int, Nil) {
  let reply = process.new_subject()
  process.send(prices, GetPrice(sku, reply))
  case process.receive(reply, within: timeout) {
    Ok(price) -> price
    Error(Nil) -> Error(Nil)
  }
}
