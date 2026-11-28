//// The search index of the notes in OpenSearch: a copy of the store that
//// OpenSearch can search. Each function takes the client and the index
//// name from the services.

import dream_opensearch/client.{type Client, type OpenSearchError, Rejected}
import dream_opensearch/document
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/int
import gleam/json
import gleam/result
import gleam/string
import notes/store.{type Note, Note}

/// Which page of the hits to give, and how many hits are on a page
pub type Paging {
  Paging(page: Int, size: Int)
}

/// One page of the notes that match a search
pub type SearchPage {
  SearchPage(total: Int, paging: Paging, notes: List(Note))
}

pub type SearchError {
  /// The request to OpenSearch failed
  SearchFailed(error: OpenSearchError)
  /// OpenSearch answered, but the answer is not the search result we expect
  UnexpectedAnswer(reason: String)
}

/// Creates the index with its mapping when it does not exist. The app
/// calls it one time, at start.
pub fn ensure_index(
  opensearch: Client,
  index: String,
) -> Result(Nil, OpenSearchError) {
  case client.send_request(opensearch, http.Head, "/" <> index, "") {
    Ok(_body) -> Ok(Nil)
    Error(Rejected(status: 404, ..)) ->
      document.create_index(opensearch, index, mapping())
      |> result.replace(Nil)
    Error(error) -> Error(error)
  }
}

/// One shard keeps the scores the same from run to run in a small index.
/// No replicas, because the development cluster has one node: a cluster
/// with more nodes sets replicas.
fn mapping() -> String {
  json.object([
    #(
      "settings",
      json.object([
        #("number_of_shards", json.int(1)),
        #("number_of_replicas", json.int(0)),
      ]),
    ),
    #(
      "mappings",
      json.object([
        #(
          "properties",
          json.object([
            #("id", json.object([#("type", json.string("integer"))])),
            #("title", json.object([#("type", json.string("text"))])),
            #("body", json.object([#("type", json.string("text"))])),
          ]),
        ),
      ]),
    ),
  ])
  |> json.to_string
}

/// Puts `note` in the index, or replaces the copy that is there
pub fn index_note(
  opensearch: Client,
  index: String,
  note: Note,
) -> Result(Nil, OpenSearchError) {
  document.index(opensearch, index, int.to_string(note.id), note_json(note))
  |> result.replace(Nil)
}

/// Removes the note with `id` from the index. A note that is not in the
/// index is not an error: it was written while search was down.
pub fn remove_note(
  opensearch: Client,
  index: String,
  id: Int,
) -> Result(Nil, OpenSearchError) {
  case document.delete(opensearch, index, int.to_string(id)) {
    Ok(_body) -> Ok(Nil)
    Error(Rejected(status: 404, ..)) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

/// The notes whose title or body match `text`, best match first
pub fn search_notes(
  opensearch: Client,
  index: String,
  text: String,
  paging: Paging,
) -> Result(SearchPage, SearchError) {
  use answer <- result.try(
    document.search(opensearch, index, search_query(text, paging))
    |> result.map_error(SearchFailed),
  )
  json.parse(answer, hits_decoder())
  |> result.map(fn(hits) { SearchPage(total: hits.0, paging:, notes: hits.1) })
  |> result.map_error(fn(error) { UnexpectedAnswer(string.inspect(error)) })
}

/// A title match counts twice as much as a body match. The ID breaks a
/// tie, so a page has the same notes each time.
fn search_query(text: String, paging: Paging) -> String {
  json.object([
    #("from", json.int({ paging.page - 1 } * paging.size)),
    #("size", json.int(paging.size)),
    #(
      "query",
      json.object([
        #(
          "multi_match",
          json.object([
            #("query", json.string(text)),
            #("fields", json.array(["title^2", "body"], json.string)),
          ]),
        ),
      ]),
    ),
    #(
      "sort",
      json.preprocessed_array([
        json.string("_score"),
        json.object([#("id", json.string("asc"))]),
      ]),
    ),
  ])
  |> json.to_string
}

fn note_json(note: Note) -> String {
  json.object([
    #("id", json.int(note.id)),
    #("title", json.string(note.title)),
    #("body", json.string(note.body)),
  ])
  |> json.to_string
}

fn hits_decoder() -> Decoder(#(Int, List(Note))) {
  use total <- decode.subfield(["hits", "total", "value"], decode.int)
  use notes <- decode.subfield(
    ["hits", "hits"],
    decode.list(decode.at(["_source"], note_decoder())),
  )
  decode.success(#(total, notes))
}

fn note_decoder() -> Decoder(Note) {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.string)
  decode.success(Note(id:, title:, body:))
}
