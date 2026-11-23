import dream/http/request.{type Request, body_as_string}
import dream/http/response.{type Response, json_response}
import dream/http/status.{bad_request, created}
import dream/http/validation.{type ValidationError, validate_json}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}

pub type CreatePost {
  CreatePost(title: String, body: String, published: Bool)
}

fn post_decoder() -> decode.Decoder(CreatePost) {
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.string)
  use published <- decode.field("published", decode.bool)
  decode.success(CreatePost(title, body, published))
}

pub fn create_post(request: Request, _context, _services) -> Response {
  case body_as_string(request) {
    Ok(body) -> create_post_from_json(body)
    Error(Nil) -> json_response(bad_request, not_text_json())
  }
}

fn create_post_from_json(body: String) -> Response {
  case validate_json(body, post_decoder()) {
    Ok(post) -> {
      // Valid post data - proceed with business logic
      json_response(created, post_to_json(post))
    }

    Error(validation_errors) -> {
      // One object for each field that failed
      let errors_json =
        json.object([
          #("errors", json.array(validation_errors, validation_error_to_json)),
        ])
      json_response(bad_request, json.to_string(errors_json))
    }
  }
}

fn validation_error_to_json(validation_error: ValidationError) -> json.Json {
  json.object([
    #("error", json.string(validation_error.message)),
    #("field", format_field_as_json(validation_error.field)),
  ])
}

fn post_to_json(post: CreatePost) -> String {
  json.object([
    #("title", json.string(post.title)),
    #("body", json.string(post.body)),
    #("published", json.bool(post.published)),
  ])
  |> json.to_string
}

fn format_field_as_json(field: Option(String)) -> json.Json {
  json.nullable(field, json.string)
}

fn not_text_json() -> String {
  json.object([#("error", json.string("Request body is not text"))])
  |> json.to_string
}
