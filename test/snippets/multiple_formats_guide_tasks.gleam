//// Multiple formats guide: one controller, many formats
////
//// Shown in excerpts in docs/guides/templates.md.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, get_header, get_param, html_response,
  json_response, ok, require_int, text_response,
}
import dream/http/error.{type Error, NotFound}
import dream/http/request.{PathParam}
import gleam/list
import gleam/option.{Some}
import gleam/result
import snippets/multiple_formats_guide_task_view as task_view
import snippets/templates_guide_task.{type Task}

pub type Services {
  Services(tasks: List(Task))
}

pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    find_task(services.tasks, id)
  }

  case result {
    Ok(task) -> respond_with_format(task, detect_format(request))
    Error(error) -> respond_with_error(error)
  }
}

fn respond_with_format(task: Task, format: String) -> Response {
  case format {
    // HTMX request asking for just the card partial
    "htmx" -> html_response(ok, task_view.card(task))

    // Full HTML page
    "html" -> html_response(ok, task_view.page(task))

    // Default to JSON
    _ -> json_response(ok, task_view.to_json(task))
  }
}

// /tasks/1.json and /tasks/1.html: Dream puts the extension in
// PathParam.format
pub fn detect_format(request: Request) -> String {
  case get_param(request, "id") {
    Ok(PathParam(format: Some(format), ..)) -> format
    _ -> detect_format_from_headers(request)
  }
}

fn detect_format_from_headers(request: Request) -> String {
  case get_header(request.headers, "HX-Request") {
    Some("true") -> "htmx"
    // Default
    _ -> "json"
  }
}

fn find_task(tasks: List(Task), id: Int) -> Result(Task, Error) {
  list.find(tasks, fn(task) { task.id == id })
  |> result.replace_error(NotFound("Task not found"))
}

fn respond_with_error(failure: Error) -> Response {
  text_response(error.to_status_code(failure), error.message(failure))
}
