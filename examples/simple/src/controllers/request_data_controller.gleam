//// Request data controller
////
//// Reads the data of a request: a path parameter, the query string, a JSON
//// body that is checked field by field, and a form. Each failure becomes a
//// 400 response that says what is wrong.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, type ValidationError}
import dream/http/request.{body_as_string, get_query_param}
import dream/http/response.{json_response, text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import utilities/response_helpers

/// GET /users/:id: the id must be a whole number
pub fn show_user(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case http.require_int(request, "id") {
    Ok(id) -> text_response(status.ok, "User " <> int.to_string(id))
    Error(error) -> response_helpers.handle_error(error)
  }
}

/// GET /search?q=...: the q parameter is required
pub fn search(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case get_query_param(request.query, "q") {
    Some(term) -> text_response(status.ok, "Results for " <> term)
    None ->
      text_response(
        status.bad_request,
        "Bad Request: the q parameter is missing",
      )
  }
}

/// The JSON body of POST /signups
pub type Signup {
  Signup(name: String, email: String, age: Int)
}

fn signup_decoder() -> decode.Decoder(Signup) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(Signup(name:, email:, age:))
}

/// POST /signups: a JSON body with name, email and age
pub fn create_signup(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case body_as_string(request) {
    Ok(body) -> signup_from_json(body)
    Error(Nil) ->
      text_response(status.bad_request, "Bad Request: the body is not text")
  }
}

fn signup_from_json(body: String) -> Response {
  case http.validate_json(body, signup_decoder()) {
    Ok(signup) -> json_response(status.created, signup_to_json(signup))
    Error(validation_errors) ->
      json_response(status.bad_request, errors_to_json(validation_errors))
  }
}

fn signup_to_json(signup: Signup) -> String {
  json.object([
    #("name", json.string(signup.name)),
    #("email", json.string(signup.email)),
    #("age", json.int(signup.age)),
  ])
  |> json.to_string
}

// One entry for each field that failed, so the client can fix them all at once
fn errors_to_json(validation_errors: List(ValidationError)) -> String {
  json.object([
    #("errors", json.array(validation_errors, validation_error_to_json)),
  ])
  |> json.to_string
}

fn validation_error_to_json(validation_error: ValidationError) -> json.Json {
  json.object([
    #("field", json.nullable(validation_error.field, json.string)),
    #("message", json.string(validation_error.message)),
  ])
}

/// POST /contact: a form with a required email and an optional topic
pub fn create_contact(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let contact = {
    use form <- result.try(http.require_form(request))
    use email <- result.try(http.require_field(form, "email"))
    let topic = option.unwrap(http.field_optional(form, "topic"), "general")
    Ok(#(email, topic))
  }

  case contact {
    Ok(#(email, topic)) ->
      text_response(status.ok, "Thanks, " <> email <> ". Topic: " <> topic)
    Error(error) -> response_helpers.handle_error(error)
  }
}
