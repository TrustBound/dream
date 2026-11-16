//// Tests for the snippets in docs/reference/architecture.md,
//// docs/reference/design-principles.md and docs/reference/dream-vs-mist.md.
////
//// Each snippet in test/snippets/architecture_*, design_principles_* and
//// dream_vs_mist_* is shown in one of those pages. These tests run it.

import dream/context.{AppContext, EmptyContext}
import dream/dream
import dream/http/error.{NotFound}
import dream/http/header.{Header}
import dream/http/request.{type Method, type Request, Get, Post, Request}
import dream/http/response.{type Response}
import dream/router.{EmptyServices}
import dream_http_client/client.{HttpResponse, ResponseError}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/erlang/process
import gleam/http
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/list
import gleam/option.{None, Some}
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import mist.{type Connection, type ResponseData}
import snippets/architecture_builders
import snippets/architecture_closures
import snippets/architecture_context
import snippets/architecture_router
import snippets/architecture_server
import snippets/architecture_task.{Task}
import snippets/architecture_task_model
import snippets/architecture_task_view
import snippets/architecture_tasks_controller
import snippets/design_principles_builder
import snippets/design_principles_closures
import snippets/design_principles_explicit
import snippets/design_principles_implicit
import snippets/design_principles_middleware
import snippets/dream_vs_mist_middleware_dream
import snippets/dream_vs_mist_middleware_mist
import snippets/dream_vs_mist_params_dream
import snippets/dream_vs_mist_params_mist
import snippets/dream_vs_mist_simple_dream
import snippets/dream_vs_mist_simple_mist

pub fn tests() -> UnitTest {
  describe("reference snippets", [
    architecture_router_tests(),
    architecture_server_tests(),
    architecture_context_tests(),
    architecture_tasks_tests(),
    architecture_closures_tests(),
    architecture_builders_tests(),
    design_principles_tests(),
    dream_vs_mist_tests(),
  ])
}

// ============================================================================
// architecture.md
// ============================================================================

fn architecture_router_tests() -> UnitTest {
  describe("architecture router", [
    it("GET / returns Home", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          architecture_router.create_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Home")
      |> or_fail_with("GET / should return Home")
    }),
    it("POST /users with a token returns 201", fn() {
      // Arrange
      let request =
        with_header(Post, "/users", "Authorization", "Bearer secret-token")

      // Act
      let response =
        dream.route_request(
          architecture_router.create_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(201)
      |> or_fail_with("POST /users with a token should return 201")
    }),
    it("POST /users without a token returns 401", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/users")

      // Act
      let response =
        dream.route_request(
          architecture_router.create_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(401)
      |> or_fail_with("POST /users without a token should return 401")
    }),
  ])
}

fn architecture_server_tests() -> UnitTest {
  describe("architecture server", [
    it("initialize_services holds one user", fn() {
      // Arrange
      let expected =
        architecture_server.Services(
          database: architecture_server.Database(users: [
            architecture_server.User(name: "Ada"),
          ]),
        )

      // Act
      let services = architecture_server.initialize_services()

      // Assert
      services
      |> should()
      |> equal(expected)
      |> or_fail_with("initialize_services should hold Ada")
    }),
    it("create_simple_server binds to localhost", fn() {
      // Arrange
      let server = architecture_server.create_simple_server()

      // Act
      let interface = dream.get_bind_interface(server)

      // Assert
      interface
      |> should()
      |> equal(Some("localhost"))
      |> or_fail_with("simple server should bind to localhost")
    }),
    it("create_app_context_server uses AppContext", fn() {
      // Arrange
      let server = architecture_server.create_app_context_server()

      // Act
      let context = dream.get_context(server)

      // Assert
      context
      |> should()
      |> equal(AppContext(request_id: ""))
      |> or_fail_with("server should use AppContext")
    }),
    it("create_custom_server uses MyContext", fn() {
      // Arrange
      let server = architecture_server.create_custom_server()

      // Act
      let context = dream.get_context(server)

      // Assert
      context
      |> should()
      |> equal(architecture_server.MyContext(request_id: "", user: None))
      |> or_fail_with("custom server should use MyContext")
    }),
    it("create_custom_server holds the services", fn() {
      // Arrange
      let server = architecture_server.create_custom_server()

      // Act
      let services = dream.get_services(server)

      // Assert
      services
      |> should()
      |> equal(architecture_server.initialize_services())
      |> or_fail_with("custom server should hold initialize_services()")
    }),
    it("create_router answers GET / with Home", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          architecture_server.create_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Home")
      |> or_fail_with("GET / should return Home")
    }),
  ])
}

fn architecture_context_tests() -> UnitTest {
  describe("architecture context", [
    it("GET /profile with a known token greets the user", fn() {
      // Arrange
      let request = with_header(Get, "/profile", "Authorization", "token-ada")

      // Act
      let response =
        dream.route_request(
          architecture_context.create_router(),
          request,
          architecture_context.AuthContext(request_id: "", user: None),
          architecture_context_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Hello, Ada")
      |> or_fail_with("GET /profile should greet Ada")
    }),
    it("GET /profile with an unknown token returns 401", fn() {
      // Arrange
      let request = with_header(Get, "/profile", "Authorization", "token-bob")

      // Act
      let response =
        dream.route_request(
          architecture_context.create_router(),
          request,
          architecture_context.AuthContext(request_id: "", user: None),
          architecture_context_services(),
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(401)
      |> or_fail_with("GET /profile with an unknown token should return 401")
    }),
  ])
}

fn architecture_context_services() -> architecture_context.Services {
  architecture_context.Services(users_by_token: [
    #("token-ada", architecture_context.User(name: "Ada")),
  ])
}

fn architecture_tasks_tests() -> UnitTest {
  describe("architecture tasks", [
    it("get_task finds a task by id", fn() {
      // Arrange
      let tasks = sample_tasks()

      // Act
      let result = architecture_task_model.get_task(tasks, 1)

      // Assert
      result
      |> should()
      |> equal(Ok(Task(id: 1, title: "Write docs", completed: False)))
      |> or_fail_with("get_task should find task 1")
    }),
    it("get_task returns NotFound for a missing id", fn() {
      // Arrange
      let tasks = sample_tasks()

      // Act
      let result = architecture_task_model.get_task(tasks, 99)

      // Assert
      result
      |> should()
      |> equal(Error(NotFound("Task not found")))
      |> or_fail_with("get_task should return NotFound")
    }),
    it("to_json formats a task", fn() {
      // Arrange
      let task = Task(id: 1, title: "Write docs", completed: False)

      // Act
      let json = architecture_task_view.to_json(task)

      // Assert
      json
      |> should()
      |> equal("{\"id\":1,\"title\":\"Write docs\",\"completed\":false}")
      |> or_fail_with("to_json should format the task")
    }),
    it("to_html escapes the title", fn() {
      // Arrange
      let task = Task(id: 2, title: "Fix <b> & \"quotes\"", completed: True)

      // Act
      let html = architecture_task_view.to_html(task)

      // Assert
      html
      |> should()
      |> equal("<li class=\"task\">Fix &lt;b&gt; &amp; &quot;quotes&quot;</li>")
      |> or_fail_with("to_html should escape the title")
    }),
    it("show_task returns JSON when the client accepts JSON", fn() {
      // Arrange
      let request =
        Request(
          ..with_header(Get, "/tasks/1", "Accept", "application/json"),
          params: [#("id", "1")],
        )

      // Act
      let response =
        architecture_tasks_controller.show_task(
          request,
          EmptyContext,
          architecture_tasks_controller.Services(tasks: sample_tasks()),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"id\":1,\"title\":\"Write docs\",\"completed\":false}")
      |> or_fail_with("show_task should return JSON")
    }),
    it("show_task returns HTML by default", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/tasks/1", [#("id", "1")])

      // Act
      let response =
        architecture_tasks_controller.show_task(
          request,
          EmptyContext,
          architecture_tasks_controller.Services(tasks: sample_tasks()),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("<li class=\"task\">Write docs</li>")
      |> or_fail_with("show_task should return HTML")
    }),
    it("show_task returns 404 for a missing task", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/tasks/99", [
          #("id", "99"),
        ])

      // Act
      let response =
        architecture_tasks_controller.show_task(
          request,
          EmptyContext,
          architecture_tasks_controller.Services(tasks: sample_tasks()),
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(404)
      |> or_fail_with("show_task should return 404")
    }),
    it("show_task returns 400 for an id that is not a number", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/tasks/abc", [
          #("id", "abc"),
        ])

      // Act
      let response =
        architecture_tasks_controller.show_task(
          request,
          EmptyContext,
          architecture_tasks_controller.Services(tasks: sample_tasks()),
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(400)
      |> or_fail_with("show_task should return 400")
    }),
  ])
}

fn sample_tasks() -> List(architecture_task.Task) {
  [
    Task(id: 1, title: "Write docs", completed: False),
    Task(id: 2, title: "Ship release", completed: True),
  ]
}

fn architecture_closures_tests() -> UnitTest {
  describe("architecture closures", [
    it("the closure handler counts the users", fn() {
      // Arrange
      let database =
        architecture_closures.Database(user_names: ["Ada", "Grace"])
      let handler = architecture_closures.create_handler(database)

      // Act
      let response =
        handler(
          test_request.create_request(Get, "/"),
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("2")
      |> or_fail_with("closure handler should count 2 users")
    }),
    it("the explicit handler counts the users", fn() {
      // Arrange
      let services =
        architecture_closures.Services(
          database: architecture_closures.Database(user_names: ["Ada", "Grace"]),
        )

      // Act
      let response =
        architecture_closures.handle_request(
          test_request.create_request(Get, "/"),
          EmptyContext,
          services,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("2")
      |> or_fail_with("explicit handler should count 2 users")
    }),
  ])
}

fn architecture_builders_tests() -> UnitTest {
  describe("architecture builders", [
    it("create_server binds to localhost", fn() {
      // Arrange
      let server = architecture_builders.create_server()

      // Act
      let interface = dream.get_bind_interface(server)

      // Assert
      interface
      |> should()
      |> equal(Some("localhost"))
      |> or_fail_with("server should bind to localhost")
    }),
    it("create_router answers GET /about", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/about")

      // Act
      let response =
        dream.route_request(
          architecture_builders.create_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("About")
      |> or_fail_with("GET /about should return About")
    }),
    it("create_users_request targets api.example.com", fn() {
      // Arrange
      let client_request = architecture_builders.create_users_request()

      // Act
      let host = client.get_host(client_request)

      // Assert
      host
      |> should()
      |> equal("api.example.com")
      |> or_fail_with("request should target api.example.com")
    }),
    it("create_users_request uses HTTPS", fn() {
      // Arrange
      let client_request = architecture_builders.create_users_request()

      // Act
      let scheme = client.get_scheme(client_request)

      // Assert
      scheme
      |> should()
      |> equal(http.Https)
      |> or_fail_with("request should use HTTPS")
    }),
    it("create_users_request has a 5 second timeout", fn() {
      // Arrange
      let client_request = architecture_builders.create_users_request()

      // Act
      let timeout = client.get_timeout(client_request)

      // Assert
      timeout
      |> should()
      |> equal(Some(5000))
      |> or_fail_with("request should time out after 5000 ms")
    }),
  ])
}

// ============================================================================
// design-principles.md
// ============================================================================

fn design_principles_tests() -> UnitTest {
  describe("design principles", [
    it("the implicit start helper binds to 0.0.0.0", fn() {
      // Arrange
      let server = design_principles_implicit.configure_server()

      // Act
      let interface = dream.get_bind_interface(server)

      // Assert
      interface
      |> should()
      |> equal(Some("0.0.0.0"))
      |> or_fail_with("hidden configuration should bind to 0.0.0.0")
    }),
    it("the explicit services hold the database URL", fn() {
      // Arrange
      let expected =
        design_principles_explicit.Services(
          database_url: "postgres://localhost/app",
        )

      // Act
      let services = design_principles_explicit.initialize_services()

      // Assert
      services
      |> should()
      |> equal(expected)
      |> or_fail_with("services should hold the database URL")
    }),
    it("the explicit router answers GET /", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")
      let services = design_principles_explicit.initialize_services()

      // Act
      let response =
        dream.route_request(
          design_principles_explicit.create_router(),
          request,
          EmptyContext,
          services,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Home")
      |> or_fail_with("GET / should return Home")
    }),
    it("the closure controller finds the user name", fn() {
      // Arrange
      let controller =
        design_principles_closures.create_controller(closure_database())
      let request =
        test_request.create_request_with_params(Get, "/users/1", [#("id", "1")])

      // Act
      let response = controller(request, EmptyContext, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Ada")
      |> or_fail_with("closure controller should return Ada")
    }),
    it("the explicit controller finds the user name", fn() {
      // Arrange
      let services =
        design_principles_closures.Services(database: closure_database())
      let request =
        test_request.create_request_with_params(Get, "/users/1", [#("id", "1")])

      // Act
      let response =
        design_principles_closures.controller(request, EmptyContext, services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Ada")
      |> or_fail_with("explicit controller should return Ada")
    }),
    it("the explicit controller returns 404 for an unknown id", fn() {
      // Arrange
      let services =
        design_principles_closures.Services(database: closure_database())
      let request =
        test_request.create_request_with_params(Get, "/users/9", [#("id", "9")])

      // Act
      let response =
        design_principles_closures.controller(request, EmptyContext, services)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(404)
      |> or_fail_with("unknown id should return 404")
    }),
    it("an admin can open /admin", fn() {
      // Arrange
      let request = with_header(Get, "/admin", "Authorization", "token-admin")

      // Act
      let response = route_admin_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(200)
      |> or_fail_with("an admin should get 200")
    }),
    it("a member cannot open /admin", fn() {
      // Arrange
      let request = with_header(Get, "/admin", "Authorization", "token-member")

      // Act
      let response = route_admin_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(403)
      |> or_fail_with("a member should get 403")
    }),
    it("a request with no token cannot open /admin", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/admin")

      // Act
      let response = route_admin_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(401)
      |> or_fail_with("no token should get 401")
    }),
    it("the builder sets the maximum body size", fn() {
      // Arrange
      let server = design_principles_builder.configure_server()

      // Act
      let max_body_size = dream.get_max_body_size(server)

      // Assert
      max_body_size
      |> should()
      |> equal(1_000_000)
      |> or_fail_with("max body size should be 1_000_000")
    }),
  ])
}

fn closure_database() -> design_principles_closures.Database {
  design_principles_closures.Database(user_names_by_id: [
    #("1", "Ada"),
    #("2", "Grace"),
  ])
}

fn route_admin_request(request: Request) -> Response {
  let services =
    design_principles_middleware.Services(users_by_token: [
      #(
        "token-admin",
        design_principles_middleware.User(
          name: "Ada",
          role: design_principles_middleware.Admin,
        ),
      ),
      #(
        "token-member",
        design_principles_middleware.User(
          name: "Grace",
          role: design_principles_middleware.Member,
        ),
      ),
    ])
  dream.route_request(
    design_principles_middleware.create_router(),
    request,
    design_principles_middleware.Context(request_id: "", user: None),
    services,
  )
}

// ============================================================================
// dream-vs-mist.md
// ============================================================================

fn dream_vs_mist_tests() -> UnitTest {
  describe("dream vs mist", [
    it("raw mist answers GET / with Hello, World!", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result =
        request_raw_mist(
          dream_vs_mist_simple_mist.handle_request,
          port,
          http.Get,
          "/",
          [],
        )

      // Assert
      result
      |> should()
      |> equal(Ok(#(200, "Hello, World!")))
      |> or_fail_with("raw mist GET / should return Hello, World!")
    }),
    it("raw mist answers an unknown path with 404", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result =
        request_raw_mist(
          dream_vs_mist_simple_mist.handle_request,
          port,
          http.Get,
          "/missing",
          [],
        )

      // Assert
      result
      |> should()
      |> equal(Ok(#(404, "Not Found")))
      |> or_fail_with("raw mist unknown path should return 404")
    }),
    it("dream answers GET / with Hello, World!", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          dream_vs_mist_simple_dream.create_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Hello, World!")
      |> or_fail_with("dream GET / should return Hello, World!")
    }),
    it("raw mist parses the user id from the path", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result =
        request_raw_mist(
          dream_vs_mist_params_mist.handle_request,
          port,
          http.Get,
          "/users/7",
          [],
        )

      // Assert
      result
      |> should()
      |> equal(Ok(#(200, "User 7")))
      |> or_fail_with("raw mist GET /users/7 should return User 7")
    }),
    it("raw mist answers a bad user id with 404", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result =
        request_raw_mist(
          dream_vs_mist_params_mist.handle_request,
          port,
          http.Get,
          "/users/abc",
          [],
        )

      // Assert
      result
      |> should()
      |> equal(Ok(#(404, "Not Found")))
      |> or_fail_with("raw mist GET /users/abc should return 404")
    }),
    it("dream show_user returns the user as JSON", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/1")

      // Act
      let response =
        dream.route_request(
          dream_vs_mist_params_dream.create_router(),
          request,
          EmptyContext,
          dream_vs_mist_params_dream.initialize_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"id\":1,\"name\":\"Ada\"}")
      |> or_fail_with("dream GET /users/1 should return Ada as JSON")
    }),
    it("dream show_user returns 404 for an unknown user", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/2")

      // Act
      let response =
        dream.route_request(
          dream_vs_mist_params_dream.create_router(),
          request,
          EmptyContext,
          dream_vs_mist_params_dream.initialize_services(),
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(404)
      |> or_fail_with("dream GET /users/2 should return 404")
    }),
    it("raw mist greets the user who sends a valid token", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result =
        request_raw_mist(
          dream_vs_mist_middleware_mist.handle_request,
          port,
          http.Get,
          "/",
          [#("authorization", "Bearer secret-token")],
        )

      // Assert
      result
      |> should()
      |> equal(Ok(#(200, "Welcome, Ada")))
      |> or_fail_with("raw mist GET / with a token should greet Ada")
    }),
    it("raw mist refuses the home page without a token", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result =
        request_raw_mist(
          dream_vs_mist_middleware_mist.handle_request,
          port,
          http.Get,
          "/",
          [],
        )

      // Assert
      result
      |> should()
      |> equal(Ok(#(401, "Unauthorized")))
      |> or_fail_with("raw mist GET / without a token should return 401")
    }),
    it("raw mist creates a post for a valid token", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result =
        request_raw_mist(
          dream_vs_mist_middleware_mist.handle_request,
          port,
          http.Post,
          "/posts",
          [#("authorization", "Bearer secret-token")],
        )

      // Assert
      result
      |> should()
      |> equal(Ok(#(201, "Post created by Ada")))
      |> or_fail_with("raw mist POST /posts should return 201")
    }),
    it("dream serves the home page without a token", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response = route_dream_middleware_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Welcome")
      |> or_fail_with("dream GET / should return Welcome")
    }),
    it("dream creates a post for a valid token", fn() {
      // Arrange
      let request =
        with_header(Post, "/posts", "Authorization", "Bearer secret-token")

      // Act
      let response = route_dream_middleware_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Post created by Ada")
      |> or_fail_with("dream POST /posts should create a post for Ada")
    }),
    it("dream refuses POST /posts without a token", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/posts")

      // Act
      let response = route_dream_middleware_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(401)
      |> or_fail_with("dream POST /posts without a token should return 401")
    }),
  ])
}

fn route_dream_middleware_request(request: Request) -> Response {
  dream.route_request(
    dream_vs_mist_middleware_dream.create_router(),
    request,
    dream_vs_mist_middleware_dream.Context(request_id: "", user: None),
    dream_vs_mist_middleware_dream.initialize_services(),
  )
}

// ============================================================================
// Helpers
// ============================================================================

fn with_header(
  method: Method,
  path: String,
  name: String,
  value: String,
) -> Request {
  Request(..test_request.create_request(method, path), headers: [
    Header(name: name, value: value),
  ])
}

/// Starts a raw Mist server with the handler, sends one request to it, stops
/// the server, and returns the status and body.
fn request_raw_mist(
  handler: fn(http_request.Request(Connection)) ->
    http_response.Response(ResponseData),
  port: Int,
  method: http.Method,
  path: String,
  headers: List(#(String, String)),
) -> Result(#(Int, String), String) {
  let started =
    mist.new(handler)
    |> mist.bind("127.0.0.1")
    |> mist.port(port)
    |> mist.start()
  case started {
    Ok(server) -> {
      let result = send_request(port, method, path, headers)
      process.send_exit(server.pid)
      result
    }
    Error(_start_error) -> Error("mist did not start")
  }
}

fn send_request(
  port: Int,
  method: http.Method,
  path: String,
  headers: List(#(String, String)),
) -> Result(#(Int, String), String) {
  let base_request =
    client.new()
    |> client.method(method)
    |> client.scheme(http.Http)
    |> client.host("127.0.0.1")
    |> client.port(port)
    |> client.path(path)
  let client_request =
    list.fold(headers, base_request, fn(request, header) {
      client.add_header(request, header.0, header.1)
    })
  case client.send(client_request) {
    Ok(HttpResponse(status:, body:, ..)) -> Ok(#(status, body))
    Error(ResponseError(response: HttpResponse(status:, body:, ..))) ->
      Ok(#(status, body))
    Error(_transport_error) -> Error("request failed")
  }
}

/// Asks the operating system for a free TCP port.
@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
