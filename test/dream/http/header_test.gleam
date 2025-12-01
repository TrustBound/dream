//// Tests for dream/http/header module.

import dream/http/header.{Header, get_header, set_header}
import dream_test/assertions/should.{
  be_some, equal, have_length, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("header", [
    describe("get_header", [
      it("returns value when header exists", fn() {
        // Arrange
        let headers = [
          Header("Content-Type", "application/json"),
          Header("Authorization", "Bearer token"),
        ]

        // Act
        let result = get_header(headers, "Content-Type")

        // Assert
        result
        |> should()
        |> be_some()
        |> equal("application/json")
        |> or_fail_with("Expected Content-Type header value")
      }),
    ]),
    describe("set_header", [
      it("adds header to empty list", fn() {
        // Arrange
        let headers = []
        let name = "X-Custom"
        let value = "value"

        // Act
        let result = set_header(headers, name, value)

        // Assert
        result
        |> should()
        |> have_length(1)
        |> or_fail_with("Expected one header after set_header")
      }),
    ]),
  ])
}
