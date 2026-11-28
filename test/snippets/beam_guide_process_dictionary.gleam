//// BEAM guide: state in the process dictionary, and state in ETS

import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, route, router}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/result
import snippets/beam_guide_cache.{type Table}

pub type Services {
  Services(visits: Table)
}

type Key {
  VisitCount
}

@external(erlang, "erlang", "get")
fn get(key: Key) -> Dynamic

@external(erlang, "erlang", "put")
fn put(key: Key, value: Int) -> Dynamic

/// Wrong: counts visits in the process dictionary of the process that
/// runs the request
pub fn count_in_process_dictionary(
  _request: Request,
  _context,
  _services: Services,
) -> Response {
  let count = decode.run(get(VisitCount), decode.int) |> result.unwrap(0)
  let _old = put(VisitCount, count + 1)
  text_response(status.ok, int.to_string(count + 1))
}

/// Fix: counts visits in an ETS table that every request shares
pub fn count_in_table(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  let count = beam_guide_cache.increment(services.visits, "visits")
  text_response(status.ok, int.to_string(count))
}

pub fn app_router() -> Router(context, Services) {
  router()
  |> route(
    method: Get,
    path: "/dictionary",
    controller: count_in_process_dictionary,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/table",
    controller: count_in_table,
    middleware: [],
  )
}
