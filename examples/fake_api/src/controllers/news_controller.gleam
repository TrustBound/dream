//// The news of the app, from the feeds of the news service in services.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/response.{json_response, stream_response}
import dream/http/status
import gleam/int
import gleam/json
import news_service.{
  type Headline, type NewsError, NoAnswerInTime, ServiceFailed,
}
import services.{type Services}

const bad_gateway = 502

const gateway_timeout = 504

/// GET /headlines: the headlines as JSON.
pub fn headlines(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case news_service.get_headlines(services.headlines) {
    Ok(headlines) -> json_response(status.ok, headlines_json(headlines))
    Error(error) -> error_response(error)
  }
}

/// GET /live: the live feed, streamed from the service to the client
/// line by line.
pub fn live(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case news_service.stream_live(services.live) {
    Ok(lines) -> stream_response(status.ok, lines, "application/x-ndjson")
    Error(error) -> error_response(error)
  }
}

/// The answer to each error of the news service.
fn error_response(error: NewsError) -> Response {
  case error {
    NoAnswerInTime(timeout_ms:) ->
      json_response(
        gateway_timeout,
        error_json(
          "The news service did not answer in "
          <> int.to_string(timeout_ms)
          <> " ms",
        ),
      )
    ServiceFailed(reason:) ->
      json_response(
        bad_gateway,
        error_json("The news service failed: " <> reason),
      )
  }
}

fn headlines_json(headlines: List(Headline)) -> String {
  json.object([
    #(
      "headlines",
      json.array(headlines, fn(headline) {
        json.object([
          #("title", json.string(headline.title)),
          #("url", json.string(headline.url)),
        ])
      }),
    ),
  ])
  |> json.to_string
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))]) |> json.to_string
}
