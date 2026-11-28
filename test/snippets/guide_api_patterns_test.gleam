//// API patterns guide: a test of cursor pagination
////
//// The model is list_after of test/snippets/rest_api_guide_cursor_pagination.gleam.

import dream/http/error.{type Error, BadRequest}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import gleam/result
import snippets/rest_api_guide_cursor_pagination.{type Page, Page, Product}

fn products() -> List(rest_api_guide_cursor_pagination.Product) {
  [Product(1, "Desk"), Product(2, "Lamp"), Product(3, "Chair")]
}

// The first page, then the page that its cursor points to
fn second_page() -> Result(Page, Error) {
  use first <- result.try(rest_api_guide_cursor_pagination.list_after(
    products(),
    None,
    2,
  ))
  rest_api_guide_cursor_pagination.list_after(products(), first.next_cursor, 2)
}

pub fn tests() -> TestSuite {
  describe("list_after", [
    it("gives the first two products on the first page", fn() {
      // Act
      let page =
        rest_api_guide_cursor_pagination.list_after(products(), None, 2)

      // Assert
      page
      |> result.map(fn(first) { first.items })
      |> should
      |> be_equal(Ok([Product(1, "Desk"), Product(2, "Lamp")]))
      |> or_fail_with("the first page should hold products 1 and 2")
    }),
    it("gives the rest, and no cursor, on the last page", fn() {
      // Act
      let page = second_page()

      // Assert
      page
      |> should
      |> be_equal(Ok(Page(items: [Product(3, "Chair")], next_cursor: None)))
      |> or_fail_with("the second page should hold product 3 and end the list")
    }),
    it("refuses a cursor that it did not make", fn() {
      // Act
      let page =
        rest_api_guide_cursor_pagination.list_after(
          products(),
          option.Some("not-a-cursor"),
          2,
        )

      // Assert
      page
      |> should
      |> be_equal(Error(BadRequest("Invalid cursor")))
      |> or_fail_with("a made-up cursor should give BadRequest")
    }),
  ])
}
