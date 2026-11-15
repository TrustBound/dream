import dream/context
import dream/dream
import dream/http/request.{Get}
import dream/http/response.{type Response}
import dream/router.{EmptyServices, route, router}
import fixtures/handler.{id_param_handler, test_handler}
import fixtures/request as test_request

pub fn show_home() -> Response {
  let request = test_request.create_request(Get, "/")

  router()
  |> route(method: Get, path: "/", controller: test_handler, middleware: [])
  |> dream.route_request(request, context.new_context("test"), EmptyServices)
}

pub fn show_user() -> Response {
  let request = test_request.create_request(Get, "/users/42")

  router()
  |> route(
    method: Get,
    path: "/users/:id",
    controller: id_param_handler,
    middleware: [],
  )
  |> dream.route_request(request, context.new_context("test"), EmptyServices)
}
