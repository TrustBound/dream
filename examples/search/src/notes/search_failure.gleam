//// What the app answers when a request to OpenSearch fails

import dream/http/response.{type Response, json_response}
import dream/http/status
import dream_opensearch/client.{
  type OpenSearchError, InvalidResponseBody, InvalidUrl, NoRecording, Rejected,
  TimedOut, Unavailable,
}
import gleam/io
import notes/views

const bad_gateway = 502

/// The status for a failed request to OpenSearch:
///
/// - 503 when OpenSearch did not answer. The client can try again later.
/// - 502 when OpenSearch answered with an error or with a body we cannot
///   read, or a test has no recording for the request.
/// - 500 when the app has a wrong OpenSearch URL.
pub fn status(error: OpenSearchError) -> Int {
  case error {
    Unavailable(..) | TimedOut(..) -> status.service_unavailable
    Rejected(..) | InvalidResponseBody(..) | NoRecording(..) -> bad_gateway
    InvalidUrl(..) -> status.internal_server_error
  }
}

/// Logs the error for the operator, and answers the client with `status`.
/// The body does not show the error: it can hold the answer of OpenSearch.
pub fn to_response(error: OpenSearchError) -> Response {
  io.println_error(client.describe_error(error))
  let code = status(error)
  json_response(code, views.error_json(message(code)))
}

/// Logs a search answer that the app cannot read, and answers 502
pub fn unexpected_answer_response(reason: String) -> Response {
  io.println_error("Cannot read the OpenSearch answer: " <> reason)
  json_response(bad_gateway, views.error_json(message(bad_gateway)))
}

fn message(code: Int) -> String {
  case code {
    503 -> "Search is unavailable. Try again later."
    _ -> "Search failed."
  }
}
