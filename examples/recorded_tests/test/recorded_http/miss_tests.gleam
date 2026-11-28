//// Two parcels tests with no recording, for the guide. They run only
//// from the output checks, which compare their report.

import dream_http_client/recorder
import dream_test/context
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import recorded_http/carrier_setup.{type App, start_app, stop_app}
import recorded_http/parcels_tests.{get, have_answer}

pub fn tests() -> TestSuite {
  describe(
    "Parcels",
    context.setup(
      fn() { start_app(recorder.Playback, 19_871) },
      teardown: stop_app,
    ),
    [
      it("shows parcel PX-300", fn(app: App) {
        get(app, "/parcels/PX-300")
        |> have_answer(
          200,
          "{\"code\":\"PX-300\",\"status\":\"in_transit\",\"eta\":\"2026-12-04\"}",
        )
      }),
      it("shows a parcel on its way from port 19871", fn(app: App) {
        get(app, "/parcels/PX-100")
        |> have_answer(
          200,
          "{\"code\":\"PX-100\",\"status\":\"in_transit\",\"eta\":\"2026-12-02\"}",
        )
      }),
    ],
  )
}
