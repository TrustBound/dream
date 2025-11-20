//// Post view - presentation logic for simple example
////
//// Pure formatting functions - no Response objects.

/// Format hello world message
pub fn format_index() -> String {
  "Hello, World!"
}

/// Format user and post information along with HTTP response
pub fn format_show(user: String, post: String, http_body: String) -> String {
  "User: "
  <> user
  <> ", Post: "
  <> post
  <> "\n\nHTTPS Response:\n\n"
  <> http_body
}

/// Format error message
pub fn format_error(error: String) -> String {
  "Error: " <> error
}
