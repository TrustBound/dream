import controllers/sse_controller
import dream/http/request.{Get}
import dream/http/response
import dream/http/status
import dream/router.{route, router}

pub fn create() {
  router()
  |> route(
    Get,
    "/health",
    fn(_, _, _) { response.text_response(status.ok, "ok") },
    [],
  )
  |> route(Get, "/events", sse_controller.handle_events, [])
  |> route(Get, "/events/named", sse_controller.handle_named_events, [])
}
