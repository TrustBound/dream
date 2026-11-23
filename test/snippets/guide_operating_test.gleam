//// Operating guide: a test of the start error for a port that is in use

import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{route, router}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/otp/actor
import gleam/result

const port = 39_871

fn index(_request, _context, _services) {
  text_response(status.ok, "Hello")
}

fn start() -> Result(server.ServerHandle, actor.StartError) {
  server.new()
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: index, middleware: []),
  )
  |> server.bind("localhost")
  |> server.listen_with_handle(port)
}

// Starts a server, tries a second one on the same port, and stops the first
fn second_start_error() -> Result(Nil, actor.StartError) {
  use first <- result.try(start())
  let second = start()
  server.stop(first)
  result.map(second, fn(_handle) { Nil })
}

pub fn tests() -> TestSuite {
  describe("listen_with_handle", [
    it("refuses a port that another server holds", fn() {
      // Act
      let second = second_start_error()

      // Assert
      second
      |> should
      |> be_equal(
        Error(actor.InitFailed(
          "Port 39871 already in use on localhost. Stop the process using that port or choose a different one.",
        )),
      )
      |> or_fail_with("the second start should fail with the port")
    }),
  ])
}
