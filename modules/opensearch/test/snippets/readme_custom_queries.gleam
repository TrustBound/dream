//// README: Custom Queries
////
//// Builds a bool query with gleam/json and sends it.

import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

pub fn search_active_users_named_alice(
  opensearch: Client,
) -> Result(String, String) {
  let bool_query =
    json.object([
      #(
        "query",
        json.object([
          #(
            "bool",
            json.object([
              #(
                "must",
                json.preprocessed_array([
                  json.object([
                    #("match", json.object([#("name", json.string("Alice"))])),
                  ]),
                ]),
              ),
              #(
                "filter",
                json.preprocessed_array([
                  json.object([
                    #("term", json.object([#("status", json.string("active"))])),
                  ]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  document.search(opensearch, "users", json.to_string(bool_query))
}
