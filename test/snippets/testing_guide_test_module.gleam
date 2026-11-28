import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/string

pub fn tests() -> TestSuite {
  describe("slug", [
    group("create_slug", [
      it("joins lowercase words with dashes", fn() {
        // Arrange
        let title = "Hello World"

        // Act
        let result = create_slug(title)

        // Assert
        result
        |> should()
        |> be_equal("hello-world")
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
