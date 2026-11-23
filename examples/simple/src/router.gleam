import controllers/cache_controller
import controllers/posts_controller
import controllers/request_data_controller
import controllers/responses_controller
import controllers/visits_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Delete, Get, Other, Post}
import dream/router.{type EmptyServices, type Router, route, router}

pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
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
  |> route(
    method: Get,
    path: "/users/:id",
    controller: request_data_controller.show_user,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/search",
    controller: request_data_controller.search,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/signups",
    controller: request_data_controller.create_signup,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/contact",
    controller: request_data_controller.create_contact,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/visits",
    controller: visits_controller.show,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/old-home",
    controller: responses_controller.moved,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/sessions",
    controller: responses_controller.sign_out,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/report.csv",
    controller: responses_controller.download_report,
    middleware: [],
  )
  |> route(
    method: Other("PURGE"),
    path: "/cache",
    controller: cache_controller.purge,
    middleware: [],
  )
}
