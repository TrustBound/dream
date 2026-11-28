//// The client of the news service. Each feed of the service has its own
//// URL, so each function takes the request of one feed as its first
//// parameter, and returns a `NewsError` that says what went wrong.

import dream_http_client/client.{type ClientRequest, type StreamFailure}
import gleam/bytes_tree.{type BytesTree}
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder.{type Yielder}

pub type Headline {
  Headline(title: String, url: String)
}

pub type NewsError {
  /// The service did not answer in time.
  NoAnswerInTime(timeout_ms: Int)
  /// Any other failure: an error status, no connection, a body that is
  /// not the JSON we expect.
  ServiceFailed(reason: String)
}

/// The request of one feed of the news service. Each call waits at most
/// 1 second for a connection, and at most 2 seconds for the answer.
pub fn feed_request(
  scheme: http.Scheme,
  host: String,
  port: Int,
  path: String,
) -> ClientRequest {
  client.new()
  |> client.scheme(scheme)
  |> client.host(host)
  |> client.port(port)
  |> client.path(path)
  |> client.connect_timeout(1000)
  |> client.timeout(2000)
  |> client.add_header("accept", "application/json")
}

/// The headlines of the feed, from `{"headlines": [{"title", "url"}]}`.
pub fn get_headlines(feed: ClientRequest) -> Result(List(Headline), NewsError) {
  use response <- result.try(
    client.send(feed) |> result.map_error(send_error_to_news_error),
  )
  json.parse_bits(response.body, headlines_decoder())
  |> result.map_error(fn(error) {
    ServiceFailed("The body is not a list of headlines: " <> describe(error))
  })
}

/// The live feed, line by line as the service sends it. The first chunk
/// tells if the service answered, so an error status or a timeout is an
/// `Error` here, before the status of our own response goes out.
pub fn stream_live(
  feed: ClientRequest,
) -> Result(Yielder(BitArray), NewsError) {
  case yielder.step(client.stream_yielder(feed)) {
    yielder.Next(Ok(first), rest) ->
      Ok(
        yielder.single(Ok(first))
        |> yielder.append(rest)
        |> yielder.map(chunk_or_failure_line),
      )
    yielder.Next(Error(failure), _rest) ->
      Error(stream_failure_to_news_error(failure))
    yielder.Done -> Ok(yielder.empty())
  }
}

// After the first chunk, our status is already sent. A failure can only
// end the stream with a line that says what went wrong.
fn chunk_or_failure_line(chunk: Result(BytesTree, StreamFailure)) -> BitArray {
  case chunk {
    Ok(bytes) -> bytes_tree.to_bit_array(bytes)
    Error(failure) -> <<
      "The news service failed: ":utf8,
      client.stream_failure_to_string(failure):utf8,
      "\n":utf8,
    >>
  }
}

fn send_error_to_news_error(error: client.SendError) -> NewsError {
  case error {
    client.ResponseError(response:) -> status_to_news_error(response.status)
    client.RequestError(error:) -> transport_error_to_news_error(error)
  }
}

fn stream_failure_to_news_error(failure: StreamFailure) -> NewsError {
  case failure {
    client.HttpFailure(response:) -> status_to_news_error(response.status)
    client.TransportFailure(error:) -> transport_error_to_news_error(error)
  }
}

fn status_to_news_error(status: Int) -> NewsError {
  ServiceFailed("HTTP " <> int.to_string(status))
}

fn transport_error_to_news_error(error: client.TransportError) -> NewsError {
  case error {
    client.TimedOut(timeout_ms:) -> NoAnswerInTime(timeout_ms)
    _ -> ServiceFailed(client.transport_error_to_string(error))
  }
}

fn describe(error: json.DecodeError) -> String {
  case error {
    json.UnableToDecode(errors) ->
      errors |> list.map(describe_decode_error) |> string.join("; ")
    json.UnexpectedEndOfInput -> "the JSON ends too soon"
    json.UnexpectedByte(byte) -> "the JSON has the byte " <> byte
    json.UnexpectedSequence(sequence) -> "the JSON has " <> sequence
  }
}

fn describe_decode_error(error: decode.DecodeError) -> String {
  "expected "
  <> error.expected
  <> " at "
  <> string.join(error.path, ".")
  <> ", found "
  <> error.found
}

fn headlines_decoder() -> Decoder(List(Headline)) {
  decode.at(["headlines"], decode.list(headline_decoder()))
}

fn headline_decoder() -> Decoder(Headline) {
  use title <- decode.field("title", decode.string)
  use url <- decode.field("url", decode.string)
  decode.success(Headline(title:, url:))
}
