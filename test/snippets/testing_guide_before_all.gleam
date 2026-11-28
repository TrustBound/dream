import dream/dream
import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status.{ok}
import dream/router.{route, router}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{after_all, before_all, describe, it}
import fixtures/request as test_request

pub fn tests() -> TestSuite {
  describe("server tests", [
    before_all(fn() {
      // Start shared resources once, such as a server
      Ok(Nil)
    }),
    after_all(fn() {
      // Stop them
      Ok(Nil)
    }),
    it("responds to GET /", fn() {
      let request = test_request.create_request(Get, "/")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> be_equal(200)
      |> or_fail_with("Should return 200")
    }),
    it("responds to GET /users", fn() {
      let request = test_request.create_request(Get, "/users")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> be_equal(200)
      |> or_fail_with("Should return 200")
    }),
  ])
}

pub fn app_router() -> router.Router(Nil, Nil) {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  |> route(method: Get, path: "/users", controller: list_users, middleware: [])
}

fn show_home(_request, _context, _services) {
  text_response(ok, "Home")
}

fn list_users(_request, _context, _services) {
  text_response(ok, "Users")
}
