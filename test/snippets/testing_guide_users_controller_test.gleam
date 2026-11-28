import dream/context.{AppContext}
import dream/http/request.{Get}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import fixtures/request as test_request
import snippets/testing_guide_users_controller as users_controller

pub fn tests() -> TestSuite {
  describe("users_controller", [
    group("index", [
      it("returns 200 for valid request", fn() {
        let request = test_request.create_request(Get, "/users")
        let context = AppContext("test-id")

        users_controller.index(request, context, EmptyServices).status
        |> should()
        |> be_equal(200)
        |> or_fail_with("Should return 200")
      }),
    ]),
  ])
}
