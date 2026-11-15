//// Architecture reference: a controller
////
//// Reads the path parameter, calls the model, and calls the view for the
//// format that the client asks for.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, html_response, json_response, ok, require_int,
  text_response,
}
import dream/http/error
import dream/http/header.{get_header}
import gleam/option.{Some}
import gleam/result
import snippets/architecture_task.{type Task}
import snippets/architecture_task_model as task_model
import snippets/architecture_task_view as task_view

pub type Services {
  Services(tasks: List(Task))
}

pub fn show_task(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let task_result = {
    use task_id <- result.try(require_int(request, "id"))
    task_model.get_task(services.tasks, task_id)
  }

  case task_result {
    Ok(task) -> respond_with_task(request, task)
    Error(http_error) ->
      text_response(error.to_status_code(http_error), error.message(http_error))
  }
}

fn respond_with_task(request: Request, task: Task) -> Response {
  case get_header(request.headers, "Accept") {
    Some("application/json") -> json_response(ok, task_view.to_json(task))
    _ -> html_response(ok, task_view.to_html(task))
  }
}
