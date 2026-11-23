import dream/http/request.{Post, Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/request as test_request

pub fn tests() -> TestSuite {
  describe("request fixture", [
    it("creates POST request with body", fn() {
      let request =
        test_request.create_request_with_body(
          Post,
          "/users",
          "{\"name\":\"Alice\"}",
        )

      request.body
      |> should()
      |> be_equal(Text("{\"name\":\"Alice\"}"))
      |> or_fail_with("Body should be the JSON")
    }),
  ])
}
