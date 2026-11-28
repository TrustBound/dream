//// BEAM guide: a call that waits forever, and a call with a timeout

import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/erlang/process.{type Subject}
import gleam/int
import snippets/beam_guide_bottleneck.{type PriceMessage, GetPrice}
import snippets/beam_guide_links.{run_in_helper}

/// Wrong: if the price service never answers, the request never ends
pub fn price_or_wait_forever(
  prices: Subject(PriceMessage),
  sku: String,
) -> Response {
  case process.call_forever(prices, GetPrice(sku, _)) {
    Ok(price) -> text_response(status.ok, int.to_string(price))
    Error(Nil) -> text_response(status.not_found, "No such product")
  }
}

/// Fix: wait at most `timeout` milliseconds, and answer 503 after that
pub fn price_with_timeout(
  prices: Subject(PriceMessage),
  sku: String,
  timeout: Int,
) -> Response {
  let answer =
    run_in_helper(fn() {
      process.call(prices, waiting: timeout, sending: GetPrice(sku, _))
    })
  case answer {
    Ok(Ok(price)) -> text_response(status.ok, int.to_string(price))
    Ok(Error(Nil)) -> text_response(status.not_found, "No such product")
    Error(Nil) ->
      text_response(
        status.service_unavailable,
        "The price service did not answer in time",
      )
  }
}
