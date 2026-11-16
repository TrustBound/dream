//// README: Client Setup
////
//// Creates a client for a local OpenSearch, and a client that sends HTTP
//// Basic authentication from the user name and password in the URL.

import dream_opensearch/client.{type Client}

// Basic setup
pub fn create_local_client() -> Client {
  client.new("http://localhost:9200")
}

// With authentication: every request sends the user name and password as
// HTTP Basic authentication
pub fn create_client_with_credentials() -> Client {
  client.new("https://user:pass@search.example.com:9200")
}
