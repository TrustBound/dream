import dream/core/http/transaction.{Delete, Get, Post, Put}
import dream/core/router.{type Router, route, router}
import examples/database/context.{type DatabaseContext}
import examples/database/controllers/posts_controller
import examples/database/controllers/users_controller
import examples/database/services.{type Services}

pub fn create_router() -> Router(DatabaseContext, Services) {
  router
  |> route(
    method: Get,
    path: "/users",
    controller: users_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id",
    controller: users_controller.show,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/users",
    controller: users_controller.create,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/users/:id",
    controller: users_controller.update,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/users/:id",
    controller: users_controller.delete,
    middleware: [],
  )
  // Posts routes
  |> route(
    method: Get,
    path: "/users/:user_id/posts",
    controller: posts_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/posts/:id",
    controller: posts_controller.show,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/users/:user_id/posts",
    controller: posts_controller.create,
    middleware: [],
  )
}
