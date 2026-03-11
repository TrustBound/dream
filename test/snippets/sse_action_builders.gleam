//// SSE Action Builders
////
//// Example snippet showing how to create SSE loop actions.

import dream/servers/mist/sse
import gleam/erlang/process

pub fn build_actions() -> Result(Nil, Nil) {
  let _continue: sse.Action(Int, String) = sse.continue_connection(0)

  let selector = process.new_selector()
  let _continue_sel: sse.Action(Int, String) =
    sse.continue_connection_with_selector(0, selector)

  let _stop: sse.Action(Int, String) = sse.stop_connection()

  Ok(Nil)
}
