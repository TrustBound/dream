//// The JSON of the notes app

import gleam/json.{type Json}
import notes/search_index.{type SearchPage}
import notes/store.{type Note}

/// A note that the app wrote. `indexed` is `False` when the store has the
/// change and the search index does not.
pub fn written_note_json(note: Note, indexed: Bool) -> String {
  json.object([
    #("id", json.int(note.id)),
    #("title", json.string(note.title)),
    #("body", json.string(note.body)),
    #("indexed", json.bool(indexed)),
  ])
  |> json.to_string
}

/// A note that the app removed
pub fn deleted_note_json(note: Note, indexed: Bool) -> String {
  json.object([#("id", json.int(note.id)), #("indexed", json.bool(indexed))])
  |> json.to_string
}

/// One page of search hits
pub fn search_page_json(page: SearchPage) -> String {
  json.object([
    #("total", json.int(page.total)),
    #("page", json.int(page.paging.page)),
    #("size", json.int(page.paging.size)),
    #("notes", json.array(page.notes, note_json)),
  ])
  |> json.to_string
}

pub fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string
}

fn note_json(note: Note) -> Json {
  json.object([
    #("id", json.int(note.id)),
    #("title", json.string(note.title)),
    #("body", json.string(note.body)),
  ])
}
