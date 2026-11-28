//// Tests for `dream/router.scope`.
////
//// The tests send requests with `dream.route_request`, which gives the same
//// answers as the server, or look routes up with `find_route`.

import dream/context.{type AppContext, AppContext}
import dream/dream
import dream/http/header.{Header}
import dream/http/request.{type Method, type Request, Delete, Get, Post}
import dream/http/response.{
  type Response, type ResponseBody, Text, text_response,
}
import dream/router.{
  type EmptyServices, type Router, EmptyServices, allowed_methods, find_route,
  route, router, scope, stream_route,
}
import dream_test/matchers.{be_equal, be_some, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/handler.{test_handler}
import fixtures/request as test_request
import gleam/int
import gleam/option.{type Option}
import matchers/extract_route_params.{extract_route_params}
import matchers/extract_streaming_flag.{extract_streaming_flag}

// ============================================================================
// Context types of the scopes
// ============================================================================

type Member {
  Member(request_id: String, name: String)
}

type Admin {
  Admin(member: Member, level: Int)
}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("router scope", [
    prefix_tests(),
    parameter_tests(),
    context_tests(),
    order_tests(),
    nesting_tests(),
    streaming_tests(),
    no_match_tests(),
    replacement_tests(),
  ])
}

fn prefix_tests() -> UnitNode {
  group("prefix", [
    it("keeps the route path for an empty prefix", fn() {
      // Arrange
      let app_router = same_type_scope("", "/users")

      // Act
      let result = send(app_router, Get, "/users")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("test")))
      |> or_fail_with(
        "GET /users should match /users in a scope with no prefix",
      )
    }),
    it("gives the prefix alone for the route path /", fn() {
      // Arrange
      let app_router = same_type_scope("/admin", "/")

      // Act
      let result = send(app_router, Get, "/admin")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("test")))
      |> or_fail_with("GET /admin should match / under the prefix /admin")
    }),
    it("puts the prefix before the route path", fn() {
      // Arrange
      let app_router = same_type_scope("/admin", "/users/:id")

      // Act
      let result = send(app_router, Get, "/admin/users/7")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("test")))
      |> or_fail_with("GET /admin/users/7 should match /admin + /users/:id")
    }),
    it("ignores a slash at the end of the prefix", fn() {
      // Arrange
      let app_router = same_type_scope("/admin/", "/users")

      // Act
      let result = send(app_router, Get, "/admin/users")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("test")))
      |> or_fail_with("GET /admin/users should match /admin/ + /users")
    }),
    it("accepts a prefix and a route path with no slash at the start", fn() {
      // Arrange
      let app_router = same_type_scope("admin", "users")

      // Act
      let result = send(app_router, Get, "/admin/users")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("test")))
      |> or_fail_with("GET /admin/users should match admin + users")
    }),
    it("does not match the route path without the prefix", fn() {
      // Arrange
      let app_router = same_type_scope("/admin", "/users")

      // Act
      let result = send(app_router, Get, "/users")

      // Assert
      result
      |> should()
      |> be_equal(#(404, Text("Route not found")))
      |> or_fail_with(
        "GET /users should get 404 when the route is under /admin",
      )
    }),
  ])
}

fn parameter_tests() -> UnitNode {
  group("parameters", [
    it("gives the parameters of the prefix and then of the route", fn() {
      // Arrange
      let app_router =
        router()
        |> scope(
          path: "/orgs/:org_id",
          with: pass_through,
          routes: router() |> route(Get, "/users/:id", test_handler, []),
        )
      let request = test_request.create_request(Get, "/orgs/5/users/9")

      // Act
      let result = find_route(app_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> be_equal([#("org_id", "5"), #("id", "9")])
      |> or_fail_with("params should be org_id 5 and id 9")
    }),
    it("gives the route's own parameter names at a shared node", fn() {
      // Arrange
      let inner =
        router()
        |> route(Get, "/users/:id", test_handler, [])
        |> route(Get, "/users/:user_id/posts", test_handler, [])
      let app_router =
        router() |> scope(path: "/api", with: pass_through, routes: inner)
      let request = test_request.create_request(Get, "/api/users/3/posts")

      // Act
      let result = find_route(app_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> be_equal([#("user_id", "3")])
      |> or_fail_with("params should use the name user_id of the posts route")
    }),
  ])
}

fn context_tests() -> UnitNode {
  group("context", [
    it("gives the controller the context that enter makes", fn() {
      // Arrange
      let app_router =
        router()
        |> scope(path: "/members", with: as_member, routes: member_routes())

      // Act
      let result = send(app_router, Get, "/members/me")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("member ada of request-1")))
      |> or_fail_with("the controller should get the Member that enter made")
    }),
    it("answers with enter when enter does not call next", fn() {
      // Arrange
      let app_router =
        router()
        |> scope(path: "/members", with: refuse, routes: member_routes())

      // Act
      let result = send(app_router, Get, "/members/me")

      // Assert
      result
      |> should()
      |> be_equal(#(401, Text("refused")))
      |> or_fail_with("enter should answer 401 without the controller")
    }),
    it("lets ordinary middleware change the response as enter", fn() {
      // Arrange
      let app_router =
        router()
        |> scope(path: "", with: add_header, routes: plain_routes("/page"))
      let request = test_request.create_request(Get, "/page")

      // Act
      let response =
        dream.route_request(app_router, request, app_context(), EmptyServices)

      // Assert
      header.get_header(response.headers, "X-Scope")
      |> should()
      |> be_equal(option.Some("yes"))
      |> or_fail_with("the answer should have the header that enter adds")
    }),
    it("keeps the routes that the router had before the scope", fn() {
      // Arrange
      let app_router =
        router()
        |> route(Get, "/", test_handler, [])
        |> scope(path: "/members", with: refuse, routes: member_routes())

      // Act
      let result = send(app_router, Get, "/")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("test")))
      |> or_fail_with("GET / should still reach its controller")
    }),
  ])
}

fn order_tests() -> UnitNode {
  group("order", [
    it(
      "runs enter, then the route's middleware in order, then the controller",
      fn() {
        // Arrange
        let inner =
          router()
          |> route(Get, "/page", test_handler, [label("first"), label("second")])
        let app_router =
          router()
          |> scope(path: "", with: label("enter"), routes: inner)

        // Act
        let result = send(app_router, Get, "/page")

        // Assert
        result
        |> should()
        |> be_equal(#(200, Text("enter(first(second(test)))")))
        |> or_fail_with("enter should wrap the route's middleware")
      },
    ),
  ])
}

fn nesting_tests() -> UnitNode {
  group("nested scopes", [
    it("runs both context changes for a scope in a scope", fn() {
      // Arrange
      let app_router = nested_router()

      // Act
      let result = send(app_router, Get, "/orgs/5/admin/teams/8/report")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("admin ada level 2")))
      |> or_fail_with("the controller should get the Admin of both scopes")
    }),
    it("joins the prefixes and the parameters of nested scopes", fn() {
      // Arrange
      let app_router = nested_router()
      let request =
        test_request.create_request(Get, "/orgs/5/admin/teams/8/report")

      // Act
      let result = find_route(app_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> be_equal([#("org_id", "5"), #("team_id", "8")])
      |> or_fail_with("params should be org_id 5 and team_id 8")
    }),
    it("runs the enter of the outer scope first", fn() {
      // Arrange
      let inner =
        router()
        |> scope(
          path: "/b",
          with: label("inner"),
          routes: router() |> route(Get, "/c", test_handler, []),
        )
      let app_router =
        router() |> scope(path: "/a", with: label("outer"), routes: inner)

      // Act
      let result = send(app_router, Get, "/a/b/c")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("outer(inner(test))")))
      |> or_fail_with("the outer enter should wrap the inner enter")
    }),
  ])
}

fn streaming_tests() -> UnitNode {
  group("streaming", [
    it("keeps a stream_route a streaming route", fn() {
      // Arrange
      let app_router =
        router()
        |> scope(
          path: "/files",
          with: pass_through,
          routes: router() |> stream_route(Post, "/upload", test_handler, []),
        )
      let request = test_request.create_request(Post, "/files/upload")

      // Act
      let result = find_route(app_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_equal(True)
      |> or_fail_with("POST /files/upload should be a streaming route")
    }),
    it("keeps a route a route that does not stream", fn() {
      // Arrange
      let app_router = same_type_scope("/files", "/list")
      let request = test_request.create_request(Get, "/files/list")

      // Act
      let result = find_route(app_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_equal(False)
      |> or_fail_with("GET /files/list should not be a streaming route")
    }),
  ])
}

fn no_match_tests() -> UnitNode {
  group("no match", [
    it("answers 405 with Allow for a scoped path with another method", fn() {
      // Arrange
      let app_router = same_type_scope("/admin", "/users")

      // Act
      let result = allow_of(app_router, Delete, "/admin/users")

      // Assert
      result
      |> should()
      |> be_equal(#(405, option.Some("GET")))
      |> or_fail_with("DELETE /admin/users should get 405 with Allow: GET")
    }),
    it("answers 404 for a path under the prefix that no route matches", fn() {
      // Arrange
      let app_router = same_type_scope("/admin", "/users")

      // Act
      let result = allow_of(app_router, Get, "/admin/missing")

      // Assert
      result
      |> should()
      |> be_equal(#(404, option.None))
      |> or_fail_with("GET /admin/missing should get 404 with no Allow")
    }),
    it("lists the methods of scoped and plain routes of one path", fn() {
      // Arrange
      let app_router =
        router()
        |> route(Post, "/admin/users", test_handler, [])
        |> scope(
          path: "/admin",
          with: pass_through,
          routes: plain_routes("/users"),
        )
      let request = test_request.create_request(Delete, "/admin/users")

      // Act
      let result = allowed_methods(app_router, request)

      // Assert
      result
      |> should()
      |> be_equal([Get, Post])
      |> or_fail_with("/admin/users should allow GET and POST")
    }),
  ])
}

fn replacement_tests() -> UnitNode {
  group("the same method and path", [
    it("replaces an earlier route with the route of a later scope", fn() {
      // Arrange
      let app_router =
        router()
        |> route(Get, "/admin/users", answer_with("plain"), [])
        |> scope(
          path: "/admin",
          with: pass_through,
          routes: router() |> route(Get, "/users", answer_with("scoped"), []),
        )

      // Act
      let result = send(app_router, Get, "/admin/users")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("scoped")))
      |> or_fail_with("the route of the later scope should answer")
    }),
    it("replaces the route of a scope with a later route", fn() {
      // Arrange
      let app_router =
        router()
        |> scope(
          path: "/admin",
          with: pass_through,
          routes: router() |> route(Get, "/users", answer_with("scoped"), []),
        )
        |> route(Get, "/admin/users", answer_with("plain"), [])

      // Act
      let result = send(app_router, Get, "/admin/users")

      // Assert
      result
      |> should()
      |> be_equal(#(200, Text("plain")))
      |> or_fail_with("the later route should answer")
    }),
  ])
}

// ============================================================================
// Routers
// ============================================================================

/// A router with one GET route of `path` under `prefix`, and no context change
fn same_type_scope(
  prefix: String,
  path: String,
) -> Router(AppContext, EmptyServices) {
  router()
  |> scope(path: prefix, with: pass_through, routes: plain_routes(path))
}

fn plain_routes(path: String) -> Router(AppContext, EmptyServices) {
  router() |> route(Get, path, test_handler, [])
}

fn member_routes() -> Router(Member, EmptyServices) {
  router() |> route(Get, "/me", show_member, [])
}

fn nested_router() -> Router(AppContext, EmptyServices) {
  let admin_routes =
    router() |> route(Get, "/teams/:team_id/report", show_admin, [])
  let member_area =
    router() |> scope(path: "/admin", with: as_admin, routes: admin_routes)
  router()
  |> scope(path: "/orgs/:org_id", with: as_member, routes: member_area)
}

// ============================================================================
// Enter functions, middleware and controllers
// ============================================================================

fn pass_through(
  request: Request,
  context: AppContext,
  services: EmptyServices,
  next: fn(Request, AppContext, EmptyServices) -> Response,
) -> Response {
  next(request, context, services)
}

fn as_member(
  request: Request,
  context: AppContext,
  services: EmptyServices,
  next: fn(Request, Member, EmptyServices) -> Response,
) -> Response {
  next(request, Member(request_id: context.request_id, name: "ada"), services)
}

fn as_admin(
  request: Request,
  member: Member,
  services: EmptyServices,
  next: fn(Request, Admin, EmptyServices) -> Response,
) -> Response {
  next(request, Admin(member: member, level: 2), services)
}

fn refuse(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
  _next: fn(Request, Member, EmptyServices) -> Response,
) -> Response {
  text_response(401, "refused")
}

fn add_header(
  request: Request,
  context: AppContext,
  services: EmptyServices,
  next: fn(Request, AppContext, EmptyServices) -> Response,
) -> Response {
  let response = next(request, context, services)
  response.Response(..response, headers: [
    Header("X-Scope", "yes"),
    ..response.headers
  ])
}

/// Middleware that wraps the text of the answer in `name(...)`
fn label(
  name: String,
) -> fn(
  Request,
  AppContext,
  EmptyServices,
  fn(Request, AppContext, EmptyServices) -> Response,
) -> Response {
  fn(request, context, services, next) {
    let response: Response = next(request, context, services)
    case response.body {
      Text(body) -> text_response(response.status, name <> "(" <> body <> ")")
      _ -> response
    }
  }
}

fn show_member(
  _request: Request,
  member: Member,
  _services: EmptyServices,
) -> Response {
  text_response(200, "member " <> member.name <> " of " <> member.request_id)
}

fn show_admin(
  _request: Request,
  admin: Admin,
  _services: EmptyServices,
) -> Response {
  text_response(
    200,
    "admin " <> admin.member.name <> " level " <> int.to_string(admin.level),
  )
}

fn answer_with(
  text: String,
) -> fn(Request, AppContext, EmptyServices) -> Response {
  fn(_request, _context, _services) { text_response(200, text) }
}

// ============================================================================
// Helpers
// ============================================================================

fn app_context() -> AppContext {
  AppContext(request_id: "request-1")
}

/// The status and the body of the answer
fn send(
  app_router: Router(AppContext, EmptyServices),
  method: Method,
  path: String,
) -> #(Int, ResponseBody) {
  let request = test_request.create_request(method, path)
  let response =
    dream.route_request(app_router, request, app_context(), EmptyServices)
  #(response.status, response.body)
}

/// The status and the Allow header of the answer
fn allow_of(
  app_router: Router(AppContext, EmptyServices),
  method: Method,
  path: String,
) -> #(Int, Option(String)) {
  let request = test_request.create_request(method, path)
  let response =
    dream.route_request(app_router, request, app_context(), EmptyServices)
  #(response.status, header.get_header(response.headers, "allow"))
}
