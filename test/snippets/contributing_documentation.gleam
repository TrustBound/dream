//// A documented public function. Shown in docs/contributing/contributing.md.

import dream/http/response.{type Response, text_response}

/// Creates a plain-text response that greets a person by name.
///
/// ## Example
///
/// ### Greet a person <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/contributing_documentation_example.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response.{type Response}
/// import snippets/contributing_documentation.{create_greeting_response}
///
/// pub fn greet_ada() -> Response {
///   create_greeting_response("Ada")
/// }
/// ```
pub fn create_greeting_response(name: String) -> Response {
  text_response(200, "Hello, " <> name <> "!")
}
