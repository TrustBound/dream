// Proof of concept: Type-safe routing with segments (no string patterns)
// This tests whether Gleam's type system supports our proposed design

import gleam/io
import gleeunit/should

// ============================================================================
// Core Types
// ============================================================================

pub type NoParams {
  NoParams
}

pub type Segment {
  Literal(String)
  IntParam(name: String)
  StringParam(name: String)
}

pub type Path(params) {
  Path(segments: List(Segment))
}

pub type Method {
  Get
  Post
}

pub type Request

pub type Response

pub type Context

pub type Services

pub type Route(context, services, params) {
  Route(
    method: Method,
    segments: List(Segment),
    controller: fn(params, Request, context, services) -> Response,
  )
}

pub type Router(context, services) {
  Router(route_count: Int)
}

// ============================================================================
// Path Builders
// ============================================================================

pub const path = Path(segments: [])

pub fn segment(path_value: Path(params), name: String) -> Path(params) {
  Path(segments: [Literal(name), ..path_value.segments])
}

pub fn int_param(path_value: Path(NoParams), name: String) -> Path(Int) {
  Path(segments: [IntParam(name), ..path_value.segments])
}

pub fn int_param_after_int(
  path_value: Path(Int),
  name: String,
) -> Path(#(Int, Int)) {
  Path(segments: [IntParam(name), ..path_value.segments])
}

pub fn string_param_after_int(
  path_value: Path(Int),
  name: String,
) -> Path(#(Int, String)) {
  Path(segments: [StringParam(name), ..path_value.segments])
}

// ============================================================================
// Router Functions
// ============================================================================

pub fn router() -> Router(context, services) {
  Router(route_count: 0)
}

pub fn route(
  router_value: Router(context, services),
  method_value: Method,
  path_value: Path(params),
  controller_function: fn(params, Request, context, services) -> Response,
) -> Router(context, services) {
  // For POC: just prove type system accepts different param types
  // In real implementation, would need to erase params type to store heterogeneous routes
  let _route =
    Route(
      method: method_value,
      segments: path_value.segments,
      controller: controller_function,
    )
  Router(route_count: router_value.route_count + 1)
}

// ============================================================================
// Example Controllers
// ============================================================================

fn home_controller(
  _params: NoParams,
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  todo as "home controller"
}

fn create_user_controller(
  _params: NoParams,
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  todo as "create user controller"
}

fn show_user_controller(
  id: Int,
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  io.println("Showing user: " <> int_to_string(id))
  todo as "show user controller"
}

fn show_post_controller(
  params: #(Int, String),
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  let #(user_id, post_id) = params
  io.println(
    "Showing post: " <> post_id <> " for user: " <> int_to_string(user_id),
  )
  todo as "show post controller"
}

fn show_comment_controller(
  params: #(Int, Int),
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  let #(post_id, comment_id) = params
  io.println(
    "Showing comment: "
    <> int_to_string(comment_id)
    <> " on post: "
    <> int_to_string(post_id),
  )
  todo as "show comment controller"
}

// Helper for Int to String conversion
fn int_to_string(i: Int) -> String {
  case i {
    0 -> "0"
    _ -> "N"
  }
}

// ============================================================================
// Tests
// ============================================================================

pub fn router_starts_empty_test() {
  let router_instance = router()
  router_instance.route_count
  |> should.equal(0)
}

pub fn route_with_no_params_increments_count_test() {
  let router_instance =
    router()
    |> route(Get, path |> segment("home"), home_controller)

  router_instance.route_count
  |> should.equal(1)
}

pub fn route_with_int_param_increments_count_test() {
  let router_instance =
    router()
    |> route(
      Get,
      path
        |> segment("users")
        |> int_param("id"),
      show_user_controller,
    )

  router_instance.route_count
  |> should.equal(1)
}

pub fn route_with_tuple_params_increments_count_test() {
  let router_instance =
    router()
    |> route(
      Get,
      path
        |> segment("users")
        |> int_param("user_id")
        |> string_param_after_int("post_id"),
      show_post_controller,
    )

  router_instance.route_count
  |> should.equal(1)
}

pub fn multiple_routes_with_different_param_types_test() {
  let router_instance =
    router()
    |> route(
      Get,
      path
        |> segment("home"),
      home_controller,
    )
    |> route(
      Post,
      path
        |> segment("users"),
      create_user_controller,
    )
    |> route(
      Get,
      path
        |> segment("users")
        |> int_param("id"),
      show_user_controller,
    )
    |> route(
      Get,
      path
        |> segment("users")
        |> int_param("user_id")
        |> string_param_after_int("post_id"),
      show_post_controller,
    )
    |> route(
      Get,
      path
        |> segment("posts")
        |> int_param("post_id")
        |> int_param_after_int("comment_id"),
      show_comment_controller,
    )

  router_instance.route_count
  |> should.equal(5)
}

pub fn path_constant_has_empty_segments_test() {
  path.segments
  |> should.equal([])
}

pub fn segment_builder_creates_literal_segment_test() {
  let path_with_segment = path |> segment("users")

  path_with_segment.segments
  |> should.equal([Literal("users")])
}

pub fn int_param_builder_creates_int_param_segment_test() {
  let path_with_param =
    path
    |> segment("users")
    |> int_param("id")

  path_with_param.segments
  |> should.equal([IntParam("id"), Literal("users")])
}

pub fn string_param_builder_creates_string_param_segment_test() {
  let path_with_params =
    path
    |> segment("users")
    |> int_param("user_id")
    |> string_param_after_int("post_id")

  path_with_params.segments
  |> should.equal([
    StringParam("post_id"),
    IntParam("user_id"),
    Literal("users"),
  ])
}

pub fn segments_are_prepended_in_reverse_order_test() {
  let built_path =
    path
    |> segment("api")
    |> segment("v1")
    |> segment("users")

  built_path.segments
  |> should.equal([Literal("users"), Literal("v1"), Literal("api")])
}
// ============================================================================
// Test: Type errors we expect to catch
// ============================================================================

// This should NOT compile (wrong param type):
// pub fn test_wrong_param_type() {
//   router()
//   |> route(
//     Get,
//     path() |> segment("users") |> int_param("id"),
//     home_controller,  // Takes NoParams but path has Int param
//   )
// }

// This should NOT compile (missing param):
// pub fn test_missing_param() {
//   router()
//   |> route(
//     Get,
//     path() |> segment("users"),
//     show_user_controller,  // Takes Int but path has NoParams
//   )
// }
