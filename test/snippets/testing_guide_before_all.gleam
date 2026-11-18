import dream/dream
import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status.{ok}
import dream/router.{route, router}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, after_all, before_all, describe, it}
import fixtures/request as test_request

pub fn tests() -> UnitTest {
  describe("server tests", [
    before_all(fn() {
      // Start shared resources once, such as a server
      AssertionOk
    }),
    after_all(fn() {
      // Stop them
      AssertionOk
    }),
    it("responds to GET /", fn() {
      let request = test_request.create_request(Get, "/")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> equal(200)
      |> or_fail_with("Should return 200")
    }),
    it("responds to GET /users", fn() {
      let request = test_request.create_request(Get, "/users")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> equal(200)
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
