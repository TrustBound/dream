import dream/http/error.{InternalServerError}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}

pub fn tests() -> TestSuite {
  describe("dream/http/error", [
    group("to_status_code", [
      it("returns 500 for InternalServerError", fn() {
        // Arrange
        let database_error = InternalServerError("Database connection failed")

        // Act
        let result = error.to_status_code(database_error)

        // Assert
        result
        |> should()
        |> be_equal(500)
        |> or_fail_with("Expected 500")
      }),
    ]),
  ])
}
