//// Stream view - presentation logic for streaming example
////
//// Pure formatting functions - no Response objects.

/// Format index/welcome message
pub fn format_index() -> String {
  "Streaming Example Server\n\n"
  <> "Routes:\n"
  <> "  GET /stream - Stream a response from httpbin.org\n"
  <> "  GET /fetch - Fetch and return a response from httpbin.org\n"
}

/// Format streamed response
pub fn format_stream(body: String) -> String {
  "Streamed response:\n\n" <> body
}

/// Format fetched response
pub fn format_fetch(body: String) -> String {
  "Fetched response:\n\n" <> body
}

/// Format error message
pub fn format_error(error: String) -> String {
  "Error: " <> error
}
