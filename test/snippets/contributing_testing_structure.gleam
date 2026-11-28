import dream/http/error.{InternalServerError}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("dream/http/error", [
    describe("to_status_code", [
      it("returns 500 for InternalServerError", fn() {
        // Arrange
        let database_error = InternalServerError("Database connection failed")

        // Act
        let result = error.to_status_code(database_error)

        // Assert
        result
        |> should()
        |> equal(500)
        |> or_fail_with("Expected 500")
      }),
    ]),
  ])
}
