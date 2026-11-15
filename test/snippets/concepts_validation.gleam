//// Concepts: validation and response building stay separate

import dream/http.{type Request, type Response, json_response, validate_json}
import dream/http/status
import dream/http/validation.{type ValidationError}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/process.{type Subject}
import gleam/json

pub type Note {
  Note(title: String)
}

pub type Services {
  Services(notes: Subject(Note))
}

pub fn create_note(
  request: Request,
  _context: context,
  services: Services,
) -> Response {
  let decoder = note_decoder()
  case validate_json(request.body, decoder) {
    Ok(data) -> create_with_data(services, data)
    Error(err) -> json_response(status.bad_request, error_json(err))
  }
}

fn note_decoder() -> Decoder(Note) {
  use title <- decode.field("title", decode.string)
  decode.success(Note(title: title))
}

fn create_with_data(services: Services, note: Note) -> Response {
  process.send(services.notes, note)
  json_response(
    status.created,
    json.to_string(json.object([#("title", json.string(note.title))])),
  )
}

fn error_json(err: ValidationError) -> String {
  json.object([#("error", json.string(err.message))])
  |> json.to_string()
}
