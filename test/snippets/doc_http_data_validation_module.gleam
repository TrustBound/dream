//// Example for the module doc of `dream/http/validation`.

import dream/http/request.{type Request, body_as_string}
import dream/http/response.{type Response}
import dream/http/status
import dream/http/validation.{type ValidationError}
import gleam/dynamic/decode
import gleam/json

pub type CreateUser {
  CreateUser(name: String, email: String, age: Int)
}

fn user_decoder() -> decode.Decoder(CreateUser) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(CreateUser(name, email, age))
}

pub fn create(request: Request, _context, _services) -> Response {
  case body_as_string(request) {
    Ok(body) -> create_from_json(body)
    Error(Nil) ->
      response.json_response(
        status.bad_request,
        error_json("Request body is not text"),
      )
  }
}

fn create_from_json(body: String) -> Response {
  let validation_result = validation.validate_json(body, user_decoder())

  case validation_result {
    Ok(user) -> response.json_response(status.created, user_to_json(user))
    Error(validation_error) ->
      create_validation_error_response(validation_error)
  }
}

fn create_validation_error_response(
  validation_error: ValidationError,
) -> Response {
  response.json_response(
    status.bad_request,
    error_json(validation_error.message),
  )
}

fn user_to_json(user: CreateUser) -> String {
  json.object([
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
    #("age", json.int(user.age)),
  ])
  |> json.to_string
}

fn error_json(message: String) -> String {
  json.to_string(json.object([#("error", json.string(message))]))
}
