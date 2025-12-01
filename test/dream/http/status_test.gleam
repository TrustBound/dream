//// Tests for dream/http/status module.

import dream/http/status
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("status", [
    describe("ok", [
      it("equals 200", fn() {
        // Arrange
        let expected = 200

        // Act
        let result = status.ok

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("status.ok should equal 200")
      }),
    ]),
    describe("created", [
      it("equals 201", fn() {
        // Arrange
        let expected = 201

        // Act
        let result = status.created

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("status.created should equal 201")
      }),
    ]),
    describe("bad_request", [
      it("equals 400", fn() {
        // Arrange
        let expected = 400

        // Act
        let result = status.bad_request

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("status.bad_request should equal 400")
      }),
    ]),
    describe("not_found", [
      it("equals 404", fn() {
        // Arrange
        let expected = 404

        // Act
        let result = status.not_found

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("status.not_found should equal 404")
      }),
    ]),
    describe("conflict", [
      it("equals 409", fn() {
        // Arrange
        let expected = 409

        // Act
        let result = status.conflict

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("status.conflict should equal 409")
      }),
    ]),
    describe("internal_server_error", [
      it("equals 500", fn() {
        // Arrange
        let expected = 500

        // Act
        let result = status.internal_server_error

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("status.internal_server_error should equal 500")
      }),
    ]),
  ])
}
