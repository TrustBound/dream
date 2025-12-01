//// Tests for dream/http/status module.

import dream/http/status
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("status", [
    describe("ok", [
      it("equals 200", fn() {
        status.ok
        |> should()
        |> equal(200)
        |> or_fail_with("status.ok should equal 200")
      }),
    ]),
    describe("created", [
      it("equals 201", fn() {
        status.created
        |> should()
        |> equal(201)
        |> or_fail_with("status.created should equal 201")
      }),
    ]),
    describe("bad_request", [
      it("equals 400", fn() {
        status.bad_request
        |> should()
        |> equal(400)
        |> or_fail_with("status.bad_request should equal 400")
      }),
    ]),
    describe("not_found", [
      it("equals 404", fn() {
        status.not_found
        |> should()
        |> equal(404)
        |> or_fail_with("status.not_found should equal 404")
      }),
    ]),
    describe("conflict", [
      it("equals 409", fn() {
        status.conflict
        |> should()
        |> equal(409)
        |> or_fail_with("status.conflict should equal 409")
      }),
    ]),
    describe("internal_server_error", [
      it("equals 500", fn() {
        status.internal_server_error
        |> should()
        |> equal(500)
        |> or_fail_with("status.internal_server_error should equal 500")
      }),
    ]),
  ])
}
