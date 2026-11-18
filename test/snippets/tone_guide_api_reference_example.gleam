import gleam/option.{type Option}
import snippets/tone_guide_api_reference.{match_path}

pub fn match_user_path() -> Option(List(#(String, String))) {
  match_path("/users/:id", "/users/123")
  // -> Some([#("id", "123")])
}
