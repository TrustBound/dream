//// The controllers that write notes. Each one writes the store first, then
//// the search index. A failed index write does not fail the request: the
//// answer says `"indexed": false`, and a reindex task fixes the index.

import dream/context.{type EmptyContext}
import dream/http/error as http_error
import dream/http/params
import dream/http/request.{type Request}
import dream/http/response.{type Response, json_response}
import dream/http/status
import dream_opensearch/client.{type OpenSearchError}
import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/io
import gleam/result
import notes/search_index
import notes/services.{type Services}
import notes/store.{
  type Draft, type Note, type StoreError, Draft, NoteNotFound, StoreDidNotAnswer,
}
import notes/views

/// `POST /notes`: keeps the note, then indexes it
pub fn create(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case params.require_json(request, draft_decoder()) {
    Ok(draft) -> create_note(services, draft)
    Error(error) -> bad_request(error)
  }
}

/// `PUT /notes/:id`: changes the note, then indexes it again
pub fn update(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let draft = {
    use id <- result.try(params.require_int(request, "id"))
    use draft <- result.map(params.require_json(request, draft_decoder()))
    #(id, draft)
  }
  case draft {
    Ok(#(id, draft)) -> update_note(services, id, draft)
    Error(error) -> bad_request(error)
  }
}

/// `DELETE /notes/:id`: removes the note, then removes it from the index
pub fn delete(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case params.require_int(request, "id") {
    Ok(id) -> delete_note(services, id)
    Error(error) -> bad_request(error)
  }
}

fn create_note(services: Services, draft: Draft) -> Response {
  case store.create(services.notes, draft) {
    Ok(note) ->
      json_response(
        status.created,
        views.written_note_json(note, index_note(services, note)),
      )
    Error(error) -> store_failure(error)
  }
}

fn update_note(services: Services, id: Int, draft: Draft) -> Response {
  case store.update(services.notes, id, draft) {
    Ok(note) ->
      json_response(
        status.ok,
        views.written_note_json(note, index_note(services, note)),
      )
    Error(error) -> store_failure(error)
  }
}

fn delete_note(services: Services, id: Int) -> Response {
  case store.delete(services.notes, id) {
    Ok(note) ->
      search_index.remove_note(services.opensearch, services.index, note.id)
      |> is_indexed
      |> views.deleted_note_json(note, _)
      |> json_response(status.ok, _)
    Error(error) -> store_failure(error)
  }
}

/// `True` when the index has the note. The store has it either way.
fn index_note(services: Services, note: Note) -> Bool {
  search_index.index_note(services.opensearch, services.index, note)
  |> is_indexed
}

fn is_indexed(written: Result(Nil, OpenSearchError)) -> Bool {
  case written {
    Ok(Nil) -> True
    Error(error) -> {
      io.println_error(
        "The index missed a change, reindex: " <> client.describe_error(error),
      )
      False
    }
  }
}

fn store_failure(error: StoreError) -> Response {
  case error {
    NoteNotFound(id:) ->
      json_response(
        status.not_found,
        views.error_json("No note " <> int.to_string(id)),
      )
    StoreDidNotAnswer ->
      json_response(
        status.internal_server_error,
        views.error_json("The note store did not answer."),
      )
  }
}

fn bad_request(error: http_error.Error) -> Response {
  json_response(
    http_error.to_status_code(error),
    views.error_json(http_error.message(error)),
  )
}

fn draft_decoder() -> Decoder(Draft) {
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.string)
  decode.success(Draft(title:, body:))
}
