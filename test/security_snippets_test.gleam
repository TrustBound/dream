//// Tests for the SECURITY.md snippet
////
//// test/snippets/security_validation.gleam is shown, line for line, in
//// SECURITY.md. Each test runs one path through the code of that block.

import dream/http/request.{Get}
import dream/http/response.{Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/request as test_request
import snippets/security_validation.{Database}

fn user_request(user_id: String) -> request.Request {
  test_request.create_request_with_params(Get, "/users/" <> user_id, [
    #("user_id", user_id),
  ])
}

pub fn tests() -> TestSuite {
  let db = Database(user_ids: [1, 2])
  describe("SECURITY.md snippets", [
    it("show_user returns a user that exists", fn() {
      // Arrange
      let request = user_request("1")

      // Act
      let response = security_validation.show_user(request, db)

      // Assert
      #(response.status, response.body)
      |> should()
      |> be_equal(#(200, Text("User 1")))
      |> or_fail_with("show_user should return user 1")
    }),
    it("show_user rejects an id that is not an integer", fn() {
      // Arrange
      let request = user_request("abc")

      // Act
      let response = security_validation.show_user(request, db)

      // Assert
      #(response.status, response.body)
      |> should()
      |> be_equal(#(400, Text("user_id must be an integer")))
      |> or_fail_with("show_user should reject abc with Dream's message")
    }),
    it("show_user rejects an integer that breaks the business rule", fn() {
      // Arrange
      let request = user_request("-5")

      // Act
      let response = security_validation.show_user(request, db)

      // Assert
      #(response.status, response.body)
      |> should()
      |> be_equal(#(400, Text("Invalid user ID")))
      |> or_fail_with("show_user should reject a negative id")
    }),
    it("show_user returns not found for a valid id with no user", fn() {
      // Arrange
      let request = user_request("9")

      // Act
      let response = security_validation.show_user(request, db)

      // Assert
      #(response.status, response.body)
      |> should()
      |> be_equal(#(404, Text("User not found")))
      |> or_fail_with("show_user should return 404 for user 9")
    }),
  ])
}
