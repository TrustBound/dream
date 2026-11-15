//// Tests for the naming conventions snippets
////
//// Each snippet in test/snippets/naming_*.gleam is shown, line for line, in
//// docs/reference/naming-conventions.md. Each test runs the code of one
//// code block in that page.

import dream/dream
import dream/http/cookie.{type Cookie, Cookie}
import dream/http/header.{Header}
import dream/http/request.{Delete, Get, Post}
import dream/http/response.{Text}
import dream/servers/mist/server
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/dict
import gleam/http as gleam_http
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile
import snippets/naming_auth
import snippets/naming_builder
import snippets/naming_checks
import snippets/naming_conversion
import snippets/naming_creation
import snippets/naming_errors
import snippets/naming_factory
import snippets/naming_lifecycle
import snippets/naming_modification
import snippets/naming_module_namespace
import snippets/naming_processing
import snippets/naming_responses
import snippets/naming_retrieval
import snippets/naming_serialization
import snippets/naming_state
import snippets/naming_user
import snippets/naming_validation
import snippets/naming_variables
import snippets/naming_variables_abbreviated
import snippets/naming_variables_good
import snippets/naming_variables_verbose

pub fn tests() -> UnitTest {
  describe("naming conventions", [
    module_namespace_tests(),
    creation_tests(),
    retrieval_tests(),
    modification_tests(),
    conversion_tests(),
    check_tests(),
    processing_tests(),
    error_tests(),
    auth_tests(),
    validation_tests(),
    lifecycle_tests(),
    serialization_tests(),
    state_tests(),
    response_tests(),
    builder_tests(),
    factory_tests(),
    variable_tests(),
  ])
}

fn simple_cookie(name: String, value: String, secure: Bool) -> Cookie {
  Cookie(
    name: name,
    value: value,
    expires: None,
    max_age: None,
    domain: None,
    path: None,
    secure: secure,
    http_only: False,
    same_site: None,
  )
}

fn module_namespace_tests() -> UnitTest {
  describe("module namespace", [
    it("user.find and router.route work without a module prefix", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let found = naming_module_namespace.show_user(1)
      let response =
        dream.route_request(
          naming_module_namespace.app_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      #(found, response.body)
      |> should()
      |> equal(#(Ok(naming_user.User(id: 1, name: "Ada")), Text("Home")))
      |> or_fail_with("show_user and app_router should work")
    }),
    it("user.user_find finds the same user", fn() {
      // Act
      let found = naming_module_namespace.show_user_with_module_prefix(1)

      // Assert
      found
      |> should()
      |> equal(Ok(naming_user.User(id: 1, name: "Ada")))
      |> or_fail_with("show_user_with_module_prefix should find user 1")
    }),
  ])
}

fn creation_tests() -> UnitTest {
  describe("creation", [
    it("create functions make a response, a cookie and a header", fn() {
      // Act
      let result = #(
        naming_creation.create_response(204).status,
        naming_creation.create_cookie("theme", "dark"),
        naming_creation.create_header("Accept", "text/html"),
      )

      // Assert
      result
      |> should()
      |> equal(#(
        204,
        simple_cookie("theme", "dark", False),
        Header("Accept", "text/html"),
      ))
      |> or_fail_with("create functions should make the values")
    }),
    it("build functions turn builders into a response and a cookie", fn() {
      // Arrange
      let response_builder =
        naming_creation.ResponseBuilder(
          status: 201,
          headers: [Header("Location", "/users/1")],
          body: "Created",
        )
      let cookie_builder =
        naming_creation.CookieBuilder(
          name: "session",
          value: "abc123",
          secure: True,
        )

      // Act
      let response = naming_creation.build_response(response_builder)
      let cookie = naming_creation.build_cookie(cookie_builder)

      // Assert
      #(response.status, response.headers, response.body, cookie)
      |> should()
      |> equal(#(
        201,
        [Header("Location", "/users/1")],
        Text("Created"),
        simple_cookie("session", "abc123", True),
      ))
      |> or_fail_with("build functions should make the values")
    }),
  ])
}

fn retrieval_tests() -> UnitTest {
  describe("retrieval", [
    it("get functions find a header, a cookie and a query parameter", fn() {
      // Arrange
      let request =
        request.Request(
          ..test_request.create_request_with_query(Get, "/", "page=2"),
          headers: [Header("content-type", "application/json")],
          cookies: [simple_cookie("session", "abc123", False)],
        )

      // Act
      let details = naming_retrieval.summarize_request(request)

      // Assert
      details
      |> should()
      |> equal(naming_retrieval.RequestDetails(
        content_type: Some("application/json"),
        session: Some(simple_cookie("session", "abc123", False)),
        page: Some("2"),
      ))
      |> or_fail_with("summarize_request should find all three values")
    }),
    it("name functions read the cookie name and the header name", fn() {
      // Act
      let names =
        naming_retrieval.list_names(
          simple_cookie("theme", "dark", False),
          Header("Accept", "text/html"),
        )

      // Assert
      names
      |> should()
      |> equal(["theme", "Accept"])
      |> or_fail_with("list_names should read both names")
    }),
    it("value functions read the cookie value and the header value", fn() {
      // Act
      let values =
        naming_retrieval.list_values(
          simple_cookie("theme", "dark", False),
          Header("Accept", "text/html"),
        )

      // Assert
      values
      |> should()
      |> equal(["dark", "text/html"])
      |> or_fail_with("list_values should read both values")
    }),
  ])
}

fn modification_tests() -> UnitTest {
  describe("modification", [
    it("set functions replace a header and set a cookie", fn() {
      // Arrange
      let request =
        request.Request(..test_request.create_request(Get, "/"), headers: [
          Header("cache-control", "max-age=60"),
        ])

      // Act
      let result = naming_modification.set_cache_and_theme(request)

      // Assert
      result
      |> should()
      |> equal(
        #([Header("Cache-Control", "no-store")], [
          simple_cookie("theme", "dark", False),
        ]),
      )
      |> or_fail_with("set functions should replace the values")
    }),
    it("add functions add a header and a route", fn() {
      // Arrange
      let request =
        request.Request(..test_request.create_request(Get, "/"), headers: [
          Header("Accept", "text/html"),
        ])

      // Act
      let #(headers, app_router) =
        naming_modification.add_link_and_route(request)
      let response = dream.route_request(app_router, request, Nil, Nil)

      // Assert
      #(headers, response.body)
      |> should()
      |> equal(#(
        [
          Header("Link", "</app.css>; rel=preload"),
          Header("Accept", "text/html"),
        ],
        Text("Home"),
      ))
      |> or_fail_with("add functions should keep the old values")
    }),
    it("remove functions take out a header and a cookie", fn() {
      // Arrange
      let request =
        request.Request(
          ..test_request.create_request(Get, "/"),
          headers: [
            Header("X-Tracking-Id", "42"),
            Header("Accept", "text/html"),
          ],
          cookies: [
            simple_cookie("tracking", "42", False),
            simple_cookie("theme", "dark", False),
          ],
        )

      // Act
      let result = naming_modification.remove_tracking(request)

      // Assert
      result
      |> should()
      |> equal(
        #([Header("Accept", "text/html")], [
          simple_cookie("theme", "dark", False),
        ]),
      )
      |> or_fail_with("remove functions should take out the tracking values")
    }),
  ])
}

fn conversion_tests() -> UnitTest {
  describe("conversion", [
    it("convert functions change a method and a cookie", fn() {
      // Act
      let result = #(
        naming_conversion.convert_http_method_to_method(gleam_http.Post),
        naming_conversion.convert_http_method_to_method(gleam_http.Trace),
        naming_conversion.convert_cookie_to_header(simple_cookie(
          "theme",
          "dark",
          False,
        )),
      )

      // Assert
      result
      |> should()
      |> equal(#(Some(Post), None, Header("Set-Cookie", "theme=dark")))
      |> or_fail_with("convert functions should change the types")
    }),
    it("parse functions read cookies and a method from text", fn() {
      // Arrange
      let headers = [Header("Cookie", "session=abc123")]

      // Act
      let parsed = naming_conversion.parse_request(headers)

      // Assert
      parsed
      |> should()
      |> equal(
        naming_conversion.ParsedRequest(
          cookies: [
            simple_cookie("theme", "dark", False),
            simple_cookie("session", "abc123", False),
          ],
          method: Some(Post),
          header_cookies: [simple_cookie("session", "abc123", False)],
        ),
      )
      |> or_fail_with("parse_request should parse all three values")
    }),
    it("format functions write a cookie and a query string", fn() {
      // Act
      let result = #(
        naming_conversion.format_cookie_header(simple_cookie(
          "theme",
          "dark",
          False,
        )),
        naming_conversion.format_query_string([
          #("q", "dream web"),
          #("page", "2"),
        ]),
      )

      // Assert
      result
      |> should()
      |> equal(#("theme=dark", "q=dream%20web&page=2"))
      |> or_fail_with("format functions should write the text")
    }),
    it("short conversions change a header to a pair and back", fn() {
      // Act
      let result = #(
        naming_conversion.header_to_pair(Header("Accept", "text/html")),
        naming_conversion.pair_to_header(#("Accept", "text/html")),
      )

      // Assert
      result
      |> should()
      |> equal(#(#("Accept", "text/html"), Header("Accept", "text/html")))
      |> or_fail_with("header_to_pair and pair_to_header should convert")
    }),
  ])
}

fn check_tests() -> UnitTest {
  describe("boolean checks", [
    it("is functions check a request, a cookie and a response", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/")
      let cookie = simple_cookie("session", "abc123", True)
      let response = response.json_response(200, "{}")

      // Act
      let result = [
        naming_checks.is_post(request),
        naming_checks.is_secure(cookie),
        naming_checks.is_json(response),
      ]

      // Assert
      result
      |> should()
      |> equal([True, True, True])
      |> or_fail_with("is functions should all be True")
    }),
    it("has functions check a body, a header and a cookie", fn() {
      // Arrange
      let request =
        request.Request(
          ..test_request.create_request(Post, "/"),
          content_type: Some("application/json"),
        )
      let headers = [Header("Accept", "text/html")]
      let cookies = [simple_cookie("theme", "dark", False)]

      // Act
      let result = [
        naming_checks.has_json_body(request),
        naming_checks.has_header(headers, "accept"),
        naming_checks.has_cookie(cookies, "session"),
      ]

      // Assert
      result
      |> should()
      |> equal([True, True, False])
      |> or_fail_with("has functions should find the body and the header")
    }),
  ])
}

fn processing_tests() -> UnitTest {
  describe("processing", [
    it("handle functions answer 401 without and 200 with a token", fn() {
      // Arrange
      let anonymous = test_request.create_request(Get, "/")
      let signed_in =
        request.Request(..anonymous, headers: [
          Header("Authorization", "Bearer token-ada"),
        ])

      // Act
      let statuses = [
        naming_processing.handle_request(anonymous).status,
        naming_processing.handle_request(signed_in).status,
      ]

      // Assert
      statuses
      |> should()
      |> equal([401, 200])
      |> or_fail_with("handle_request should check the token")
    }),
    it("route_request sends GET / to its controller", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response = naming_processing.respond(request)

      // Assert
      response.body
      |> should()
      |> equal(Text("Home"))
      |> or_fail_with("respond should route GET / to home")
    }),
    it("match functions compare paths and methods", fn() {
      // Act
      let result = [
        naming_processing.match_path("/users/:id", "/users/42"),
        naming_processing.match_path("/users/:id", "/posts/42"),
        naming_processing.match_method([Get, Post], Delete),
      ]

      // Assert
      result
      |> should()
      |> equal([True, False, False])
      |> or_fail_with("match functions should match only /users/42")
    }),
  ])
}

fn error_tests() -> UnitTest {
  describe("error handling", [
    it("handle error functions turn errors into responses", fn() {
      // Act
      let parse_response =
        naming_errors.handle_parse_error(json.UnexpectedEndOfInput)
      let auth_response =
        naming_errors.handle_auth_error(naming_errors.ExpiredToken)

      // Assert
      #(parse_response.status, auth_response.body)
      |> should()
      |> equal(#(400, Text("Sign in again")))
      |> or_fail_with("handle error functions should make responses")
    }),
    it("recover functions retry and use the cached value", fn() {
      // Act
      let result = #(
        naming_errors.recover_from_timeout(Error(naming_errors.Timeout), fn() {
          Ok("fresh")
        }),
        naming_errors.recover_from_connection_error(
          Error(naming_errors.ConnectionRefused),
          "cached",
        ),
      )

      // Assert
      result
      |> should()
      |> equal(#(Ok("fresh"), Ok("cached")))
      |> or_fail_with("recover functions should recover")
    }),
  ])
}

fn bearer_request() -> request.Request {
  request.Request(..test_request.create_request(Get, "/"), headers: [
    Header("Authorization", "Bearer token-ada"),
  ])
}

fn auth_tests() -> UnitTest {
  let ada = naming_auth.User(id: 1, name: "Ada", role: naming_auth.Editor)
  let reader = naming_auth.User(id: 2, name: "Bo", role: naming_auth.Reader)
  let article = naming_auth.Article(id: 7, author_id: 1)
  describe("authentication and authorization", [
    it("authenticate functions check credentials, tokens and requests", fn() {
      // Act
      let result = #(
        naming_auth.authenticate_user(naming_auth.Credentials(
          username: "ada",
          password: "correct-horse",
        )),
        naming_auth.authenticate_token("unknown-token"),
        naming_auth.authenticate_request(bearer_request()),
      )

      // Assert
      result
      |> should()
      |> equal(#(Ok(ada), Error(naming_auth.InvalidToken), Ok(ada)))
      |> or_fail_with("authenticate functions should find Ada")
    }),
    it("authorize functions refuse a reader and allow an editor", fn() {
      // Act
      let result = #(
        naming_auth.authorize_user(reader, article),
        naming_auth.authorize_request(bearer_request(), article),
      )

      // Assert
      result
      |> should()
      |> equal(#(Error(naming_auth.Forbidden), Ok(Nil)))
      |> or_fail_with("authorize functions should check the role")
    }),
    it("check permission functions test one permission", fn() {
      // Act
      let result = [
        naming_auth.check_user_permission(reader, naming_auth.EditArticles),
        naming_auth.check_request_permission(
          bearer_request(),
          naming_auth.EditArticles,
        ),
      ]

      // Assert
      result
      |> should()
      |> equal([False, True])
      |> or_fail_with("only the editor should edit articles")
    }),
  ])
}

fn validation_tests() -> UnitTest {
  describe("validation", [
    it("validate functions tell what is wrong", fn() {
      // Arrange
      let signup =
        naming_validation.Signup(email: "ada.example.com", password: "short")

      // Act
      let result = #(
        naming_validation.validate_signup(signup),
        naming_validation.validate_cookie(simple_cookie(
          "session",
          "abc123",
          False,
        )),
      )

      // Assert
      result
      |> should()
      |> equal(#(
        Error([
          naming_validation.MissingEmail,
          naming_validation.PasswordTooShort,
        ]),
        Error("The session cookie must be secure"),
      ))
      |> or_fail_with("validate functions should return the errors")
    }),
  ])
}

fn lifecycle_tests() -> UnitTest {
  let config =
    naming_lifecycle.DatabaseConfig(
      url: "postgres://localhost/app",
      pool_size: 5,
    )
  describe("lifecycle", [
    it("start_server starts a server", fn() {
      // Act
      let started = naming_lifecycle.start_server(free_port())
      let result = result.map(started, server.stop)

      // Assert
      result
      |> should()
      |> equal(Ok(Nil))
      |> or_fail_with("start_server should start a server")
    }),
    it("stop_server stops a server", fn() {
      // Arrange
      let started = naming_lifecycle.start_server(free_port())

      // Act
      let result = result.map(started, naming_lifecycle.stop_server)

      // Assert
      result
      |> should()
      |> equal(Ok(Nil))
      |> or_fail_with("stop_server should stop the server")
    }),
    it("init functions prepare the database and the services", fn() {
      // Act
      let result = #(
        naming_lifecycle.init_services(config),
        naming_lifecycle.init_database(
          naming_lifecycle.DatabaseConfig(..config, pool_size: 0),
        ),
      )

      // Assert
      result
      |> should()
      |> equal(#(
        Ok(
          naming_lifecycle.Services(database: naming_lifecycle.Database(
            url: "postgres://localhost/app",
            connections: 5,
          )),
        ),
        Error("pool_size must be greater than 0"),
      ))
      |> or_fail_with("init functions should check the pool size")
    }),
    it("shutdown functions close the connections", fn() {
      // Arrange
      let services =
        naming_lifecycle.Services(database: naming_lifecycle.Database(
          url: "postgres://localhost/app",
          connections: 5,
        ))

      // Act
      let result = naming_lifecycle.shutdown_services(services)

      // Assert
      result
      |> should()
      |> equal(
        naming_lifecycle.Services(database: naming_lifecycle.Database(
          url: "postgres://localhost/app",
          connections: 0,
        )),
      )
      |> or_fail_with("shutdown_services should close all connections")
    }),
  ])
}

fn serialization_tests() -> UnitTest {
  describe("serialization", [
    it("serialize functions encode a user and a session", fn() {
      // Act
      let result = #(
        naming_serialization.serialize_user(naming_serialization.User(
          id: 1,
          name: "Ada",
        )),
        naming_serialization.serialize_session(naming_serialization.Session(
          id: "abc123",
          user_id: 1,
        )),
      )

      // Assert
      result
      |> should()
      |> equal(#("{\"id\":1,\"name\":\"Ada\"}", <<"abc123:1":utf8>>))
      |> or_fail_with("serialize functions should encode the values")
    }),
    it("deserialize functions decode a user and a session", fn() {
      // Act
      let result = #(
        naming_serialization.deserialize_user("{\"id\":1,\"name\":\"Ada\"}"),
        naming_serialization.deserialize_session(<<"abc123:1":utf8>>),
      )

      // Assert
      result
      |> should()
      |> equal(#(
        Ok(naming_serialization.User(id: 1, name: "Ada")),
        Ok(naming_serialization.Session(id: "abc123", user_id: 1)),
      ))
      |> or_fail_with("deserialize functions should decode the values")
    }),
  ])
}

fn state_tests() -> UnitTest {
  let ada = naming_state.User(id: 1, name: "Ada")
  let session = naming_state.Session(id: "abc123", user_id: 1)
  describe("state management", [
    it("load functions read a user and a config file", fn() {
      // Arrange
      let database = naming_state.Database(users: dict.from_list([#(1, ada)]))

      // Act
      let result = #(
        naming_state.load_user(database, 1),
        naming_state.load_config("gleam.toml")
          |> result.map(string.starts_with(_, "name = \"dream\"")),
      )

      // Assert
      result
      |> should()
      |> equal(#(Ok(ada), Ok(True)))
      |> or_fail_with("load functions should read the user and the file")
    }),
    it("save functions write a user and a config file", fn() {
      // Arrange
      let database = naming_state.Database(users: dict.new())
      let path = "build/naming_snippets_saved_config.toml"

      // Act
      let saved = naming_state.save_user(database, ada)
      let written = naming_state.save_config("port = 3000", path)

      // Assert
      #(naming_state.load_user(saved, 1), written, simplifile.read(path))
      |> should()
      |> equal(#(Ok(ada), Ok(Nil), Ok("port = 3000")))
      |> or_fail_with("save functions should write the user and the file")
    }),
    it("store_session keeps a session in memory", fn() {
      // Act
      let sessions = naming_state.store_session(dict.new(), session)

      // Assert
      dict.to_list(sessions)
      |> should()
      |> equal([#("abc123", session)])
      |> or_fail_with("store_session should keep the session")
    }),
    it("restore functions bring back sessions and a config file", fn() {
      // Arrange
      let backup_path = "build/naming_snippets_backup_config.toml"
      let path = "build/naming_snippets_restored_config.toml"
      let _ = simplifile.write(to: backup_path, contents: "port = 4000")

      // Act
      let sessions = naming_state.restore_sessions([session])
      let restored = naming_state.restore_config(backup_path, path)

      // Assert
      #(dict.to_list(sessions), restored, simplifile.read(path))
      |> should()
      |> equal(#([#("abc123", session)], Ok(Nil), Ok("port = 4000")))
      |> or_fail_with("restore functions should bring back the saved copies")
    }),
  ])
}

fn response_tests() -> UnitTest {
  describe("response builders", [
    it("type response functions set the status", fn() {
      // Act
      let statuses =
        naming_responses.example_responses()
        |> list.map(fn(response) { response.status })

      // Assert
      statuses
      |> should()
      |> equal([200, 200, 200, 303, 204])
      |> or_fail_with("each response should have its status")
    }),
  ])
}

fn builder_tests() -> UnitTest {
  describe("builder pattern exception", [
    it("the server builder binds and listens", fn() {
      // Act
      let started = naming_builder.start(free_port())
      let result = result.map(started, server.stop)

      // Assert
      result
      |> should()
      |> equal(Ok(Nil))
      |> or_fail_with("the builder should start a server")
    }),
  ])
}

fn factory_tests() -> UnitTest {
  describe("factory function exception", [
    it("router.router() makes a router", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(naming_factory.app_router(), request, Nil, Nil)

      // Assert
      response.body
      |> should()
      |> equal(Text("Home"))
      |> or_fail_with("app_router should route GET / to index")
    }),
    it("the ambiguous factories still return values", fn() {
      // Act
      let result = #(naming_factory.initialize(), naming_factory.user())

      // Assert
      result
      |> should()
      |> equal(#(
        Ok(naming_factory.Services(users: [])),
        Ok(naming_factory.User(id: 1, name: "Ada")),
      ))
      |> or_fail_with("initialize and user should return values")
    }),
    it("database checks the URL", fn() {
      // Act
      let result = #(
        naming_factory.database("postgres://localhost/app"),
        naming_factory.database("mysql://localhost/app"),
      )

      // Assert
      result
      |> should()
      |> equal(#(
        Ok(naming_factory.Database(url: "postgres://localhost/app")),
        Error("The database URL must start with postgres://"),
      ))
      |> or_fail_with("database should accept only postgres URLs")
    }),
  ])
}

fn variable_tests() -> UnitTest {
  let request =
    test_request.create_request_with_params(Get, "/users/1", [#("id", "1")])
  let services =
    naming_variables.Services(users: [naming_variables.User(id: 1, name: "Ada")])
  describe("variable naming", [
    it("the good show_user returns the user name", fn() {
      // Act
      let response = naming_variables_good.show_user(request, Nil, services)

      // Assert
      response.body
      |> should()
      |> equal(Text("Ada"))
      |> or_fail_with("the good show_user should return Ada")
    }),
    it("the abbreviated show_user returns the user name", fn() {
      // Act
      let response =
        naming_variables_abbreviated.show_user(request, Nil, services)

      // Assert
      response.body
      |> should()
      |> equal(Text("Ada"))
      |> or_fail_with("the abbreviated show_user should return Ada")
    }),
    it("the verbose show_user returns the user name", fn() {
      // Act
      let response = naming_variables_verbose.show_user(request, Nil, services)

      // Assert
      response.body
      |> should()
      |> equal(Text("Ada"))
      |> or_fail_with("the verbose controller should return Ada")
    }),
  ])
}

/// Asks the operating system for a free TCP port.
@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
