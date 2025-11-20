//// Tasks controller - HTTP handlers with HTMX support
////
//// Thin HTTP layer that validates inputs, calls operations, and renders views.

import context.{type TasksContext}
import dream/http as http
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import operations/task_operations
import services.{type Services}
import types/task.{TaskData}
import utilities/response_helpers
import views/task_view

/// Show single task
pub fn show(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    task_operations.get_task_with_tags(services.db, task_id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Show edit form for a task (returns inline editor)
pub fn edit(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    task_operations.get_task_with_tags(services.db, task_id)
  }

  case result {
    Ok(#(task, tags)) ->
      http.html_response(http.ok, task_view.editor(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// List all tasks
pub fn index(
  _request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  io.println("Index controller: Fetching tasks...")

  case task_operations.list_tasks_with_tags(services.db) {
    Ok(tasks_with_tags) -> {
      io.println(
        "Index controller: Got "
        <> int.to_string(list.length(tasks_with_tags))
        <> " tasks",
      )

      // Separate tasks and tags_by_task for the view
      let tasks = list.map(tasks_with_tags, response_helpers.extract_task)
      let tags_by_task =
        list.map(tasks_with_tags, response_helpers.extract_tags_by_task)

      http.html_response(http.ok, task_view.index_page(tasks, tags_by_task))
    }
    Error(err) -> {
      io.println("Index controller: Error fetching tasks")
      response_helpers.handle_error(err)
    }
  }
}

/// Create a new task
pub fn create(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use form <- result.try(http.require_form(request))

    let title = http.field_optional(form, "title") |> option.unwrap("New Task")
    let description = http.field_optional(form, "description")
    let priority =
      http.require_field_int(form, "priority")
      |> result.unwrap(3)
    let due_date = http.field_optional(form, "due_date")
    let project_id = http.field_optional(form, "project_id")
      |> option.then(fn(id_str) {
        case int.parse(id_str) {
          Ok(id) -> option.Some(id)
          Error(_) -> option.None
        }
      })

  let data =
    TaskData(
      title: title,
      description: description,
      completed: False,
      priority: priority,
      due_date: due_date,
      position: 0,
      project_id: project_id,
    )

    use task <- result.try(task_operations.create_task(services.db, data))
    task_operations.get_task_with_tags(services.db, task.id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(e) -> {
      io.println(string.inspect(e))
      response_helpers.handle_error(e)
    }
  }
}

/// Update a task
pub fn update(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))

    use existing_task <- result.try(task_operations.get_task(
      services.db,
      task_id,
    ))

    use form <- result.try(http.require_form(request))

    let title =
      http.field_optional(form, "title") |> option.unwrap(existing_task.title)
    let description = http.field_optional(form, "description")
    let priority =
      http.require_field_int(form, "priority")
      |> result.unwrap(existing_task.priority)
    let due_date = http.field_optional(form, "due_date")

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

    use task <- result.try(task_operations.update_task(
      services.db,
      task_id,
      data,
    ))

    task_operations.get_task_with_tags(services.db, task.id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Delete a task
pub fn delete(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    task_operations.delete_task(services.db, task_id)
  }

  case result {
    Ok(_) -> http.empty_response(http.no_content)
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Toggle task completion
pub fn toggle(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))

    use task <- result.try(task_operations.toggle_completion(
      services.db,
      task_id,
    ))

    task_operations.get_task_with_tags(services.db, task.id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Reorder task (update position)
pub fn reorder(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    use form <- result.try(http.require_form(request))

    let new_position =
      http.require_field_int(form, "position")
      |> result.unwrap(0)

    use task <- result.try(task_operations.update_position(
      services.db,
      task_id,
      new_position,
    ))

    task_operations.get_task_with_tags(services.db, task.id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Render inline editor for new task
pub fn new_inline(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let project_id = case http.get_query_param(request, "project_id") {
    option.Some(id_str) -> {
      case int.parse(id_str) {
        Ok(id) -> option.Some(id)
        Error(_) -> option.None
      }
    }
    option.None -> option.None
  }

  let data =
    TaskData(
    title: "",
    description: option.None,
    completed: False,
    priority: 3,
    due_date: option.None,
    position: 0,
    project_id: project_id,
  )

  case task_operations.create_task(services.db, data) {
    Ok(task) -> http.html_response(http.ok, task_view.editor(task, []))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Update a single field (auto-save)
pub fn update_field(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    use form <- result.try(http.require_form(request))

    let field = http.field_optional(form, "field") |> option.unwrap("")
    let value = http.field_optional(form, field) |> option.unwrap("")

    task_operations.update_field(services.db, task_id, field, value)
  }

  case result {
    Ok(_) -> http.empty_response(http.ok)
    Error(err) -> response_helpers.handle_error(err)
  }
}
