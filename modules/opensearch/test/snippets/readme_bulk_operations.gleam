//// README: Bulk Operations
////
//// Indexes two users in one bulk request.

import dream_opensearch/client.{type Client}
import dream_opensearch/document

pub fn bulk_index_users(opensearch: Client) -> Result(String, String) {
  // NDJSON format: action and document on alternating lines
  let ndjson =
    "{ \"index\": { \"_index\": \"users\", \"_id\": \"1\" } }\n"
    <> "{ \"name\": \"Alice\", \"email\": \"alice@example.com\" }\n"
    <> "{ \"index\": { \"_index\": \"users\", \"_id\": \"2\" } }\n"
    <> "{ \"name\": \"Bob\", \"email\": \"bob@example.com\" }\n"

  document.bulk(opensearch, ndjson)
}
