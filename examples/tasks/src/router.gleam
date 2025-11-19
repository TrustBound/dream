//// Router configuration

import context.{type TasksContext}
import controllers/projects_controller
import controllers/static_controller
import controllers/tags_controller
import controllers/tasks_controller
import dream/http/request.{Delete, Get, Post, Put}
import dream/router.{type Router, route, router}
import middleware/logging_middleware
import services.{type Services}

pub fn create_router() -> Router(TasksContext, Services) {
  router
  // Static files
  |> route(
    method: Get,
    path: "/public/**filepath",
    controller: static_controller.serve_public,
    middleware: [],
  )
  // Main page
  |> route(
    method: Get,
    path: "/",
    controller: tasks_controller.index,
    middleware: [logging_middleware.logging_middleware],
  )
  // Tasks routes
  |> route(
    method: Get,
    path: "/tasks/:task_id",
    controller: tasks_controller.show,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Get,
    path: "/tasks/:task_id/edit",
    controller: tasks_controller.edit,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Post,
    path: "/tasks",
    controller: tasks_controller.create,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Put,
    path: "/tasks/:task_id",
    controller: tasks_controller.update,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Delete,
    path: "/tasks/:task_id",
    controller: tasks_controller.delete,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Post,
    path: "/tasks/:task_id/toggle",
    controller: tasks_controller.toggle,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Post,
    path: "/tasks/:task_id/reorder",
    controller: tasks_controller.reorder,
    middleware: [logging_middleware.logging_middleware],
  )
  // Projects routes
  |> route(
    method: Get,
    path: "/projects",
    controller: projects_controller.index,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Get,
    path: "/projects/:project_id",
    controller: projects_controller.show,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Post,
    path: "/projects",
    controller: projects_controller.create,
    middleware: [logging_middleware.logging_middleware],
  )
  |> route(
    method: Delete,
    path: "/projects/:project_id",
    controller: projects_controller.delete,
    middleware: [logging_middleware.logging_middleware],
  )
  // Tags routes
  |> route(
    method: Get,
    path: "/tags",
    controller: tags_controller.index,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/tags",
    controller: tags_controller.create,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/tasks/:task_id/tags",
    controller: tags_controller.add_to_task,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/tasks/:task_id/tags/:tag_id",
    controller: tags_controller.remove_from_task,
    middleware: [],
  )
}

