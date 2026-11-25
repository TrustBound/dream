//// BEAM guide: a linked helper process, and a monitored one

import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/erlang/process

/// Wrong: `process.spawn` links the helper to the request process, so a
/// crash of the helper also ends the request
pub fn render_with_linked_helper(render: fn() -> String) -> Response {
  let reply = process.new_subject()
  process.spawn(fn() { process.send(reply, render()) })
  case process.receive(reply, within: 1000) {
    Ok(text) -> text_response(status.ok, text)
    Error(Nil) -> text_response(status.service_unavailable, "Too slow")
  }
}

/// Fix: start the helper unlinked and monitor it. A crash of the helper
/// is then a message.
pub fn render_with_monitored_helper(render: fn() -> String) -> Response {
  case run_in_helper(render) {
    Ok(text) -> text_response(status.ok, text)
    Error(Nil) ->
      text_response(status.internal_server_error, "The page did not render")
  }
}

/// Runs `work` in a new process. Returns `Error(Nil)` when that process
/// ends without an answer, for example when it crashes.
pub fn run_in_helper(work: fn() -> a) -> Result(a, Nil) {
  let reply = process.new_subject()
  let helper = process.spawn_unlinked(fn() { process.send(reply, work()) })
  let monitor = process.monitor(helper)
  let result =
    process.new_selector()
    |> process.select_map(reply, Ok)
    |> process.select_specific_monitor(monitor, fn(_down) { Error(Nil) })
    |> process.selector_receive_forever
  process.demonitor_process(monitor)
  result
}
