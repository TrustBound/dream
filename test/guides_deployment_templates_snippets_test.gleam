//// Tests for the snippets in docs/guides/authentication.md,
//// deployment.md, multiple-formats.md, operations.md and templates.md.
////
//// Each test runs snippet code and checks one exact value.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/error.{BadRequest, NotFound}
import dream/http/header.{Header}
import dream/http/request.{type Request, Get, Post, Request}
import dream/http/response.{type Response}
import dream/router.{route, router}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/request as test_request
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/json
import gleam/option.{None}
import gleam/string
import gleam/time/timestamp
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import snippets/authentication_guide_app
import snippets/authentication_guide_context.{User, default_context}
import snippets/deployment_guide_app
import snippets/deployment_guide_logging
import snippets/deployment_guide_request_log
import snippets/multiple_formats_guide_task_view
import snippets/multiple_formats_guide_tasks
import snippets/operations_guide_posts.{Post as BlogPost}
import snippets/operations_guide_tasks
import snippets/templates_guide_components
import snippets/templates_guide_forms
import snippets/templates_guide_greeting
import snippets/templates_guide_layouts
import snippets/templates_guide_pages
import snippets/templates_guide_task.{Tag, Task}
import snippets/templates_guide_views

pub fn tests() -> TestSuite {
  describe("guide snippets", [
    authentication_tests(),
    deployment_tests(),
    multiple_formats_tests(),
    operations_tests(),
    templates_tests(),
  ])
}

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

const ada = User(id: "7", email: "ada@example.com", role: "admin")

fn authentication_services() -> authentication_guide_app.Services {
  authentication_guide_app.Services(tokens: [#("token-ada-123", ada)])
}

fn route_authentication_request(request: Request) -> Response {
  dream.route_request(
    authentication_guide_app.create_router(),
    request,
    default_context,
    authentication_services(),
  )
}

fn with_header(request: Request, name: String, value: String) -> Request {
  Request(..request, headers: [Header(name, value)])
}

fn authentication_tests() -> UnitNode {
  group("authentication guide", [
    it("the default context has no user", fn() {
      // Arrange
      let context = default_context

      // Act
      let user = context.user

      // Assert
      user
      |> should()
      |> be_equal(None)
      |> or_fail_with("default_context should have no user")
    }),
    it("GET / needs no token", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response = route_authentication_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Welcome")
      |> or_fail_with("GET / should return Welcome")
    }),
    it("GET /profile without a header returns 401", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/profile")

      // Act
      let response = route_authentication_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(401)
      |> or_fail_with("GET /profile without a header should return 401")
    }),
    it("GET /profile without a header says the header is missing", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/profile")

      // Act
      let response = route_authentication_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Missing Authorization header")
      |> or_fail_with("GET /profile should say the header is missing")
    }),
    it("GET /profile with an unknown token says the token is invalid", fn() {
      // Arrange
      let request =
        test_request.create_request(Get, "/profile")
        |> with_header("Authorization", "Bearer not-a-real-token")

      // Act
      let response = route_authentication_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Invalid token")
      |> or_fail_with("GET /profile should reject an unknown token")
    }),
    it("GET /profile with a token but no Bearer prefix is invalid", fn() {
      // Arrange
      let request =
        test_request.create_request(Get, "/profile")
        |> with_header("Authorization", "token-ada-123")

      // Act
      let response = route_authentication_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Invalid token")
      |> or_fail_with("GET /profile should need the Bearer prefix")
    }),
    it("GET /profile with a valid token returns the user as JSON", fn() {
      // Arrange
      let request =
        test_request.create_request(Get, "/profile")
        |> with_header("Authorization", "Bearer token-ada-123")

      // Act
      let response = route_authentication_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal(
        "{\"id\":\"7\",\"email\":\"ada@example.com\",\"role\":\"admin\"}",
      )
      |> or_fail_with("GET /profile should return the user")
    }),
    it("POST /posts with a valid token returns 201", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Post, "/posts", "Hello")
        |> with_header("Authorization", "Bearer token-ada-123")

      // Act
      let response = route_authentication_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("ada@example.com wrote: Hello")
      |> or_fail_with("POST /posts should use the user from the context")
    }),
    it("show_profile with no user in the context returns 401", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/profile")

      // Act
      let response =
        authentication_guide_app.show_profile(
          request,
          default_context,
          authentication_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Authentication required")
      |> or_fail_with("show_profile should need a user")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Deployment
// ---------------------------------------------------------------------------

fn healthy_services() -> deployment_guide_app.Services {
  deployment_guide_app.Services(check_database: fn() { Ok(Nil) })
}

fn unhealthy_services() -> deployment_guide_app.Services {
  deployment_guide_app.Services(check_database: fn() {
    Error("connection refused")
  })
}

fn route_health_request(services: deployment_guide_app.Services) -> Response {
  dream.route_request(
    deployment_guide_app.create_router(),
    test_request.create_request(Get, "/health"),
    EmptyContext,
    services,
  )
}

fn deployment_tests() -> UnitNode {
  group("deployment guide", [
    it("GET /health with a working database returns OK", fn() {
      // Arrange
      let services = healthy_services()

      // Act
      let response = route_health_request(services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("OK")
      |> or_fail_with("GET /health should return OK")
    }),
    it("GET /health with a failed database check returns 503", fn() {
      // Arrange
      let services = unhealthy_services()

      // Act
      let response = route_health_request(services)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(503)
      |> or_fail_with("GET /health should return 503")
    }),
    it("GET /health with a failed database check names the cause", fn() {
      // Arrange
      let services = unhealthy_services()

      // Act
      let response = route_health_request(services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Database unavailable")
      |> or_fail_with("GET /health should say the database is unavailable")
    }),
    it("create_server answers GET /health over TCP", fn() {
      // Arrange
      let port = free_port()

      // Act
      let body = request_health_over_tcp(port)

      // Assert
      body
      |> should()
      |> be_equal(Ok("OK"))
      |> or_fail_with("the server should answer GET /health with OK")
    }),
    it("format_info_line writes one JSON line", fn() {
      // Arrange
      let metadata = json.object([#("port", json.int(3000))])
      let time = timestamp.from_unix_seconds(1_767_225_600)

      // Act
      let line =
        deployment_guide_logging.format_info_line(
          "Server started",
          metadata,
          time,
        )

      // Assert
      line
      |> should()
      |> be_equal(
        "{\"level\":\"info\",\"message\":\"Server started\",\"metadata\":{\"port\":3000},\"timestamp\":\"2026-01-01T00:00:00Z\"}",
      )
      |> or_fail_with("format_info_line should write the JSON line")
    }),
    it("log_info prints and returns Nil", fn() {
      // Arrange
      let metadata = json.object([#("test", json.string("log_info"))])

      // Act
      let result = deployment_guide_logging.log_info("Snippet test", metadata)

      // Assert
      result
      |> should()
      |> be_equal(Nil)
      |> or_fail_with("log_info should return Nil")
    }),
    it("format_request_line writes one JSON line", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/tasks")
      let response = response.text_response(201, "Created")

      // Act
      let line =
        deployment_guide_request_log.format_request_line(request, response, 12)

      // Assert
      line
      |> should()
      |> be_equal(
        "{\"type\":\"request\",\"method\":\"POST\",\"path\":\"/tasks\",\"status\":201,\"duration_ms\":12}",
      )
      |> or_fail_with("format_request_line should write the JSON line")
    }),
    it("log_request prints and returns Nil", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/health")
      let response = response.text_response(200, "OK")

      // Act
      let result =
        deployment_guide_request_log.log_request(request, response, 3)

      // Assert
      result
      |> should()
      |> be_equal(Nil)
      |> or_fail_with("log_request should return Nil")
    }),
  ])
}

fn request_health_over_tcp(port: Int) -> Result(String, String) {
  let started =
    deployment_guide_app.create_server(healthy_services())
    |> server.listen_with_handle(port)
  case started {
    Ok(handle) -> {
      let reply =
        request_until_closed(
          port,
          <<
            "GET /health HTTP/1.0\r\nhost: localhost\r\n\r\n",
          >>,
          2000,
        )
      server.stop(handle)
      extract_http_body(reply)
    }
    Error(_start_error) -> Error("server did not start")
  }
}

fn extract_http_body(
  reply: Result(BitArray, Dynamic),
) -> Result(String, String) {
  case reply {
    Ok(bytes) -> split_http_body(bytes)
    Error(_reason) -> Error("request failed")
  }
}

fn split_http_body(bytes: BitArray) -> Result(String, String) {
  case bit_array.to_string(bytes) {
    Ok(text) -> body_after_headers(text)
    Error(Nil) -> Error("response is not UTF-8")
  }
}

fn body_after_headers(text: String) -> Result(String, String) {
  case string.split_once(text, "\r\n\r\n") {
    Ok(#(_headers, body)) -> Ok(body)
    Error(Nil) -> Error("response has no header end: " <> text)
  }
}

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "raw_http_ffi", "request_until_closed")
fn request_until_closed(
  port: Int,
  payload: BitArray,
  timeout_ms: Int,
) -> Result(BitArray, Dynamic)

// ---------------------------------------------------------------------------
// Multiple formats
// ---------------------------------------------------------------------------

const write_docs =
  Task(id: 1, title: "Write docs", completed: True, tags: [Tag(name: "docs")])

const fix_bug = Task(id: 2, title: "Fix bug", completed: False, tags: [])

const write_docs_card =
  "<article id=\"task-1\"><label><input type=\"checkbox\" id=\"checkbox-1\" name=\"completed\" checked hx-post=\"/tasks/1/toggle\"></label><input id=\"title-1\" name=\"title\" value=\"Write docs\" readonly><mark>docs</mark></article>"

const fix_bug_card =
  "<article id=\"task-2\"><label><input type=\"checkbox\" id=\"checkbox-2\" name=\"completed\"  hx-post=\"/tasks/2/toggle\"></label><input id=\"title-2\" name=\"title\" value=\"Fix bug\" readonly></article>"

fn route_task_request(request: Request) -> Response {
  let task_router =
    router()
    |> route(
      method: Get,
      path: "/tasks/:id",
      controller: multiple_formats_guide_tasks.show,
      middleware: [],
    )
  dream.route_request(
    task_router,
    request,
    EmptyContext,
    multiple_formats_guide_tasks.Services(tasks: [write_docs, fix_bug]),
  )
}

fn multiple_formats_tests() -> UnitNode {
  group("multiple formats guide", [
    it("GET /tasks/1 returns JSON by default", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/tasks/1")

      // Act
      let response = route_task_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"id\":1,\"title\":\"Write docs\"}")
      |> or_fail_with("GET /tasks/1 should return JSON")
    }),
    it("GET /tasks/1.json returns JSON", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/tasks/1.json")

      // Act
      let response = route_task_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"id\":1,\"title\":\"Write docs\"}")
      |> or_fail_with("GET /tasks/1.json should return JSON")
    }),
    it("GET /tasks/1.html returns the full page", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/tasks/1.html")

      // Act
      let response = route_task_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal(
        "<!DOCTYPE html><html><head><title>Write docs</title></head><body><nav><a href=\"/\">Tasks</a></nav><div class=\"container\">"
        <> write_docs_card
        <> "</div><footer>Built with Dream</footer><script src=\"/assets/htmx.min.js\"></script></body></html>",
      )
      |> or_fail_with("GET /tasks/1.html should return the page")
    }),
    it("GET /tasks/1 with HX-Request returns the card partial", fn() {
      // Arrange
      let request =
        test_request.create_request(Get, "/tasks/1")
        |> with_header("HX-Request", "true")

      // Act
      let response = route_task_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal(write_docs_card)
      |> or_fail_with("GET /tasks/1 with HX-Request should return the card")
    }),
    it("GET /tasks/9 returns 404", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/tasks/9")

      // Act
      let response = route_task_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(404)
      |> or_fail_with("GET /tasks/9 should return 404")
    }),
    it("GET /tasks/abc returns 400", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/tasks/abc")

      // Act
      let response = route_task_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(400)
      |> or_fail_with("GET /tasks/abc should return 400")
    }),
    it("detect_format with HX-Request false falls back to json", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/tasks/1", [#("id", "1")])
        |> with_header("HX-Request", "false")

      // Act
      let format = multiple_formats_guide_tasks.detect_format(request)

      // Assert
      format
      |> should()
      |> be_equal("json")
      |> or_fail_with("detect_format should default to json")
    }),
    it("task_view.to_json writes id and title", fn() {
      // Arrange
      let task = fix_bug

      // Act
      let body = multiple_formats_guide_task_view.to_json(task)

      // Assert
      body
      |> should()
      |> be_equal("{\"id\":2,\"title\":\"Fix bug\"}")
      |> or_fail_with("to_json should write id and title")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

fn task_services() -> operations_guide_tasks.Services {
  operations_guide_tasks.Services(tasks: [
    operations_guide_tasks.Task(id: 1, title: "Plan"),
    operations_guide_tasks.Task(id: 2, title: "Build"),
    operations_guide_tasks.Task(id: 3, title: "Ship"),
  ])
}

fn route_reorder_request(request: Request) -> Response {
  let task_router =
    router()
    |> route(
      method: Post,
      path: "/tasks/:id/reorder",
      controller: operations_guide_tasks.reorder,
      middleware: [],
    )
  dream.route_request(task_router, request, EmptyContext, task_services())
}

fn post_services(
  search_result: Result(Nil, error.Error),
) -> operations_guide_posts.Services {
  operations_guide_posts.Services(
    posts: [BlogPost(id: 4, title: "Release notes", published: False)],
    add_to_search_index: fn(_post) { search_result },
    notify_subscribers: fn(_post) { Ok(Nil) },
  )
}

fn operations_tests() -> UnitNode {
  group("operations guide", [
    it("reorder_task moves task 3 to position 1", fn() {
      // Arrange
      let services = task_services()

      // Act
      let result = operations_guide_tasks.reorder_task(services, 3, 1)

      // Assert
      result
      |> should()
      |> be_equal(
        Ok([
          operations_guide_tasks.Task(id: 3, title: "Ship"),
          operations_guide_tasks.Task(id: 1, title: "Plan"),
          operations_guide_tasks.Task(id: 2, title: "Build"),
        ]),
      )
      |> or_fail_with("reorder_task should move task 3 first")
    }),
    it("reorder_task with an unknown task returns NotFound", fn() {
      // Arrange
      let services = task_services()

      // Act
      let result = operations_guide_tasks.reorder_task(services, 9, 1)

      // Assert
      result
      |> should()
      |> be_equal(Error(NotFound("Task not found")))
      |> or_fail_with("reorder_task should not find task 9")
    }),
    it("reorder_task with a position past the end returns BadRequest", fn() {
      // Arrange
      let services = task_services()

      // Act
      let result = operations_guide_tasks.reorder_task(services, 1, 4)

      // Assert
      result
      |> should()
      |> be_equal(
        Error(BadRequest("Position must be between 1 and the task count")),
      )
      |> or_fail_with("reorder_task should refuse position 4")
    }),
    it("POST /tasks/1/reorder returns the new order", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Post,
          "/tasks/1/reorder",
          "position=3",
        )

      // Act
      let response = route_reorder_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("[2,3,1]")
      |> or_fail_with("POST /tasks/1/reorder should return the new order")
    }),
    it("POST /tasks/1/reorder with no position returns 400", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Post,
          "/tasks/1/reorder",
          "other=1",
        )

      // Act
      let response = route_reorder_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(400)
      |> or_fail_with("POST /tasks/1/reorder needs a position")
    }),
    it("publish_post returns the published post", fn() {
      // Arrange
      let services = post_services(Ok(Nil))

      // Act
      let result = operations_guide_posts.publish_post(services, 4)

      // Assert
      result
      |> should()
      |> be_equal(Ok(BlogPost(id: 4, title: "Release notes", published: True)))
      |> or_fail_with("publish_post should publish post 4")
    }),
    it("publish_post returns the error of a failed side effect", fn() {
      // Arrange
      let failure = error.InternalServerError("search index is down")
      let services = post_services(Error(failure))

      // Act
      let result = operations_guide_posts.publish_post(services, 4)

      // Assert
      result
      |> should()
      |> be_equal(Error(failure))
      |> or_fail_with("publish_post should return the search index error")
    }),
    it("publish_post with an unknown post returns NotFound", fn() {
      // Arrange
      let services = post_services(Ok(Nil))

      // Act
      let result = operations_guide_posts.publish_post(services, 5)

      // Assert
      result
      |> should()
      |> be_equal(Error(NotFound("Post not found")))
      |> or_fail_with("publish_post should not find post 5")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

const task_form_html =
  "<form hx-post=\"/tasks\"><input id=\"new-title\" name=\"title\" value=\"\" required><button id=\"submit-btn\" type=\"submit\" >Save Task</button></form>"

fn templates_tests() -> UnitNode {
  group("templates guide", [
    it("greet renders the hello template", fn() {
      // Arrange
      let name = "Dream"

      // Act
      let html = templates_guide_greeting.greet(name)

      // Assert
      html
      |> should()
      |> be_equal("Hello Dream!")
      |> or_fail_with("greet should render Hello Dream!")
    }),
    it("save_button renders the button element", fn() {
      // Arrange
      let expected =
        "<button id=\"submit-btn\" type=\"submit\" hx-post=\"/tasks\">Save Task</button>"

      // Act
      let html = templates_guide_components.save_button()

      // Assert
      html
      |> should()
      |> be_equal(expected)
      |> or_fail_with("save_button should render the button")
    }),
    it("task_card renders a completed task with its tags", fn() {
      // Arrange
      let task = write_docs

      // Act
      let html = templates_guide_components.task_card(task)

      // Assert
      html
      |> should()
      |> be_equal(write_docs_card)
      |> or_fail_with("task_card should render the completed task")
    }),
    it("task_card renders an open task with no tags", fn() {
      // Arrange
      let task = fix_bug

      // Act
      let html = templates_guide_components.task_card(task)

      // Assert
      html
      |> should()
      |> be_equal(fix_bug_card)
      |> or_fail_with("task_card should render the open task")
    }),
    it("task_form renders the form template", fn() {
      // Arrange
      let expected = task_form_html

      // Act
      let html = templates_guide_forms.task_form()

      // Assert
      html
      |> should()
      |> be_equal(expected)
      |> or_fail_with("task_form should render the form")
    }),
    it("pages index_page composes the form and the task list", fn() {
      // Arrange
      let tasks = [write_docs, fix_bug]

      // Act
      let html = templates_guide_pages.index_page(tasks)

      // Assert
      html
      |> should()
      |> be_equal(
        "<main><section><h1>Tasks</h1>"
        <> task_form_html
        <> "</section><section>"
        <> write_docs_card
        <> fix_bug_card
        <> "</section></main>",
      )
      |> or_fail_with("index_page should compose the page")
    }),
    it("build_page wraps content in the page layout", fn() {
      // Arrange
      let content = "<p>Hi</p>"

      // Act
      let html = templates_guide_layouts.build_page("Home", content)

      // Assert
      html
      |> should()
      |> be_equal(
        "<!DOCTYPE html><html><head><title>Home</title></head><body><nav><a href=\"/\">Tasks</a></nav><div class=\"container\"><p>Hi</p></div><footer>Built with Dream</footer><script src=\"/assets/htmx.min.js\"></script></body></html>",
      )
      |> or_fail_with("build_page should wrap the content")
    }),
    it("views index_page uses every layer", fn() {
      // Arrange
      let tasks = [fix_bug]

      // Act
      let html = templates_guide_views.index_page(tasks)

      // Assert
      html
      |> should()
      |> be_equal(
        "<!DOCTYPE html><html><head><title>Tasks</title></head><body><nav><a href=\"/\">Tasks</a></nav><div class=\"container\"><main><section><h1>Tasks</h1></section><section>"
        <> fix_bug_card
        <> "</section></main></div><footer>Built with Dream</footer><script src=\"/assets/htmx.min.js\"></script></body></html>",
      )
      |> or_fail_with("index_page should render the full page")
    }),
  ])
}
