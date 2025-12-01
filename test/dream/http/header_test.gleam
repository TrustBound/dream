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
        let headers = [
          Header("Content-Type", "application/json"),
          Header("Authorization", "Bearer token"),
        ]

        get_header(headers, "Content-Type")
        |> should()
        |> be_some()
        |> equal("application/json")
        |> or_fail_with("Expected Content-Type header value")
      }),
    ]),
    describe("set_header", [
      it("adds header to empty list", fn() {
        set_header([], "X-Custom", "value")
        |> should()
        |> have_length(1)
        |> or_fail_with("Expected one header after set_header")
      }),
    ]),
  ])
}
