import dream/context.{AppContext}
import dream/http/request.{Get}
import dream/router.{EmptyServices}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import snippets/testing_guide_users_controller as users_controller

pub fn tests() -> UnitTest {
  describe("users_controller", [
    describe("index", [
      it("returns 200 for valid request", fn() {
        let request = test_request.create_request(Get, "/users")
        let context = AppContext("test-id")

        users_controller.index(request, context, EmptyServices).status
        |> should()
        |> equal(200)
        |> or_fail_with("Should return 200")
      }),
    ]),
  ])
}
