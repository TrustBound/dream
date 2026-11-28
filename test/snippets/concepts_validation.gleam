//// Concepts: validation and response building stay separate

import dream/http.{type Request, type Response, json_response, validate_json}
import dream/http/request.{body_as_string}
import dream/http/status
import dream/http/validation.{type ValidationError}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/list

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
  case body_as_string(request) {
    Ok(body) -> create_from_body(services, body)
    Error(Nil) ->
      json_response(
        status.bad_request,
        message_json("Request body is not text"),
      )
  }
}

fn create_from_body(services: Services, body: String) -> Response {
  let decoder = note_decoder()
  case validate_json(body, decoder) {
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

// One message for each field that failed
fn error_json(errors: List(ValidationError)) -> String {
  json.object([
    #("errors", json.array(list.map(errors, error_message), json.string)),
  ])
  |> json.to_string()
}

fn error_message(err: ValidationError) -> String {
  err.message
}

fn message_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string()
}
