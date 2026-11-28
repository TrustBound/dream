//// The parcels suite of the guide "Test a Dream app that calls other
//// APIs".

import app_request.{body_text, send}
import dream/http/request.{Get}
import dream/http/response.{type Response}
import dream_test/context
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{describe, it}
import gleam/int
import gleam/result
import parcels/router
import recorded_http/carrier_setup.{
  type App, carrier_port, recorder_mode, start_app, stop_app,
}

pub fn tests() -> TestSuite {
  describe("Parcels", context.setup(start_parcels_app, teardown: stop_app), [
    it("shows a parcel on its way", fn(app: App) {
      get(app, "/parcels/PX-100")
      |> have_answer(
        200,
        "{\"code\":\"PX-100\",\"status\":\"in_transit\",\"eta\":\"2026-12-02\"}",
      )
    }),
    it("shows a delivered parcel", fn(app: App) {
      get(app, "/parcels/PX-200")
      |> have_answer(
        200,
        "{\"code\":\"PX-200\",\"status\":\"delivered\",\"eta\":\"2026-11-20\"}",
      )
    }),
    it("answers 404 for a parcel the carrier does not know", fn(app: App) {
      get(app, "/parcels/PX-404")
      |> have_answer(404, "{\"error\":\"No parcel PX-404\"}")
    }),
  ])
}

fn start_parcels_app() -> Result(App, String) {
  use mode <- result.try(recorder_mode())
  start_app(mode, carrier_port)
}

/// Sends `GET path` through the routes of the app, with the services of
/// the test.
pub fn get(app: App, path: String) -> Response {
  send(router.create_router(), app.services, Get, path, "")
}

/// Passes when the app answers `status` with `body`. When the call to the
/// carrier fails, the app answers 502, and the failure message is its
/// body: the reason, line by line.
pub fn have_answer(
  response: Response,
  status: Int,
  body: String,
) -> Result(AssertionResult, String) {
  case response.status {
    502 if status != 502 -> Ok(fail_with(body_text(response)))
    _ ->
      #(response.status, body_text(response))
      |> should
      |> be_equal(#(status, body))
      |> or_fail_with("GET should answer " <> int.to_string(status))
  }
}
