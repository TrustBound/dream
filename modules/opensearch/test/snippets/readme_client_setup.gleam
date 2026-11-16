//// README: Client Setup
////
//// Creates a client for a local OpenSearch, and shows a URL form that the
//// client does not support.

import dream_opensearch/client.{type Client}

// Basic setup
pub fn create_local_client() -> Client {
  client.new("http://localhost:9200")
}

// Do not do this: the client does not read a user name and password from
// the URL, so the request does not authenticate.
pub fn create_client_with_credentials_in_url() -> Client {
  client.new("https://user:pass@search.example.com:9200")
}
