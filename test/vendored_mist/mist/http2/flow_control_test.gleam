import mist/internal/http2/flow_control

pub fn it_should_send_up_to_the_smaller_window_test() {
  assert flow_control.compute_send_size(100, 50, 200) == 50
}

pub fn it_should_send_nothing_with_a_negative_window_test() {
  assert flow_control.compute_send_size(-1000, 65_535, 0) == 0
}
