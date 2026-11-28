//// The routes of the app

import dream/context.{type EmptyContext}
import dream/http/request.{Get, Post}
import dream/router.{type Router, route, router}
import jobs_controller
import services.{type Services}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Post,
    path: "/jobs",
    controller: jobs_controller.create,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/jobs/:id",
    controller: jobs_controller.show,
    middleware: [],
  )
}
