import context.{type DatabaseContext}
import controllers/posts_controller
import controllers/users_controller
import dream/http/request.{Delete, Get, Post, Put}
import dream/router.{type Router, route, router}
import services.{type Services}

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
