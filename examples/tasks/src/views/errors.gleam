//// Error response helpers

import dream/http/response.{type Response, html_response}
import dream/http/status
import templates/components/layout_components
import templates/pages/error

pub fn not_found(message: String) -> Response {
  let content = error.render(error_title: "Not Found", error_message: message)
  let html = layout_components.build_page("Not Found", content)
  html_response(status.not_found, html)
}

pub fn bad_request(message: String) -> Response {
  let content = error.render(error_title: "Bad Request", error_message: message)
  let html = layout_components.build_page("Bad Request", content)
  html_response(status.bad_request, html)
}

pub fn unauthorized(message: String) -> Response {
  let content =
    error.render(error_title: "Unauthorized", error_message: message)
  let html = layout_components.build_page("Unauthorized", content)
  html_response(status.unauthorized, html)
}

pub fn forbidden(message: String) -> Response {
  let content = error.render(error_title: "Forbidden", error_message: message)
  let html = layout_components.build_page("Forbidden", content)
  html_response(status.forbidden, html)
}

pub fn unprocessable_content(message: String) -> Response {
  let content =
    error.render(error_title: "Unprocessable Content", error_message: message)
  let html = layout_components.build_page("Unprocessable Content", content)
  html_response(status.unprocessable_content, html)
}

pub fn conflict(message: String) -> Response {
  let content = error.render(error_title: "Conflict", error_message: message)
  let html = layout_components.build_page("Conflict", content)
  html_response(status.conflict, html)
}

pub fn internal_error() -> Response {
  let content =
    error.render(
      error_title: "Internal Server Error",
      error_message: "An unexpected error occurred. Please try again later.",
    )
  let html = layout_components.build_page("Internal Server Error", content)
  html_response(status.internal_server_error, html)
}
