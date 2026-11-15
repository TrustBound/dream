//// The multi-format controller from the controllers-and-models guide.

import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, get_param, html_response, json_response, ok,
  require_int,
}
import gleam/option.{type Option, None, Some}
import gleam/result
import snippets/controllers_guide_response_helpers as response_helpers
import snippets/controllers_guide_services.{type Services}
import snippets/controllers_guide_task.{type Task}
import snippets/controllers_guide_task_model as task_model
import snippets/controllers_guide_task_view as task_view

pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    use task <- result.try(task_model.get(db, id))
    Ok(task)
  }

  case result {
    Ok(task) -> respond_with_format(task, requested_format(request))
    Error(err) -> response_helpers.handle_error(err)
  }
}

// The format comes from the path extension, such as /tasks/1.json
fn requested_format(request: Request) -> Option(String) {
  case get_param(request, "id") {
    Ok(param) -> param.format
    Error(_) -> None
  }
}

fn respond_with_format(task: Task, format: Option(String)) -> Response {
  case format {
    Some("json") -> json_response(ok, task_view.to_json(task))
    Some("html") -> html_response(ok, task_view.card(task))
    // Default
    _ -> json_response(ok, task_view.to_json(task))
  }
}
