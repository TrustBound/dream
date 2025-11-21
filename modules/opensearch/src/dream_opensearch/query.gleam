//// OpenSearch query builder helpers
////
//// This module provides helper functions to build common OpenSearch query
//// types. These functions return JSON strings that can be passed to
//// `document.search()`.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_opensearch/document
//// import dream_opensearch/query
////
//// // Full-text search
//// let query = query.match("name", "Alice")
//// document.search(client, "users", query)
////
//// // Exact term match
//// let query = query.term("status", "active")
//// document.search(client, "users", query)
//// ```
////
//// ## Custom Queries
////
//// For complex queries, build the JSON manually using `gleam/json`:
////
//// ```gleam
//// import gleam/json
////
//// let query = json.object([
////   #("query", json.object([
////     #("bool", json.object([
////       #("must", json.array([
////         json.object([#("match", json.object([#("name", json.string("Alice"))]))]),
////       ])),
////     ])),
////   ])),
//// ])
//// ```

import gleam/json

/// Build a match_all query
///
/// Creates a query that matches all documents in the index. Useful for
/// retrieving all documents or as a base for filtering.
///
/// ## Returns
///
/// A JSON query string that matches all documents.
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
/// import dream_opensearch/query
///
/// let query = query.match_all()
/// document.search(client, "users", query)
/// ```
pub fn match_all() -> String {
  json.object([#("query", json.object([#("match_all", json.object([]))]))])
  |> json.to_string()
}

/// Build a simple term query
///
/// Creates a query that matches documents where the specified field exactly
/// matches the given value. This is useful for exact matches on keyword fields.
///
/// ## Parameters
///
/// - `field`: The field name to match against
/// - `value`: The exact value to match
///
/// ## Returns
///
/// A JSON query string for the term query.
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
/// import dream_opensearch/query
///
/// // Find all users with status "active"
/// let query = query.term("status", "active")
/// document.search(client, "users", query)
/// ```
pub fn term(field: String, value: String) -> String {
  json.object([
    #(
      "query",
      json.object([
        #("term", json.object([#(field, json.string(value))])),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Build a range query
///
/// Creates a query that matches documents where the specified field falls
/// within the given range (greater than or equal to `gte`, less than or
/// equal to `lte`).
///
/// ## Parameters
///
/// - `field`: The field name to filter on
/// - `gte`: The minimum value (greater than or equal)
/// - `lte`: The maximum value (less than or equal)
///
/// ## Returns
///
/// A JSON query string for the range query.
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
/// import dream_opensearch/query
///
/// // Find products with price between 10 and 100
/// let query = query.range("price", "10", "100")
/// document.search(client, "products", query)
/// ```
pub fn range(field: String, gte: String, lte: String) -> String {
  json.object([
    #(
      "query",
      json.object([
        #(
          "range",
          json.object([
            #(
              field,
              json.object([
                #("gte", json.string(gte)),
                #("lte", json.string(lte)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Build a match query (full-text search)
///
/// Creates a full-text search query that matches documents where the specified
/// field contains the given text. This performs text analysis and is suitable
/// for searching text fields.
///
/// ## Parameters
///
/// - `field`: The field name to search in
/// - `text`: The text to search for
///
/// ## Returns
///
/// A JSON query string for the match query.
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
/// import dream_opensearch/query
///
/// // Search for users with "Alice" in the name field
/// let query = query.match("name", "Alice")
/// document.search(client, "users", query)
/// ```
pub fn match(field: String, text: String) -> String {
  json.object([
    #(
      "query",
      json.object([
        #("match", json.object([#(field, json.string(text))])),
      ]),
    ),
  ])
  |> json.to_string()
}
