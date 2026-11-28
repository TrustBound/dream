//// The routes of the notes app

import dream/context.{type EmptyContext}
import dream/http/request.{Delete, Get, Post, Put}
import dream/router.{type Router, route, router}
import notes/notes_controller
import notes/search_controller
import notes/services.{type Services}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Post,
    path: "/notes",
    controller: notes_controller.create,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/notes/:id",
    controller: notes_controller.update,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/notes/:id",
    controller: notes_controller.delete,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/search",
    controller: search_controller.search,
    middleware: [],
  )
}
