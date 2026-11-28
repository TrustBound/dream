//// The tests of the app against the fake news service. The suite starts
//// the fake one time, and each test gives the app services that point
//// at one case of the fake.

import app_request.{get}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, group, it}
import fake_news_service.{
  type FakeNews, answers_port, closed_port, failures_port, feed,
}
import services.{Services}

pub fn tests() -> TestSuite {
  describe(
    "News",
    context.setup(fake_news_service.start, teardown: fake_news_service.stop),
    [
      group("GET /headlines", [
        it("answers the headlines as JSON", fn(_fake: FakeNews) {
          let services = news_services(answers_port, "/v2/headlines")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            200,
            "{\"headlines\":["
              <> "{\"title\":\"Gleam on the BEAM\",\"url\":\"https://news.example.com/1\"},"
              <> "{\"title\":\"Dream 3.0.0\",\"url\":\"https://news.example.com/2\"}"
              <> "]}",
          ))
          |> or_fail_with("GET /headlines should answer the headlines")
        }),
        it("answers 502 when the service answers 503", fn(_fake: FakeNews) {
          let services =
            news_services(answers_port, "/v2/headlines-unavailable")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The news service failed: HTTP 503\"}",
          ))
          |> or_fail_with("GET /headlines should answer 502")
        }),
        it("answers 502 when the body is not JSON", fn(_fake: FakeNews) {
          let services = news_services(answers_port, "/v2/headlines-not-json")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The news service failed: The body is not a list of headlines: the JSON has the byte 0x3C\"}",
          ))
          |> or_fail_with("GET /headlines should answer 502")
        }),
        it("answers 504 when the service is slow", fn(_fake: FakeNews) {
          let services = news_services(failures_port, "/slow")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            504,
            "{\"error\":\"The news service did not answer in 500 ms\"}",
          ))
          |> or_fail_with("GET /headlines should answer 504")
        }),
        it("answers 502 when nothing listens", fn(_fake: FakeNews) {
          let services = news_services(closed_port, "/v2/headlines")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The news service failed: Connection failed: Connection refused\"}",
          ))
          |> or_fail_with("GET /headlines should answer 502")
        }),
      ]),
      group("GET /live", [
        it("streams the feed line by line", fn(_fake: FakeNews) {
          let services = live_services("/stream/json")

          let answer = get(services, "/live")

          answer
          |> should
          |> be_equal(#(
            200,
            "{\"event\":\"chunk\",\"number\":1,\"message\":\"JSON event 1\"}\n"
              <> "{\"event\":\"chunk\",\"number\":2,\"message\":\"JSON event 2\"}\n"
              <> "{\"event\":\"chunk\",\"number\":3,\"message\":\"JSON event 3\"}\n"
              <> "{\"event\":\"chunk\",\"number\":4,\"message\":\"JSON event 4\"}\n"
              <> "{\"event\":\"chunk\",\"number\":5,\"message\":\"JSON event 5\"}\n",
          ))
          |> or_fail_with("GET /live should stream the five lines")
        }),
        it("answers 502 when the stream starts with 500", fn(_fake: FakeNews) {
          let services = live_services("/stream/error")

          let answer = get(services, "/live")

          answer
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The news service failed: HTTP 500\"}",
          ))
          |> or_fail_with("GET /live should answer 502")
        }),
        it(
          "ends the stream with the failure when the connection drops",
          fn(_fake: FakeNews) {
            let services = live_services("/stream/drop")

            let answer = get(services, "/live")

            answer
            |> should
            |> be_equal(#(
              200,
              "Drop chunk 1\nDrop chunk 2\n"
                <> "The news service failed: Remote closed connection\n",
            ))
            |> or_fail_with("GET /live should end with the failure")
          },
        ),
      ]),
    ],
  )
}

/// The services of the app with the headlines feed at `path` on `port`.
fn news_services(port: Int, path: String) -> services.Services {
  Services(
    headlines: feed(port, path),
    live: feed(failures_port, "/stream/json"),
  )
}

/// The services of the app with the live feed at `path` on the server
/// with the built-in endpoints.
fn live_services(path: String) -> services.Services {
  Services(
    headlines: feed(answers_port, "/v2/headlines"),
    live: feed(failures_port, path),
  )
}
