//// Test all README snippets by actually running them.
////
//// This ensures documentation examples remain valid and executable.

import gleeunit/should
import snippets/config_mode_method_specific
import snippets/config_mode_ordering
import snippets/config_mode_prefix
import snippets/programmatic_mode

pub fn programmatic_mode_test() {
  programmatic_mode.run()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn config_mode_prefix_test() {
  config_mode_prefix.run()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn config_mode_method_specific_test() {
  config_mode_method_specific.run()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn config_mode_ordering_test() {
  config_mode_ordering.run()
  |> should.be_ok()
  |> should.equal(True)
}
