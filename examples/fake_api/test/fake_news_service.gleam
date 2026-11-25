//// The fake news service of the tests: two mock servers on localhost,
//// started one time for a suite and stopped after its last test.

import dream_http_client/client.{type ClientRequest}
import dream_mock_server/config.{type MockRoute, Exact, MockRoute}
import dream_mock_server/server.{type ServerHandle}
import gleam/http
import gleam/option.{Some}
import gleam/result
import gleam/string
import news_service

/// The two servers of the fake: one with our own answers, and one with
/// the built-in endpoints of `dream_mock_server` for slow and streamed
/// answers.
pub type FakeNews {
  FakeNews(answers: ServerHandle, failures: ServerHandle)
}

/// The port of the server with our own answers.
pub const answers_port = 19_910

/// The port of the server with the built-in endpoints.
pub const failures_port = 19_911

/// A port where nothing listens.
pub const closed_port = 19_912

/// Our own answers: one path for each case that a test needs.
pub fn news_routes() -> List(MockRoute) {
  [
    MockRoute(
      path: "/v2/headlines",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"headlines\":["
        <> "{\"title\":\"Gleam on the BEAM\",\"url\":\"https://news.example.com/1\"},"
        <> "{\"title\":\"Dream 3.0.0\",\"url\":\"https://news.example.com/2\"}"
        <> "]}",
    ),
    MockRoute(
      path: "/v2/headlines-unavailable",
      path_match: Exact,
      method: Some(http.Get),
      status: 503,
      body: "Service Unavailable",
    ),
    MockRoute(
      path: "/v2/headlines-not-json",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "<html>Down for maintenance</html>",
    ),
  ]
}

/// Starts both servers. When the second one cannot start, it stops the
/// first one, so that no server stays on after a failed setup.
pub fn start() -> Result(FakeNews, String) {
  use answers <- result.try(
    server.start_with_config(answers_port, news_routes())
    |> result.map_error(string.inspect),
  )
  case server.start(failures_port) {
    Ok(failures) -> Ok(FakeNews(answers:, failures:))
    Error(start_error) -> {
      server.stop(answers)
      Error(string.inspect(start_error))
    }
  }
}

pub fn stop(fake: FakeNews) -> Result(Nil, String) {
  server.stop(fake.answers)
  server.stop(fake.failures)
  Ok(Nil)
}

/// The request of a feed at `path` on the fake, with a timeout of 500 ms,
/// so that the test of a slow answer is fast.
pub fn feed(port: Int, path: String) -> ClientRequest {
  news_service.feed_request(http.Http, "localhost", port, path)
  |> client.timeout(500)
}
