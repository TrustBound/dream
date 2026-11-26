//// Tests for the naming conventions snippets
////
//// Each snippet in test/snippets/naming_*.gleam is shown, line for line, in
//// docs/reference/naming-conventions.md. Each test runs the code of one
//// code block in that page.

import dream/dream.{route_request}
import dream/http/cookie.{type Cookie, Cookie}
import dream/http/error
import dream/http/header.{Header}
import dream/http/request.{Delete, Get, Post, Trace}
import dream/http/response.{Text}
import dream/servers/mist/server.{stop}
import dream_errors
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/request.{
  create_request, create_request_with_params, create_request_with_query,
} as _
import gleam/dict.{from_list, new, to_list}
import gleam/http as gleam_http
import gleam/json.{UnexpectedEndOfInput}
import gleam/list.{map}
import gleam/option.{None, Some}
import gleam/result
import gleam/string.{starts_with}
import simplifile.{read, write}
import snippets/naming_auth.{
  Article, Credentials, EditArticles, Editor, Forbidden, InvalidToken, Reader,
  authenticate_request, authenticate_token, authenticate_user, authorize_request,
  authorize_user, check_request_permission, check_user_permission,
}
import snippets/naming_builder.{start}
import snippets/naming_checks.{
  has_cookie, has_header, has_json_body, is_json, is_post, is_secure,
}
import snippets/naming_conversion.{
  ParsedRequest, convert_cookie_to_header, convert_http_method_to_method,
  format_cookie_header, format_query_string, header_to_pair, pair_to_header,
  parse_request,
}
import snippets/naming_creation.{
  CookieBuilder, ResponseBuilder, build_cookie, build_response, create_cookie,
  create_header, create_response,
}
import snippets/naming_errors.{
  ConnectionRefused, ExpiredToken, handle_auth_error, handle_parse_error,
  recover_from_connection_error, recover_from_timeout,
}
import snippets/naming_factory.{initialize, user}
import snippets/naming_imports.{
  error_response, error_response_qualified, not_found_response,
  shared_error_response,
}
import snippets/naming_lifecycle.{
  DatabaseConfig, init_database, init_services, shutdown_services, start_server,
  stop_server,
}
import snippets/naming_modification.{
  add_link_and_route, remove_tracking, set_cache_and_theme,
}
import snippets/naming_module_namespace.{show_user_with_module_prefix}
import snippets/naming_processing.{
  handle_request, match_method, match_path, respond,
}
import snippets/naming_responses.{example_responses}
import snippets/naming_retrieval.{
  RequestDetails, list_names, list_values, summarize_request,
}
import snippets/naming_serialization.{
  deserialize_session, deserialize_user, serialize_session, serialize_user,
}
import snippets/naming_state.{
  load_config, load_user, restore_config, restore_sessions, save_config,
  save_user, store_session,
}
import snippets/naming_user
import snippets/naming_validation.{
  MissingEmail, PasswordTooShort, Signup, validate_cookie, validate_signup,
}
import snippets/naming_variables
import snippets/naming_variables_abbreviated
import snippets/naming_variables_good
import snippets/naming_variables_verbose

pub fn tests() -> TestSuite {
  describe("naming conventions", [
    module_namespace_tests(),
    import_tests(),
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

fn import_tests() -> UnitNode {
  group("imports", [
    it("bare and qualified calls make the same response", fn() {
      // Arrange
      let failure = error.NotFound("User not found")

      // Act
      let bare = error_response(failure)
      let qualified = error_response_qualified(failure)
      let not_found = not_found_response()

      // Assert
      #(bare.status, bare.body, qualified.body, not_found.body)
      |> should()
      |> be_equal(#(
        404,
        Text("User not found"),
        Text("User not found"),
        Text("User not found"),
      ))
      |> or_fail_with("bare and qualified calls should match")
    }),
    it("a clashing name stays qualified and still works", fn() {
      // Act
      let missing = shared_error_response(dream_errors.NotFound("gone"))
      let slow = shared_error_response(dream_errors.Timeout("slow", Nil))

      // Assert
      #(missing.status, missing.body, slow.status, slow.body)
      |> should()
      |> be_equal(#(404, Text("User not found"), 504, Text("Timed out")))
      |> or_fail_with("shared errors should map to responses")
    }),
  ])
}

fn module_namespace_tests() -> UnitNode {
  group("module namespace", [
    it("user.find and router.route work without a module prefix", fn() {
      // Arrange
      let request = create_request(Get, "/")

      // Act
      let found = naming_module_namespace.show_user(1)
      let response =
        route_request(naming_module_namespace.app_router(), request, Nil, Nil)

      // Assert
      #(found, response.body)
      |> should()
      |> be_equal(#(Ok(naming_user.User(id: 1, name: "Ada")), Text("Home")))
      |> or_fail_with("show_user and app_router should work")
    }),
    it("user.user_find finds the same user", fn() {
      // Act
      let found = show_user_with_module_prefix(1)

      // Assert
      found
      |> should()
      |> be_equal(Ok(naming_user.User(id: 1, name: "Ada")))
      |> or_fail_with("show_user_with_module_prefix should find user 1")
    }),
  ])
}

fn creation_tests() -> UnitNode {
  group("creation", [
    it("create functions make a response, a cookie and a header", fn() {
      // Act
      let result = #(
        create_response(204).status,
        create_cookie("theme", "dark"),
        create_header("Accept", "text/html"),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(
        204,
        simple_cookie("theme", "dark", False),
        Header("Accept", "text/html"),
      ))
      |> or_fail_with("create functions should make the values")
    }),
    it("build functions turn builders into a response and a cookie", fn() {
      // Arrange
      let response_builder =
        ResponseBuilder(
          status: 201,
          headers: [Header("Location", "/users/1")],
          body: "Created",
        )
      let cookie_builder =
        CookieBuilder(name: "session", value: "abc123", secure: True)

      // Act
      let response = build_response(response_builder)
      let cookie = build_cookie(cookie_builder)

      // Assert
      #(response.status, response.headers, response.body, cookie)
      |> should()
      |> be_equal(#(
        201,
        [Header("Location", "/users/1")],
        Text("Created"),
        simple_cookie("session", "abc123", True),
      ))
      |> or_fail_with("build functions should make the values")
    }),
  ])
}

fn retrieval_tests() -> UnitNode {
  group("retrieval", [
    it("get functions find a header, a cookie and a query parameter", fn() {
      // Arrange
      let request =
        request.Request(
          ..create_request_with_query(Get, "/", "page=2"),
          headers: [Header("content-type", "application/json")],
          cookies: [simple_cookie("session", "abc123", False)],
        )

      // Act
      let details = summarize_request(request)

      // Assert
      details
      |> should()
      |> be_equal(RequestDetails(
        content_type: Some("application/json"),
        session: Some(simple_cookie("session", "abc123", False)),
        page: Some("2"),
      ))
      |> or_fail_with("summarize_request should find all three values")
    }),
    it("name functions read the cookie name and the header name", fn() {
      // Act
      let names =
        list_names(
          simple_cookie("theme", "dark", False),
          Header("Accept", "text/html"),
        )

      // Assert
      names
      |> should()
      |> be_equal(["theme", "Accept"])
      |> or_fail_with("list_names should read both names")
    }),
    it("value functions read the cookie value and the header value", fn() {
      // Act
      let values =
        list_values(
          simple_cookie("theme", "dark", False),
          Header("Accept", "text/html"),
        )

      // Assert
      values
      |> should()
      |> be_equal(["dark", "text/html"])
      |> or_fail_with("list_values should read both values")
    }),
  ])
}

fn modification_tests() -> UnitNode {
  group("modification", [
    it("set functions replace a header and set a cookie", fn() {
      // Arrange
      let request =
        request.Request(..create_request(Get, "/"), headers: [
          Header("cache-control", "max-age=60"),
        ])

      // Act
      let result = set_cache_and_theme(request)

      // Assert
      result
      |> should()
      |> be_equal(
        #([Header("Cache-Control", "no-store")], [
          simple_cookie("theme", "dark", False),
        ]),
      )
      |> or_fail_with("set functions should replace the values")
    }),
    it("add functions add a header and a route", fn() {
      // Arrange
      let request =
        request.Request(..create_request(Get, "/"), headers: [
          Header("Accept", "text/html"),
        ])

      // Act
      let #(headers, app_router) = add_link_and_route(request)
      let response = route_request(app_router, request, Nil, Nil)

      // Assert
      #(headers, response.body)
      |> should()
      |> be_equal(#(
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
          ..create_request(Get, "/"),
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
      let result = remove_tracking(request)

      // Assert
      result
      |> should()
      |> be_equal(
        #([Header("Accept", "text/html")], [
          simple_cookie("theme", "dark", False),
        ]),
      )
      |> or_fail_with("remove functions should take out the tracking values")
    }),
  ])
}

fn conversion_tests() -> UnitNode {
  group("conversion", [
    it("convert functions change a method and a cookie", fn() {
      // Act
      let result = #(
        convert_http_method_to_method(gleam_http.Post),
        convert_http_method_to_method(gleam_http.Trace),
        convert_cookie_to_header(simple_cookie("theme", "dark", False)),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(Some(Post), Some(Trace), Header("Set-Cookie", "theme=dark")))
      |> or_fail_with("convert functions should change the types")
    }),
    it("parse functions read cookies and a method from text", fn() {
      // Arrange
      let headers = [Header("Cookie", "session=abc123")]

      // Act
      let parsed = parse_request(headers)

      // Assert
      parsed
      |> should()
      |> be_equal(
        ParsedRequest(
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
        format_cookie_header(simple_cookie("theme", "dark", False)),
        format_query_string([
          #("q", "dream web"),
          #("page", "2"),
        ]),
      )

      // Assert
      result
      |> should()
      |> be_equal(#("theme=dark", "q=dream%20web&page=2"))
      |> or_fail_with("format functions should write the text")
    }),
    it("short conversions change a header to a pair and back", fn() {
      // Act
      let result = #(
        header_to_pair(Header("Accept", "text/html")),
        pair_to_header(#("Accept", "text/html")),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(#("Accept", "text/html"), Header("Accept", "text/html")))
      |> or_fail_with("header_to_pair and pair_to_header should convert")
    }),
  ])
}

fn check_tests() -> UnitNode {
  group("boolean checks", [
    it("is functions check a request, a cookie and a response", fn() {
      // Arrange
      let request = create_request(Post, "/")
      let cookie = simple_cookie("session", "abc123", True)
      let response = response.json_response(200, "{}")

      // Act
      let result = [
        is_post(request),
        is_secure(cookie),
        is_json(response),
      ]

      // Assert
      result
      |> should()
      |> be_equal([True, True, True])
      |> or_fail_with("is functions should all be True")
    }),
    it("has functions check a body, a header and a cookie", fn() {
      // Arrange
      let request =
        request.Request(
          ..create_request(Post, "/"),
          content_type: Some("application/json"),
        )
      let headers = [Header("Accept", "text/html")]
      let cookies = [simple_cookie("theme", "dark", False)]

      // Act
      let result = [
        has_json_body(request),
        has_header(headers, "accept"),
        has_cookie(cookies, "session"),
      ]

      // Assert
      result
      |> should()
      |> be_equal([True, True, False])
      |> or_fail_with("has functions should find the body and the header")
    }),
  ])
}

fn processing_tests() -> UnitNode {
  group("processing", [
    it("handle functions answer 401 without and 200 with a token", fn() {
      // Arrange
      let anonymous = create_request(Get, "/")
      let signed_in =
        request.Request(..anonymous, headers: [
          Header("Authorization", "Bearer token-ada"),
        ])

      // Act
      let statuses = [
        handle_request(anonymous).status,
        handle_request(signed_in).status,
      ]

      // Assert
      statuses
      |> should()
      |> be_equal([401, 200])
      |> or_fail_with("handle_request should check the token")
    }),
    it("route_request sends GET / to its controller", fn() {
      // Arrange
      let request = create_request(Get, "/")

      // Act
      let response = respond(request)

      // Assert
      response.body
      |> should()
      |> be_equal(Text("Home"))
      |> or_fail_with("respond should route GET / to home")
    }),
    it("match functions compare paths and methods", fn() {
      // Act
      let result = [
        match_path("/users/:id", "/users/42"),
        match_path("/users/:id", "/posts/42"),
        match_method([Get, Post], Delete),
      ]

      // Assert
      result
      |> should()
      |> be_equal([True, False, False])
      |> or_fail_with("match functions should match only /users/42")
    }),
  ])
}

fn error_tests() -> UnitNode {
  group("error handling", [
    it("handle error functions turn errors into responses", fn() {
      // Act
      let parse_response = handle_parse_error(UnexpectedEndOfInput)
      let auth_response = handle_auth_error(ExpiredToken)

      // Assert
      #(parse_response.status, auth_response.body)
      |> should()
      |> be_equal(#(400, Text("Sign in again")))
      |> or_fail_with("handle error functions should make responses")
    }),
    it("recover functions retry and use the cached value", fn() {
      // Act
      let result = #(
        recover_from_timeout(Error(naming_errors.Timeout), fn() { Ok("fresh") }),
        recover_from_connection_error(Error(ConnectionRefused), "cached"),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(Ok("fresh"), Ok("cached")))
      |> or_fail_with("recover functions should recover")
    }),
  ])
}

fn bearer_request() -> request.Request {
  request.Request(..create_request(Get, "/"), headers: [
    Header("Authorization", "Bearer token-ada"),
  ])
}

fn auth_tests() -> UnitNode {
  let ada = naming_auth.User(id: 1, name: "Ada", role: Editor)
  let reader = naming_auth.User(id: 2, name: "Bo", role: Reader)
  let article = Article(id: 7, author_id: 1)
  group("authentication and authorization", [
    it("authenticate functions check credentials, tokens and requests", fn() {
      // Act
      let result = #(
        authenticate_user(Credentials(
          username: "ada",
          password: "correct-horse",
        )),
        authenticate_token("unknown-token"),
        authenticate_request(bearer_request()),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(Ok(ada), Error(InvalidToken), Ok(ada)))
      |> or_fail_with("authenticate functions should find Ada")
    }),
    it("authorize functions refuse a reader and allow an editor", fn() {
      // Act
      let result = #(
        authorize_user(reader, article),
        authorize_request(bearer_request(), article),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(Error(Forbidden), Ok(Nil)))
      |> or_fail_with("authorize functions should check the role")
    }),
    it("check permission functions test one permission", fn() {
      // Act
      let result = [
        check_user_permission(reader, EditArticles),
        check_request_permission(bearer_request(), EditArticles),
      ]

      // Assert
      result
      |> should()
      |> be_equal([False, True])
      |> or_fail_with("only the editor should edit articles")
    }),
  ])
}

fn validation_tests() -> UnitNode {
  group("validation", [
    it("validate functions tell what is wrong", fn() {
      // Arrange
      let signup = Signup(email: "ada.example.com", password: "short")

      // Act
      let result = #(
        validate_signup(signup),
        validate_cookie(simple_cookie("session", "abc123", False)),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(
        Error([
          MissingEmail,
          PasswordTooShort,
        ]),
        Error("The session cookie must be secure"),
      ))
      |> or_fail_with("validate functions should return the errors")
    }),
  ])
}

fn lifecycle_tests() -> UnitNode {
  let config = DatabaseConfig(url: "postgres://localhost/app", pool_size: 5)
  group("lifecycle", [
    it("start_server starts a server", fn() {
      // Act
      let started = start_server(free_port())
      let result = result.map(started, stop)

      // Assert
      result
      |> should()
      |> be_equal(Ok(Nil))
      |> or_fail_with("start_server should start a server")
    }),
    it("stop_server stops a server", fn() {
      // Arrange
      let started = start_server(free_port())

      // Act
      let result = result.map(started, stop_server)

      // Assert
      result
      |> should()
      |> be_equal(Ok(Nil))
      |> or_fail_with("stop_server should stop the server")
    }),
    it("init functions prepare the database and the services", fn() {
      // Act
      let result = #(
        init_services(config),
        init_database(DatabaseConfig(..config, pool_size: 0)),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(
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
      let result = shutdown_services(services)

      // Assert
      result
      |> should()
      |> be_equal(
        naming_lifecycle.Services(database: naming_lifecycle.Database(
          url: "postgres://localhost/app",
          connections: 0,
        )),
      )
      |> or_fail_with("shutdown_services should close all connections")
    }),
  ])
}

fn serialization_tests() -> UnitNode {
  group("serialization", [
    it("serialize functions encode a user and a session", fn() {
      // Act
      let result = #(
        serialize_user(naming_serialization.User(id: 1, name: "Ada")),
        serialize_session(naming_serialization.Session(id: "abc123", user_id: 1)),
      )

      // Assert
      result
      |> should()
      |> be_equal(#("{\"id\":1,\"name\":\"Ada\"}", <<"abc123:1":utf8>>))
      |> or_fail_with("serialize functions should encode the values")
    }),
    it("deserialize functions decode a user and a session", fn() {
      // Act
      let result = #(
        deserialize_user("{\"id\":1,\"name\":\"Ada\"}"),
        deserialize_session(<<"abc123:1":utf8>>),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(
        Ok(naming_serialization.User(id: 1, name: "Ada")),
        Ok(naming_serialization.Session(id: "abc123", user_id: 1)),
      ))
      |> or_fail_with("deserialize functions should decode the values")
    }),
  ])
}

fn state_tests() -> UnitNode {
  let ada = naming_state.User(id: 1, name: "Ada")
  let session = naming_state.Session(id: "abc123", user_id: 1)
  group("state management", [
    it("load functions read a user and a config file", fn() {
      // Arrange
      let database = naming_state.Database(users: from_list([#(1, ada)]))

      // Act
      let result = #(
        load_user(database, 1),
        load_config("gleam.toml")
          |> result.map(starts_with(_, "name = \"dream\"")),
      )

      // Assert
      result
      |> should()
      |> be_equal(#(Ok(ada), Ok(True)))
      |> or_fail_with("load functions should read the user and the file")
    }),
    it("save functions write a user and a config file", fn() {
      // Arrange
      let database = naming_state.Database(users: new())
      let path = "build/naming_snippets_saved_config.toml"

      // Act
      let saved = save_user(database, ada)
      let written = save_config("port = 3000", path)

      // Assert
      #(load_user(saved, 1), written, read(path))
      |> should()
      |> be_equal(#(Ok(ada), Ok(Nil), Ok("port = 3000")))
      |> or_fail_with("save functions should write the user and the file")
    }),
    it("store_session keeps a session in memory", fn() {
      // Act
      let sessions = store_session(new(), session)

      // Assert
      to_list(sessions)
      |> should()
      |> be_equal([#("abc123", session)])
      |> or_fail_with("store_session should keep the session")
    }),
    it("restore functions bring back sessions and a config file", fn() {
      // Arrange
      let backup_path = "build/naming_snippets_backup_config.toml"
      let path = "build/naming_snippets_restored_config.toml"
      let _ = write(to: backup_path, contents: "port = 4000")

      // Act
      let sessions = restore_sessions([session])
      let restored = restore_config(backup_path, path)

      // Assert
      #(to_list(sessions), restored, read(path))
      |> should()
      |> be_equal(#([#("abc123", session)], Ok(Nil), Ok("port = 4000")))
      |> or_fail_with("restore functions should bring back the saved copies")
    }),
  ])
}

fn response_tests() -> UnitNode {
  group("response builders", [
    it("type response functions set the status", fn() {
      // Act
      let statuses =
        example_responses()
        |> map(fn(response) { response.status })

      // Assert
      statuses
      |> should()
      |> be_equal([200, 200, 200, 303, 204])
      |> or_fail_with("each response should have its status")
    }),
  ])
}

fn builder_tests() -> UnitNode {
  group("builder pattern exception", [
    it("the server builder binds and listens", fn() {
      // Act
      let started = start(free_port())
      let result = result.map(started, stop)

      // Assert
      result
      |> should()
      |> be_equal(Ok(Nil))
      |> or_fail_with("the builder should start a server")
    }),
  ])
}

fn factory_tests() -> UnitNode {
  group("factory function exception", [
    it("router.router() makes a router", fn() {
      // Arrange
      let request = create_request(Get, "/")

      // Act
      let response =
        route_request(naming_factory.app_router(), request, Nil, Nil)

      // Assert
      response.body
      |> should()
      |> be_equal(Text("Home"))
      |> or_fail_with("app_router should route GET / to index")
    }),
    it("the ambiguous factories still return values", fn() {
      // Act
      let result = #(initialize(), user())

      // Assert
      result
      |> should()
      |> be_equal(#(
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
      |> be_equal(#(
        Ok(naming_factory.Database(url: "postgres://localhost/app")),
        Error("The database URL must start with postgres://"),
      ))
      |> or_fail_with("database should accept only postgres URLs")
    }),
  ])
}

fn variable_tests() -> UnitNode {
  let request = create_request_with_params(Get, "/users/1", [#("id", "1")])
  let services =
    naming_variables.Services(users: [naming_variables.User(id: 1, name: "Ada")])
  group("variable naming", [
    it("the good show_user returns the user name", fn() {
      // Act
      let response = naming_variables_good.show_user(request, Nil, services)

      // Assert
      response.body
      |> should()
      |> be_equal(Text("Ada"))
      |> or_fail_with("the good show_user should return Ada")
    }),
    it("the abbreviated show_user returns the user name", fn() {
      // Act
      let response =
        naming_variables_abbreviated.show_user(request, Nil, services)

      // Assert
      response.body
      |> should()
      |> be_equal(Text("Ada"))
      |> or_fail_with("the abbreviated show_user should return Ada")
    }),
    it("the verbose show_user returns the user name", fn() {
      // Act
      let response = naming_variables_verbose.show_user(request, Nil, services)

      // Assert
      response.body
      |> should()
      |> be_equal(Text("Ada"))
      |> or_fail_with("the verbose controller should return Ada")
    }),
  ])
}

/// Asks the operating system for a free TCP port.
@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
