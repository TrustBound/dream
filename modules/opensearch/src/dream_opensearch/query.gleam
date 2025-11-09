//// OpenSearch query builder helpers

import gleam/json

/// Build a match_all query
pub fn match_all() -> String {
  json.object([#("query", json.object([#("match_all", json.object([]))]))])
  |> json.to_string()
}

/// Build a simple term query
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

