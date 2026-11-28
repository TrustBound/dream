import dream/http/response.{type Response}
import snippets/contributing_documentation.{create_greeting_response}

pub fn greet_ada() -> Response {
  create_greeting_response("Ada")
}
