//// The status that the app answers for each OpenSearch error

import dream_opensearch/client.{
  InvalidResponseBody, InvalidUrl, NoRecording, Rejected, TimedOut, Unavailable,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import notes/search_failure

pub fn tests() -> TestSuite {
  describe("search_failure", [
    group("status", [
      it("returns 503 for Unavailable", fn() {
        let error = Unavailable(reason: "Connection failed: Connection refused")

        search_failure.status(error)
        |> should
        |> be_equal(503)
        |> or_fail_with("Unavailable should give 503")
      }),
      it("returns 503 for TimedOut", fn() {
        let error = TimedOut(timeout_ms: 2000)

        search_failure.status(error)
        |> should
        |> be_equal(503)
        |> or_fail_with("TimedOut should give 503")
      }),
      it("returns 502 for Rejected", fn() {
        let error = Rejected(status: 400, body: "{\"error\":\"bad query\"}")

        search_failure.status(error)
        |> should
        |> be_equal(502)
        |> or_fail_with("Rejected should give 502")
      }),
      it("returns 502 for InvalidResponseBody", fn() {
        let error = InvalidResponseBody(status: 200)

        search_failure.status(error)
        |> should
        |> be_equal(502)
        |> or_fail_with("InvalidResponseBody should give 502")
      }),
      it("returns 502 for NoRecording", fn() {
        let error =
          NoRecording(
            method: "POST",
            url: "http://localhost:19200/notes/_search",
            details: "No recording matches",
          )

        search_failure.status(error)
        |> should
        |> be_equal(502)
        |> or_fail_with("NoRecording should give 502")
      }),
      it("returns 500 for InvalidUrl", fn() {
        let error = InvalidUrl(reason: "the URL has no host")

        search_failure.status(error)
        |> should
        |> be_equal(500)
        |> or_fail_with("InvalidUrl should give 500")
      }),
    ]),
  ])
}
