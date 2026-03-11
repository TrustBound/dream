import controllers/sse_controller
import dream/http/request.{Get}
import dream/http/response
import dream/http/status
import dream/router.{route, router}
import middleware

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
  |> route(Get, "/events/cors", sse_controller.handle_events, [
    middleware.cors,
  ])
  |> route(Get, "/events/rejected", sse_controller.handle_events, [
    middleware.reject_unauthorized,
  ])
  |> route(Get, "/events/stacked", sse_controller.handle_events, [
    middleware.cors,
    middleware.security_headers,
  ])
}
