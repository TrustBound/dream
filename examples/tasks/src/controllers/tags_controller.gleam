//// Tags controller - HTTP handlers

import context.{type TasksContext}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, html_response, json_response}
import dream/http/status
import gleam/option
import models/tag/tag_model
import models/task/model as task_model
import services.{type Services}
import types/tag.{TagData}
import views/errors
import views/tag_view
import views/task_view

/// List all tags
pub fn index(
  _request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  case tag_model.list(services.db) {
    Ok(tags) -> json_response(status.ok, tag_view.list_to_json(tags))
    Error(_) -> errors.internal_error()
  }
}

/// Create a new tag
pub fn create(
  _request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  // Placeholder - would need JSON validation
  let data = TagData(name: "New Tag", color: option.None)

  case tag_model.get_or_create(services.db, data) {
    Ok(tag) -> json_response(status.ok, tag_view.to_json(tag))
    Error(_) -> errors.internal_error()
  }
}

/// Add tag to task
pub fn add_to_task(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "task_id")
  let assert Ok(task_id) = param.as_int

  // Would need to get tag_id from query params or body
  let tag_id = 1

  case tag_model.add_to_task(services.db, task_id, tag_id) {
    Ok(_) -> {
      // Return updated task card
      case task_model.get(services.db, task_id) {
        Ok(task) -> {
          let tags = case tag_model.get_tags_for_task(services.db, task.id) {
            Ok(t) -> t
            Error(_) -> []
          }
          html_response(status.ok, task_view.card(task, tags))
        }
        Error(_) -> errors.internal_error()
      }
    }
    Error(_) -> errors.internal_error()
  }
}

/// Remove tag from task
pub fn remove_from_task(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(task_param) = get_param(request, "task_id")
  let assert Ok(task_id) = task_param.as_int
  let assert Ok(tag_param) = get_param(request, "tag_id")
  let assert Ok(tag_id) = tag_param.as_int

  case tag_model.remove_from_task(services.db, task_id, tag_id) {
    Ok(_) -> {
      // Return updated task card
      case task_model.get(services.db, task_id) {
        Ok(task) -> {
          let tags = case tag_model.get_tags_for_task(services.db, task.id) {
            Ok(t) -> t
            Error(_) -> []
          }
          html_response(status.ok, task_view.card(task, tags))
        }
        Error(_) -> errors.internal_error()
      }
    }
    Error(_) -> errors.internal_error()
  }
}
