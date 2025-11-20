//// Response helper utilities
////
//// Common helpers for handling responses in controllers.

import dream/http.{type Error, type Response}
import dream/http/error
import types/tag.{type Tag}
import types/task.{type Task}
import views/errors

/// Handle Dream errors and convert to appropriate HTTP responses
pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) -> errors.bad_request(msg)
    error.Unauthorized(_msg) -> errors.bad_request("Unauthorized")
    error.Forbidden(_msg) -> errors.bad_request("Forbidden")
    error.NotFound(msg) -> errors.not_found(msg)
    error.UnprocessableContent(msg) -> errors.bad_request(msg)
    error.InternalServerError(_msg) -> errors.internal_error()
  }
}

/// Extract task from a task-tags pair
pub fn extract_task(pair: #(Task, List(Tag))) -> Task {
  pair.0
}

/// Extract tags indexed by task ID from a task-tags pair
pub fn extract_tags_by_task(pair: #(Task, List(Tag))) -> #(Int, List(Tag)) {
  #({ pair.0 }.id, pair.1)
}
