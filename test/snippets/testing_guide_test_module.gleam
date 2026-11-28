import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/string

pub fn tests() -> UnitTest {
  describe("slug", [
    describe("create_slug", [
      it("joins lowercase words with dashes", fn() {
        // Arrange
        let title = "Hello World"

        // Act
        let result = create_slug(title)

        // Assert
        result
        |> should()
        |> equal("hello-world")
        |> or_fail_with("Should return a lowercase slug")
      }),
    ]),
  ])
}

pub fn create_slug(title: String) -> String {
  title
  |> string.lowercase()
  |> string.split(" ")
  |> string.join("-")
}
