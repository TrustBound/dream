import controllers/posts_controller
import dream/context.{type AppContext}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}

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
