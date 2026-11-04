import gleam/int
import mist/internal/http2/flow_control

pub fn it_should_not_increment_window_above_threshold_test() {
  let min_window_size = int.bitwise_shift_left(1, 30)
  let window_size = min_window_size + 1000

  let #(new_size, increment) =
    flow_control.compute_receive_window(window_size, 500)

  assert new_size == window_size - 500
  assert increment == 0
}

pub fn it_should_increment_window_below_threshold_test() {
  let min_window_size = int.bitwise_shift_left(1, 30)
  let window_size = min_window_size + 100

  let #(new_size, increment) =
    flow_control.compute_receive_window(window_size, 200)

  assert new_size > min_window_size
  assert increment > 0
  assert new_size == window_size - 200 + increment
}

pub fn it_should_update_send_window_test() {
  let assert Ok(result) = flow_control.update_send_window(65_535, 1000)
  assert result == 66_535
}

pub fn it_should_reject_send_window_overflow_test() {
  let max_window = int.bitwise_shift_left(1, 31) - 1
  assert flow_control.update_send_window(max_window, 1)
    == Error("Invalid update increment")
}
