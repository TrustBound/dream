//// Tasks controller - HTTP handlers with HTMX support

import context.{type TasksContext}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, html_response}
import dream/http/status
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import models/tag/tag_model
import models/task/task_model
import services.{type Services}
import types/tag.{type Tag}
import types/task.{type Task, TaskData}
import utilities/form_parser
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

/// Show edit form for a task
pub fn edit(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "task_id")
  let assert Ok(task_id) = param.as_int

  case task_model.get(services.db, task_id) {
    Ok(task) -> html_response(status.ok, task_view.edit_form(task))
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
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let form_data = form_parser.parse_form_body(request.body)
  let title = form_parser.get_form_field(form_data, "title")
    |> option.unwrap("New Task")
  let description = form_parser.get_form_field_optional(form_data, "description")
  let priority = form_parser.get_form_field_int(form_data, "priority")
    |> option.unwrap(3)
  let due_date = form_parser.get_form_field_optional(form_data, "due_date")

  let data =
    TaskData(
      title: title,
      description: description,
      completed: False,
      priority: priority,
      due_date: due_date,
      position: 0,
      project_id: option.None,
    )

  case task_model.create(services.db, data) {
    Ok(task) -> {
      let tags = case tag_model.get_tags_for_task(services.db, task.id) {
        Ok(t) -> t
        Error(_) -> []
      }
      html_response(status.ok, task_view.card(task, tags))
    }
    Error(e) -> {
      io.println(string.inspect(e))
      errors.internal_error()
    }
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

  // Get existing task to preserve fields not in form
  case task_model.get(services.db, task_id) {
    Ok(existing_task) -> {
      let form_data = form_parser.parse_form_body(request.body)
      let title = form_parser.get_form_field(form_data, "title")
        |> option.unwrap(existing_task.title)
      let description = form_parser.get_form_field_optional(form_data, "description")
      let priority = form_parser.get_form_field_int(form_data, "priority")
        |> option.unwrap(existing_task.priority)
      let due_date = form_parser.get_form_field_optional(form_data, "due_date")

      let data =
        TaskData(
          title: title,
          description: description,
          completed: existing_task.completed,
          priority: priority,
          due_date: due_date,
          position: existing_task.position,
          project_id: existing_task.project_id,
        )

      case task_model.update(services.db, task_id, data) {
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
    Error(_) -> errors.not_found("Task not found")
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
    Ok(_) -> html_response(status.ok, "")
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

  let form_data = form_parser.parse_form_body(request.body)
  let new_position = form_parser.get_form_field_int(form_data, "position")
    |> option.unwrap(0)

  case task_model.update_position(services.db, task_id, new_position) {
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
