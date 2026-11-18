import dream/http/request.{Post, Text}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, it}
import fixtures/request as test_request

pub fn tests() -> UnitTest {
  it("creates POST request with body", fn() {
    let request =
      test_request.create_request_with_body(
        Post,
        "/users",
        "{\"name\":\"Alice\"}",
      )

    request.body
    |> should()
    |> equal(Text("{\"name\":\"Alice\"}"))
    |> or_fail_with("Body should be the JSON")
  })
}
