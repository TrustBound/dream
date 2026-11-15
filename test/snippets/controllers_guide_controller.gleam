import dream/context.{type AppContext}
import dream/http.{type Request, type Response, html_response, ok, require_int}
import gleam/result
import snippets/controllers_guide_response_helpers as response_helpers
import snippets/controllers_guide_services.{type Services}
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
    Ok(task) -> html_response(ok, task_view.show(task))
    Error(err) -> response_helpers.handle_error(err)
  }
}

pub type Controller(context, services) =
  fn(Request, context, services) -> Response
