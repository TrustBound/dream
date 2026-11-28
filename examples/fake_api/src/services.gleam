//// The services of the app: what each controller needs from outside.

import dream_http_client/client.{type ClientRequest}
import gleam/http
import news_service

/// The news service gives each feed as its own URL, so the app keeps one
/// request for each feed.
pub type Services {
  Services(headlines: ClientRequest, live: ClientRequest)
}

/// The services of the running app: the feeds of the news service at
/// their real addresses. The app builds the requests one time, at start.
pub fn initialize_services() -> Services {
  Services(
    headlines: news_service.feed_request(
      http.Https,
      "news.example.com",
      443,
      "/v2/headlines",
    ),
    live: news_service.feed_request(
      http.Https,
      "news.example.com",
      443,
      "/v2/live",
    ),
  )
}
