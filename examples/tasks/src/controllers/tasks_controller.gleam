//// Tasks controller - HTTP handlers with HTMX support

import context.{type TasksContext}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, empty_response, html_response}
import dream/http/status
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import models/tag/model as tag_model
import models/task/task_model
import services.{type Services}
import types/tag.{type Tag}
import types/task.{type Task, TaskData}
import views/errors
import views/task_view

/// Show single task
pub fn show(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "task_id")
  let assert Ok(task_id) = param.as_int

  case task_model.get(services.db, task_id) {
    Ok(task) -> show_with_tags(services, task, param.format)
    Error(_) -> errors.not_found("Task not found")
  }
}

fn show_with_tags(
  services: Services,
  task: Task,
  format: option.Option(String),
) -> Response {
  case tag_model.get_tags_for_task(services.db, task.id) {
    Ok(tags) -> respond_with_format(task, tags, format)
    Error(_) -> respond_with_format(task, [], format)
  }
}

fn respond_with_format(
  task: Task,
  tags: List(Tag),
  format: option.Option(String),
) -> Response {
  case format {
    option.Some("htmx") -> html_response(status.ok, task_view.card(task, tags))
    _ -> html_response(status.ok, task_view.to_json(task))
  }
}

/// List all tasks
pub fn index(
  _request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  io.println("Index controller: Fetching tasks...")
  case task_model.list(services.db) {
    Ok(tasks) -> {
      io.println(
        "Index controller: Got "
        <> int.to_string(list.length(tasks))
        <> " tasks",
      )
      index_with_tags(services, tasks)
    }
    Error(_) -> {
      io.println("Index controller: Error fetching tasks")
      errors.internal_error()
    }
  }
}

fn index_with_tags(services: Services, tasks: List(Task)) -> Response {
  // Get tags for all tasks
  let tags_by_task = build_tags_by_task(services, tasks)
  html_response(status.ok, task_view.index_page(tasks, tags_by_task))
}

fn build_tags_by_task(
  services: Services,
  tasks: List(Task),
) -> List(#(Int, List(Tag))) {
  case tasks {
    [] -> []
    [task, ..rest] -> {
      let tags = case tag_model.get_tags_for_task(services.db, task.id) {
        Ok(t) -> t
        Error(_) -> []
      }
      [#(task.id, tags), ..build_tags_by_task(services, rest)]
    }
  }
}

/// Create a new task
pub fn create(
  _request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  // For now, return placeholder - would need JSON validation
  let data =
    TaskData(
      title: "New Task",
      description: option.None,
      completed: False,
      priority: 3,
      due_date: option.None,
      position: 0,
      project_id: option.None,
    )

  case task_model.create(services.db, data) {
    Ok(task) -> html_response(status.ok, task_view.card(task, []))
    Error(_) -> errors.internal_error()
  }
}

/// Update a task
pub fn update(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "task_id")
  let assert Ok(task_id) = param.as_int

  // Placeholder - would need JSON validation
  let data =
    TaskData(
      title: "Updated Task",
      description: option.None,
      completed: False,
      priority: 3,
      due_date: option.None,
      position: 0,
      project_id: option.None,
    )

  case task_model.update(services.db, task_id, data) {
    Ok(task) -> html_response(status.ok, task_view.card(task, []))
    Error(_) -> errors.internal_error()
  }
}

/// Delete a task
pub fn delete(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "task_id")
  let assert Ok(task_id) = param.as_int

  case task_model.delete(services.db, task_id) {
    Ok(_) -> empty_response(status.no_content)
    Error(_) -> errors.internal_error()
  }
}

/// Toggle task completion
pub fn toggle(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "task_id")
  let assert Ok(task_id) = param.as_int

  case task_model.toggle_completed(services.db, task_id) {
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

/// Reorder task (update position)
pub fn reorder(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "task_id")
  let assert Ok(task_id) = param.as_int

  // Would need to get position from request body
  let new_position = 0

  case task_model.update_position(services.db, task_id, new_position) {
    Ok(_) -> empty_response(status.ok)
    Error(_) -> errors.internal_error()
  }
}
