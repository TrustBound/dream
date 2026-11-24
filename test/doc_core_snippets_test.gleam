//// Tests for the snippets shown in the doc comments of `dream/dream`,
//// `dream/context`, `dream/router`, `dream/router/parser`,
//// `dream/router/trie` and `dream/controllers/static`. Each snippet is in
//// test/snippets/doc_core_*.gleam.

import dream/context.{AppContext, EmptyContext}
import dream/controllers/static
import dream/dream
import dream/http/cookie.{simple_cookie}
import dream/http/header.{type Header, Header}
import dream/http/request.{type Method, type Request, Delete, Get, Post, Request}
import dream/http/response.{type Response, text_response}
import dream/router.{find_route, router}
import dream/router/trie.{ExtensionPattern, Literal, Match, MultiWildcard, Param}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/request as test_request
import gleam/list
import gleam/option.{None, Some}
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import snippets/doc_core_context_custom
import snippets/doc_core_context_middleware
import snippets/doc_core_context_new_context
import snippets/doc_core_dream
import snippets/doc_core_dream_builder
import snippets/doc_core_dream_execute_route
import snippets/doc_core_dream_get_shutdown_timeout
import snippets/doc_core_dream_get_tls
import snippets/doc_core_dream_set_shutdown_timeout
import snippets/doc_core_dream_set_tls
import snippets/doc_core_dream_type
import snippets/doc_core_parser
import snippets/doc_core_router
import snippets/doc_core_router_basic
import snippets/doc_core_router_build_controller_chain
import snippets/doc_core_router_wrong
import snippets/doc_core_static
import snippets/doc_core_static_default_config
import snippets/doc_core_static_serve
import snippets/doc_core_static_with_custom_404
import snippets/doc_core_static_with_directory_listing
import snippets/doc_core_static_without_index
import snippets/doc_core_trie

pub fn tests() -> TestSuite {
  describe("doc comment snippets for the core modules", [
    dream_module_tests(),
    context_module_tests(),
    router_module_tests(),
    static_module_tests(),
    parser_module_tests(),
    trie_module_tests(),
  ])
}

fn send(router_value, method: Method, path: String) -> Response {
  dream.route_request(
    router_value,
    test_request.create_request(method, path),
    Nil,
    Nil,
  )
}

fn middleware_names(headers: List(Header)) -> List(String) {
  list.filter_map(headers, middleware_name)
}

fn middleware_name(header: Header) -> Result(String, Nil) {
  case header {
    Header("X-Middleware", name) -> Ok(name)
    _ -> Error(Nil)
  }
}

fn request_with_authorization(token: String) -> Request {
  Request(..test_request.create_request(Get, "/profile"), headers: [
    Header("Authorization", token),
  ])
}

fn show_user_name(
  _request: Request,
  context: doc_core_context_middleware.MyContext,
  _services: doc_core_context_middleware.Services,
) -> Response {
  case context.user {
    Some(user) -> text_response(200, user.name)
    None -> text_response(200, "No user")
  }
}

fn middleware_services() -> doc_core_context_middleware.Services {
  doc_core_context_middleware.Services(
    database: doc_core_context_middleware.Database(
      valid_token: "token-123",
      token_user: doc_core_context_middleware.User(name: "Ada"),
    ),
  )
}

fn middleware_context() -> doc_core_context_middleware.MyContext {
  doc_core_context_middleware.MyContext(request_id: "request-1", user: None)
}

fn dream_module_tests() -> UnitNode {
  group("dream/dream", [
    it("Dream type example server has the custom context", fn() {
      // Arrange
      let app = doc_core_dream_type.create_server()

      // Act
      let context = dream.get_context(app)

      // Assert
      context
      |> should()
      |> be_equal(doc_core_dream_type.MyContext(request_id: "", user: None))
      |> or_fail_with(
        "context should be MyContext(request_id: \"\", user: None)",
      )
    }),
    it("create builder example sets the max body size", fn() {
      // Arrange
      let app = doc_core_dream_builder.create_server()

      // Act
      let size = dream.get_max_body_size(app)

      // Assert
      size
      |> should()
      |> be_equal(10_000_000)
      |> or_fail_with("max body size should be 10_000_000")
    }),
    it("create builder example sets the bind interface", fn() {
      // Arrange
      let app = doc_core_dream_builder.create_server()

      // Act
      let interface = dream.get_bind_interface(app)

      // Assert
      interface
      |> should()
      |> be_equal(Some("0.0.0.0"))
      |> or_fail_with("bind interface should be Some(\"0.0.0.0\")")
    }),
    it("get_server example returns the Mist builder of the app", fn() {
      // Arrange
      let app = server.new()

      // Act
      let mist_server = doc_core_dream.raw_server(app)

      // Assert
      mist_server
      |> should()
      |> be_equal(dream.get_server(app, risks_understood: True))
      |> or_fail_with("raw_server should return the app's Mist builder")
    }),
    it("get_router example returns the router", fn() {
      // Arrange
      let expected = doc_core_dream.my_router()

      // Act
      let configured_router = doc_core_dream.configured_router()

      // Assert
      configured_router
      |> should()
      |> be_equal(expected)
      |> or_fail_with("configured_router should return my_router()")
    }),
    it("get_context example returns the context", fn() {
      // Arrange
      let expected = doc_core_dream.MyContext(user: None)

      // Act
      let context = doc_core_dream.configured_context()

      // Assert
      context
      |> should()
      |> be_equal(expected)
      |> or_fail_with("configured_context should be MyContext(user: None)")
    }),
    it("get_services example returns the services", fn() {
      // Arrange
      let expected = doc_core_dream.my_services()

      // Act
      let services = doc_core_dream.configured_services()

      // Assert
      services
      |> should()
      |> be_equal(expected)
      |> or_fail_with("configured_services should return my_services()")
    }),
    it("get_max_body_size example returns 5_000_000", fn() {
      // Arrange
      let expected = 5_000_000

      // Act
      let size = doc_core_dream.configured_max_body_size()

      // Assert
      size
      |> should()
      |> be_equal(expected)
      |> or_fail_with("configured_max_body_size should be 5_000_000")
    }),
    it("get_bind_interface example names the interface", fn() {
      // Arrange
      let expected = "Will bind to 0.0.0.0"

      // Act
      let status = doc_core_dream.bind_status()

      // Assert
      status
      |> should()
      |> be_equal(expected)
      |> or_fail_with("bind_status should be \"Will bind to 0.0.0.0\"")
    }),
    it("route_request example routes GET / to the home controller", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        doc_core_dream.handle(
          doc_core_dream.my_router(),
          request,
          Nil,
          doc_core_dream.my_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Home")
      |> or_fail_with("handle should return the body Home")
    }),
    it("parse_cookies_from_headers example returns two cookies", fn() {
      // Arrange
      let expected = [
        simple_cookie("session", "abc123"),
        simple_cookie("theme", "dark"),
      ]

      // Act
      let cookies = doc_core_dream.request_cookies()

      // Assert
      cookies
      |> should()
      |> be_equal(expected)
      |> or_fail_with("request_cookies should be session and theme")
    }),
    it("parse_cookie_string example returns three cookies", fn() {
      // Arrange
      let expected = [
        simple_cookie("session", "abc123"),
        simple_cookie("theme", "dark"),
        simple_cookie("lang", "en"),
      ]

      // Act
      let cookies = doc_core_dream.cookie_string_cookies()

      // Assert
      cookies
      |> should()
      |> be_equal(expected)
      |> or_fail_with("cookie_string_cookies should be session, theme, lang")
    }),
    it("set_tls example reads back the certificate and key files", fn() {
      // Act
      let tls = doc_core_dream_set_tls.tls_files()

      // Assert
      tls
      |> should()
      |> be_equal(Some(dream.Tls(certfile: "cert.pem", keyfile: "key.pem")))
      |> or_fail_with("the TLS files should be cert.pem and key.pem")
    }),
    it("get_tls example returns None for plain HTTP", fn() {
      // Act
      let tls = doc_core_dream_get_tls.plain_http_tls()

      // Assert
      tls
      |> should()
      |> be_equal(None)
      |> or_fail_with("a new server should have no TLS files")
    }),
    it("set_shutdown_timeout example reads back 10 seconds", fn() {
      // Act
      let timeout = doc_core_dream_set_shutdown_timeout.ten_seconds()

      // Assert
      timeout
      |> should()
      |> be_equal(10_000)
      |> or_fail_with("the shutdown timeout should be 10_000")
    }),
    it("get_shutdown_timeout example returns the 30 second default", fn() {
      // Act
      let timeout =
        doc_core_dream_get_shutdown_timeout.default_shutdown_timeout()

      // Assert
      timeout
      |> should()
      |> be_equal(30_000)
      |> or_fail_with("a new server should wait at most 30_000 ms")
    }),
    it("execute_route example runs the matched controller", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/7")

      // Act
      let response = doc_core_dream_execute_route.handle(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("User 7")
      |> or_fail_with("the body should be User 7")
    }),
    it("execute_route example returns 404 when no route matches", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/teams")

      // Act
      let response = doc_core_dream_execute_route.handle(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(404)
      |> or_fail_with("a path with no route should give 404")
    }),
  ])
}

// The context examples end in listen(3000), which blocks. The tests compile
// them and run the builder steps that they use.
fn context_module_tests() -> UnitNode {
  group("dream/context", [
    it("default context is EmptyContext", fn() {
      // Arrange
      let app = server.new() |> server.router(router())

      // Act
      let context = dream.get_context(app)

      // Assert
      context
      |> should()
      |> be_equal(EmptyContext)
      |> or_fail_with("the default context should be EmptyContext")
    }),
    it("explicit EmptyContext is kept", fn() {
      // Arrange
      let app = server.new() |> server.context(EmptyContext)

      // Act
      let context = dream.get_context(app)

      // Assert
      context
      |> should()
      |> be_equal(EmptyContext)
      |> or_fail_with("the context should be EmptyContext")
    }),
    it("AppContext is kept", fn() {
      // Arrange
      let app = server.new() |> server.context(AppContext(request_id: ""))

      // Act
      let context = dream.get_context(app)

      // Assert
      context
      |> should()
      |> be_equal(AppContext(request_id: ""))
      |> or_fail_with("the context should be AppContext(request_id: \"\")")
    }),
    it("custom context starts with an empty session", fn() {
      // Arrange
      let app =
        server.new()
        |> server.context(
          doc_core_context_custom.MyContext(
            request_id: "",
            user: None,
            session: doc_core_context_custom.empty_session(),
            permissions: [],
          ),
        )

      // Act
      let context = dream.get_context(app)

      // Assert
      context.session
      |> should()
      |> be_equal(doc_core_context_custom.Session(values: []))
      |> or_fail_with("the session should be Session(values: [])")
    }),
    it("auth middleware puts the user in the context", fn() {
      // Arrange
      let request = request_with_authorization("token-123")

      // Act
      let response =
        doc_core_context_middleware.auth_middleware(
          request,
          middleware_context(),
          middleware_services(),
          show_user_name,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Ada")
      |> or_fail_with("the controller should see the user Ada")
    }),
    it("auth middleware without a token returns 401", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/profile")

      // Act
      let response =
        doc_core_context_middleware.auth_middleware(
          request,
          middleware_context(),
          middleware_services(),
          show_user_name,
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(401)
      |> or_fail_with("a request with no token should get 401")
    }),
    it("new_context example sets the request ID", fn() {
      // Act
      let context = doc_core_context_new_context.request_context()

      // Assert
      context
      |> should()
      |> be_equal(AppContext(request_id: "req-123"))
      |> or_fail_with("the request ID should be req-123")
    }),
  ])
}

fn router_module_tests() -> UnitNode {
  group("dream/router", [
    it("basic routing sends GET /users/123 to show_user", fn() {
      // Arrange
      let app_router = doc_core_router_basic.create_router()

      // Act
      let response = send(app_router, Get, "/users/123")

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("User 123")
      |> or_fail_with("GET /users/123 should return User 123")
    }),
    it("parameter remapping reads id on /users/123", fn() {
      // Arrange
      let app_router = doc_core_router.parameter_router()

      // Act
      let response = send(app_router, Get, "/users/123")

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("User 123")
      |> or_fail_with("GET /users/123 should return User 123")
    }),
    it("parameter remapping reads user_id on /users/123/posts", fn() {
      // Arrange
      let app_router = doc_core_router.parameter_router()

      // Act
      let response = send(app_router, Get, "/users/123/posts")

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Posts by user 123")
      |> or_fail_with("GET /users/123/posts should return Posts by user 123")
    }),
    it("middleware run auth outside logging", fn() {
      // Arrange
      let app_router = doc_core_router.admin_router()

      // Act
      let response = send(app_router, Get, "/admin/users")

      // Assert
      middleware_names(response.headers)
      |> should()
      |> be_equal(["auth", "logging"])
      |> or_fail_with("auth should run last on the way out")
    }),
    it("wrong parameter name returns 400", fn() {
      // Arrange
      let app_router = doc_core_router_wrong.user_router()

      // Act
      let response = send(app_router, Get, "/users/42")

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(400)
      |> or_fail_with("the typo in the parameter name should give 400")
    }),
    it("router example sends GET / to home", fn() {
      // Arrange
      let app_router = doc_core_router.app_router()

      // Act
      let response = send(app_router, Get, "/")

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Home")
      |> or_fail_with("GET / should return Home")
    }),
    it("route example wildcard captures the asset path", fn() {
      // Arrange
      let app_router = doc_core_router.add_routes(router())

      // Act
      let response = send(app_router, Get, "/assets/css/app.css")

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Asset css/app.css")
      |> or_fail_with("GET /assets/css/app.css should return Asset css/app.css")
    }),
    it("stream_route example makes a streaming route", fn() {
      // Arrange
      let app_router = doc_core_router.add_upload_routes(router())
      let request = test_request.create_request(Post, "/upload")

      // Act
      let streaming =
        find_route(app_router, request)
        |> option.map(fn(found) { { found.0 }.streaming })

      // Assert
      streaming
      |> should()
      |> be_equal(Some(True))
      |> or_fail_with("POST /upload should match a streaming route")
    }),
    it("find_route example returns the id parameter", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/123")

      // Act
      let params = doc_core_router.find_user_params(router(), request)

      // Assert
      params
      |> should()
      |> be_equal([#("id", "123")])
      |> or_fail_with("params should be [#(\"id\", \"123\")]")
    }),
    it("allowed_methods example gives the methods of the path", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/items/7")

      // Act
      let methods = doc_core_router.item_methods(request)

      // Assert
      methods
      |> should()
      |> be_equal([Delete, Get])
      |> or_fail_with("POST /items/7 should give [Delete, Get]")
    }),
    it("allowed_methods example gives no methods for an unknown path", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/users")

      // Act
      let methods = doc_core_router.item_methods(request)

      // Assert
      methods
      |> should()
      |> be_equal([])
      |> or_fail_with("POST /users should give []")
    }),
    it(
      "build_controller_chain example runs the first middleware outermost",
      fn() {
        // Arrange
        let request = test_request.create_request(Get, "/")

        // Act
        let response = doc_core_router_build_controller_chain.handle(request)

        // Assert
        response
        |> should()
        |> extract_body_text()
        |> be_equal("outer(inner(controller))")
        |> or_fail_with("the body should be outer(inner(controller))")
      },
    ),
  ])
}

fn static_module_tests() -> UnitNode {
  group("dream/controllers/static", [
    it("asset router returns 404 for a file that is not there", fn() {
      // Arrange
      let app_router = doc_core_static.asset_router()

      // Act
      let response = send(app_router, Get, "/assets/missing.css")

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(404)
      |> or_fail_with("a missing file should give 404")
    }),
    it("serve_assets without a path parameter returns a JSON error", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/assets")

      // Act
      let response = doc_core_static.serve_assets(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"error\":\"Missing required path parameter: path\"}")
      |> or_fail_with("the body should be the missing parameter error")
    }),
    it("serve_public without a filepath parameter returns a JSON error", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/public")

      // Act
      let response = doc_core_static_serve.serve_public(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"error\":\"Missing required path parameter: filepath\"}")
      |> or_fail_with("the body should be the missing parameter error")
    }),
    it("serve_public refuses a path that leaves the root", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/public/../secret", [
          #("filepath", "../secret"),
        ])

      // Act
      let response = doc_core_static_serve.serve_public(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(404)
      |> or_fail_with("a path with .. should give 404")
    }),
    it("default_config example serves index files and has no listing", fn() {
      // Act
      let flags = config_flags(doc_core_static_default_config.asset_config())

      // Assert
      flags
      |> should()
      |> be_equal(#(True, False))
      |> or_fail_with("index should be on and listing off")
    }),
    it("with_directory_listing example allows a directory listing", fn() {
      // Act
      let flags =
        config_flags(doc_core_static_with_directory_listing.listing_config())

      // Assert
      flags
      |> should()
      |> be_equal(#(True, True))
      |> or_fail_with("index and listing should be on")
    }),
    it("without_index example turns off index files", fn() {
      // Act
      let flags = config_flags(doc_core_static_without_index.no_index_config())

      // Assert
      flags
      |> should()
      |> be_equal(#(False, False))
      |> or_fail_with("index and listing should be off")
    }),
    it(
      "with_custom_404 example uses the custom handler for a missing file",
      fn() {
        // Arrange
        let request = test_request.create_request(Get, "/downloads/report.pdf")

        // Act
        let response =
          doc_core_static_with_custom_404.download(request, "report.pdf")

        // Assert
        response
        |> should()
        |> extract_body_text()
        |> be_equal("No such file")
        |> or_fail_with("the body should be No such file")
      },
    ),
  ])
}

fn parser_module_tests() -> UnitNode {
  group("dream/router/parser", [
    it("module examples parse to the documented segments", fn() {
      // Arrange
      let expected = [
        [Literal("users"), Param("id")],
        [Literal("files"), MultiWildcard(Some("path"))],
        [Literal("images"), ExtensionPattern(["jpg", "png"])],
      ]

      // Act
      let segments = doc_core_parser.module_examples()

      // Assert
      segments
      |> should()
      |> be_equal(expected)
      |> or_fail_with("the module examples should parse as documented")
    }),
    it("parse_pattern examples parse to the documented segments", fn() {
      // Arrange
      let expected = [
        [Literal("users")],
        [Literal("users"), Param("id")],
        [Literal("public"), MultiWildcard(Some("filepath"))],
        [Literal("images"), ExtensionPattern(["jpg", "png"])],
      ]

      // Act
      let segments = doc_core_parser.parse_pattern_examples()

      // Assert
      segments
      |> should()
      |> be_equal(expected)
      |> or_fail_with("the parse_pattern examples should parse as documented")
    }),
    it("brace extensions are trimmed", fn() {
      // Arrange
      let expected = [
        Literal("images"),
        ExtensionPattern(["jpg", "png", "gif"]),
      ]

      // Act
      let segments = doc_core_parser.brace_extensions()

      // Assert
      segments
      |> should()
      |> be_equal(expected)
      |> or_fail_with("the extensions should be jpg, png and gif")
    }),
  ])
}

fn trie_module_tests() -> UnitNode {
  group("dream/router/trie", [
    it("new example finds GET users", fn() {
      // Arrange
      let users_trie = doc_core_trie.users_trie("list users")

      // Act
      let result = trie.lookup(users_trie, "GET", ["users"])

      // Assert
      result
      |> should()
      |> be_equal(Some(Match("list users", [])))
      |> or_fail_with("GET users should match list users")
    }),
    it("insert example finds POST users", fn() {
      // Arrange
      let user_trie = doc_core_trie.user_trie("show user", "create user")

      // Act
      let result = trie.lookup(user_trie, "POST", ["users"])

      // Assert
      result
      |> should()
      |> be_equal(Some(Match("create user", [])))
      |> or_fail_with("POST users should match create user")
    }),
    it("lookup example returns the handler and the id", fn() {
      // Arrange
      let user_trie = doc_core_trie.user_trie("show user", "create user")

      // Act
      let result = doc_core_trie.find_user(user_trie)

      // Assert
      result
      |> should()
      |> be_equal(Ok(#("show user", [#("id", "123")])))
      |> or_fail_with("GET users/123 should match show user with id 123")
    }),
  ])
}

/// The serve_index and allow_directory_listing flags of a static config.
fn config_flags(config: static.Config(Nil, Nil)) -> #(Bool, Bool) {
  #(config.serve_index, config.allow_directory_listing)
}
