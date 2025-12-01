//// Tests for dream/servers/mist/request module.
////
//// Note: convert_metadata() requires mist.Connection which is opaque and cannot
//// be created in unit tests. This function is tested through integration tests
//// via the handler.

import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("request", [
    describe("convert_metadata", [
      it("is tested via integration tests due to opaque mist types", fn() {
        // mist.Connection is an opaque type that cannot be instantiated
        // outside of Mist's runtime. The convert_metadata function is
        // tested through integration tests via the handler.
        AssertionOk
      }),
    ]),
  ])
}
