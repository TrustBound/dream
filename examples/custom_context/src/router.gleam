import dream/core/http/transaction.{Get}
import dream/core/router.{type Router, route, router}
import context.{type AuthContext}
import controllers/posts_controller
import middleware/admin_middleware.{admin_middleware}
import middleware/auth_middleware.{auth_middleware}
import services.{type Services}

pub fn create_router() -> Router(AuthContext, Services) {
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
    middleware: [auth_middleware],
  )
  |> route(
    method: Get,
    path: "/admin",
    controller: posts_controller.index,
    middleware: [auth_middleware, admin_middleware],
  )
}
