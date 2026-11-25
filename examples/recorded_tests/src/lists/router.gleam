import dream/context.{type EmptyContext}
import dream/http/request.{Get, Post}
import dream/router.{type Router, route, router}
import lists/lists_controller
import lists/services.{type Services}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/lists",
    controller: lists_controller.index,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/lists",
    controller: lists_controller.create,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/lists/:id",
    controller: lists_controller.show,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/lists/:id/share",
    controller: lists_controller.share,
    middleware: [],
  )
}
