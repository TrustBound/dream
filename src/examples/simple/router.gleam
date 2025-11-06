import dream/core/context.{type AppContext}
import dream/core/http/transaction.{Get}
import dream/core/router.{type EmptyServices, type Router, route, router}
import examples/simple/controllers/posts_controller

pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
  |> route(
    method: Get,
    path: "/",
    controller: posts_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id/posts/:post_id",
    controller: posts_controller.show,
    middleware: [],
  )
}
