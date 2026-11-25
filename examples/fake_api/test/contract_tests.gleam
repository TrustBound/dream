//// The contract of the headlines feed: the same test runs against the
//// fake, and against the real service when `NEWS_HEADLINES_URL` is set.

import dream_http_client/client.{type ClientRequest}
import dream_mock_server/server.{type ServerHandle}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{type ContextNode, describe, it, skip}
import envoy
import fake_news_service.{feed, news_routes}
import gleam/http
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import news_service

/// The port of the fake in this suite.
pub const contract_port = 19_913

pub fn tests() -> TestSuite {
  describe(
    "The headlines contract",
    context.setup(start_fake, teardown: stop_fake),
    [
      it("holds for the fake", fn(_fake: ServerHandle) {
        let headlines = feed(contract_port, "/v2/headlines")

        has_headlines(headlines)
      }),
      real_service_test(envoy.get("NEWS_HEADLINES_URL")),
    ],
  )
}

/// Passes when the feed answers at least one headline with a title and a
/// URL: the shape that the app needs.
fn has_headlines(feed: ClientRequest) -> Result(AssertionResult, String) {
  let count = news_service.get_headlines(feed) |> result.map(list.length)

  count
  |> result.map(fn(count) { count > 0 })
  |> should
  |> be_equal(Ok(True))
  |> or_fail_with("the feed should answer at least one headline")
}

fn real_service_test(url: Result(String, Nil)) -> ContextNode(ServerHandle) {
  case url {
    Ok(text) ->
      it("holds for the real service", fn(_fake: ServerHandle) {
        use headlines <- result.try(real_feed(text))
        has_headlines(headlines)
      })
    Error(Nil) ->
      skip("holds for the real service", fn(_fake: ServerHandle) {
        Error("Set NEWS_HEADLINES_URL to run it")
      })
  }
}

/// The request of the real headlines feed at `text`, with the timeouts
/// of the app.
fn real_feed(text: String) -> Result(ClientRequest, String) {
  use parsed <- result.try(
    uri.parse(text) |> result.replace_error("NEWS_HEADLINES_URL is not a URL"),
  )
  use host <- result.try(option.to_result(
    parsed.host,
    "NEWS_HEADLINES_URL has no host",
  ))
  let scheme = scheme_of(parsed)
  Ok(news_service.feed_request(
    scheme,
    host,
    option.unwrap(parsed.port, default_port(scheme)),
    parsed.path,
  ))
}

fn scheme_of(parsed: Uri) -> http.Scheme {
  case parsed.scheme {
    Some("http") -> http.Http
    _ -> http.Https
  }
}

fn default_port(scheme: http.Scheme) -> Int {
  case scheme {
    http.Http -> 80
    http.Https -> 443
  }
}

fn start_fake() -> Result(ServerHandle, String) {
  server.start_with_config(contract_port, news_routes())
  |> result.map_error(string.inspect)
}

fn stop_fake(fake: ServerHandle) -> Result(Nil, String) {
  server.stop(fake)
  Ok(Nil)
}
