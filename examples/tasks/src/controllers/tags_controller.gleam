//// Tags controller - HTTP handlers
////
//// Thin HTTP layer that validates inputs, calls operations, and renders views.

import context.{type TasksContext}
import dream/http
import dream/http/error
import gleam/result
import operations/tag_operations
import services.{type Services}
import templates/components/tag_components
import utilities/response_helpers
import views/tag_view
import views/task_view

/// List all tags
pub fn index(
  _request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  case tag_operations.list_all(services.db) {
    Ok(tags) -> http.json_response(http.ok, tag_view.list_to_json(tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Get tag selector for a task (returns HTML)
pub fn get_task_tags(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    use all_tags <- result.try(tag_operations.list_all(services.db))
    Ok(#(all_tags, task_id))
  }

  case result {
    Ok(#(all_tags, task_id)) ->
      http.html_response(
        http.ok,
        tag_components.tag_selector_html(all_tags, task_id),
      )
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Create a new tag
pub fn create(
  _request: http.Request,
  _context: TasksContext,
  _services: Services,
) -> http.Response {
  // Placeholder - would need JSON validation
  response_helpers.handle_error(error.InternalServerError("Not implemented"))
}

/// Create tag and add to task (returns updated tag selector HTML)
pub fn create_and_add_to_task(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    use form <- result.try(http.require_form(request))
    use tag_name <- result.try(http.require_field(form, "tag_name"))

    use _ <- result.try(tag_operations.create_and_attach(
      services.db,
      task_id,
      tag_name,
    ))

    use all_tags <- result.try(tag_operations.list_all(services.db))
    Ok(#(all_tags, task_id))
  }

  case result {
    Ok(#(all_tags, task_id)) ->
      http.html_response(
        http.ok,
        tag_components.tag_selector_html(all_tags, task_id),
      )
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Add tag to task
pub fn add_to_task(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    use form <- result.try(http.require_form(request))
    use tag_id <- result.try(http.require_field_int(form, "tag_id"))

    use _ <- result.try(tag_operations.add_tag_to_task(
      services.db,
      task_id,
      tag_id,
    ))

    tag_operations.get_task_with_tags(services.db, task_id)
  }

  case result {
    Ok(#(task, tags)) ->
      http.html_response(http.ok, task_view.editor(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Remove tag from task
pub fn remove_from_task(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    use tag_id <- result.try(http.require_int(request, "tag_id"))

    use _ <- result.try(tag_operations.remove_tag_from_task(
      services.db,
      task_id,
      tag_id,
    ))

    tag_operations.get_task_with_tags(services.db, task_id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}
