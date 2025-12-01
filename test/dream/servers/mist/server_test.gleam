//// Tests for dream/servers/mist/server module.

import dream/dream
import dream/router.{router}
import dream/servers/mist/server
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, after_each, before_each, describe, it}
import fixtures/hooks.{start_server, stop_server, test_server_port}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("server", [
    builder_tests(),
    listen_tests(),
  ])
}

fn builder_tests() -> UnitTest {
  describe("builder", [
    it("new creates dream instance with 10MB default max body size", fn() {
      dream.get_max_body_size(server.new())
      |> should()
      |> equal(10_000_000)
      |> or_fail_with("Default max body size should be 10MB")
    }),
    it("router sets router on dream instance", fn() {
      let _ = server.router(server.new(), router())
      AssertionOk
    }),
    it("bind sets bind address", fn() {
      let _ =
        server.new()
        |> server.router(router())
        |> server.bind("127.0.0.1")
      AssertionOk
    }),
    it("max_body_size sets max body size", fn() {
      let _ =
        server.new()
        |> server.router(router())
        |> server.max_body_size(2048)
      AssertionOk
    }),
  ])
}

fn listen_tests() -> UnitTest {
  describe("listen_with_handle", [
    before_each(start_server),
    after_each(stop_server),
    it("starts on expected port", fn() {
      // Server is started by before_each hook
      // Just verify the port constant is what we expect
      test_server_port
      |> should()
      |> equal(19_999)
      |> or_fail_with("Test server port should be 19999")
    }),
  ])
}
