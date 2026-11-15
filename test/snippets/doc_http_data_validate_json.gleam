import dream/http/request.{type Request}
import dream/http/response.{type Response, json_response}
import dream/http/status.{bad_request, created}
import dream/http/validation.{validate_json}
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
  case validate_json(request.body, post_decoder()) {
    Ok(post) -> {
      // Valid post data - proceed with business logic
      json_response(created, post_to_json(post))
    }

    Error(validation_error) -> {
      let field_json = format_field_as_json(validation_error.field)
      let error_json =
        json.object([
          #("error", json.string(validation_error.message)),
          #("field", field_json),
        ])
      json_response(bad_request, json.to_string(error_json))
    }
  }
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
