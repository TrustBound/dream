import dream/context.{AppContext}
import dream/http/header.{Header}
import dream/http/request.{Get, Request}
import dream/http/response.{Response, Text}
import dream/router.{EmptyServices}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/option
import snippets/testing_guide_auth_middleware as auth

fn success_handler(_request, _context, _services) {
  Response(200, Text("Success"), [], [], option.None)
}

pub fn tests() -> UnitTest {
  describe("auth middleware", [
    it("returns 401 without token", fn() {
      let request = test_request.create_request(Get, "/protected")
      let context = AppContext("test-id")

      auth.middleware(request, context, EmptyServices, success_handler).status
      |> should()
      |> equal(401)
      |> or_fail_with("Should reject without token")
    }),
    it("calls next with valid token", fn() {
      let request =
        Request(..test_request.create_request(Get, "/protected"), headers: [
          Header("Authorization", "Bearer valid"),
        ])
      let context = AppContext("test-id")

      auth.middleware(request, context, EmptyServices, success_handler).status
      |> should()
      |> equal(200)
      |> or_fail_with("Should pass with valid token")
    }),
  ])
}
