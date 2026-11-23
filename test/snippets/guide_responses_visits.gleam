//// Responses guide: the visit counter of
//// examples/simple/src/controllers/visits_controller.gleam
////
//// The same code as the example, so the test of the guide tests it.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/cookie.{get_cookie_value, simple_cookie}
import dream/http/response.{Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/int
import gleam/option
import gleam/result

/// GET /visits
pub fn show(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let visits =
    get_cookie_value(request.cookies, "visits")
    |> option.to_result(Nil)
    |> result.try(int.parse)
    |> result.unwrap(0)
    |> int.add(1)
  let count = int.to_string(visits)

  Response(..text_response(status.ok, "Visit number " <> count), cookies: [
    simple_cookie("visits", count),
  ])
}
