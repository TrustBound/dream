//// Router configuration

import context.{type Context}
import controllers/events_controller
import controllers/posts_controller
import controllers/users_controller
import dream/core/http/transaction.{Get, Post}
import dream/core/router.{type Router, route, router}
import middleware/logging_middleware.{logging_middleware}
import services.{type Services}

pub fn create_router() -> Router(Context, Services) {
  router
  // Users routes
  |> route(
    method: Get,
    path: "/users",
    controller: users_controller.index,
    middleware: [logging_middleware],
  )
  |> route(
    method: Get,
    path: "/users/:id",
    controller: users_controller.show,
    middleware: [logging_middleware],
  )
  // Posts routes
  |> route(
    method: Get,
    path: "/posts",
    controller: posts_controller.index,
    middleware: [logging_middleware],
  )
  |> route(
    method: Get,
    path: "/posts/:id",
    controller: posts_controller.show,
    middleware: [logging_middleware],
  )
  |> route(
    method: Post,
    path: "/posts/:id/publish",
    controller: posts_controller.publish,
    middleware: [logging_middleware],
  )
  |> route(
    method: Get,
    path: "/posts/export",
    controller: posts_controller.export,
    middleware: [],
  )
  // Events routes
  |> route(
    method: Get,
    path: "/events",
    controller: events_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/events/stream",
    controller: events_controller.stream,
    middleware: [],
  )
}

