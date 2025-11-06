import dream/core/singleton
import gleam/erlang/process
import gleam/option
import gleeunit/should

// Test state type
type CounterState {
  CounterState(count: Int)
}

// Test message types
type CounterMessage {
  Increment
  Decrement
  GetCount
  SetCount(Int)
}

type CounterReply {
  Count(Int)
  Acknowledged
}

fn handle_counter_message(
  msg: CounterMessage,
  state: CounterState,
) -> #(CounterState, option.Option(CounterReply)) {
  case msg {
    Increment -> {
      let new_state = CounterState(count: state.count + 1)
      #(new_state, option.Some(Acknowledged))
    }
    Decrement -> {
      let new_state = CounterState(count: state.count - 1)
      #(new_state, option.Some(Acknowledged))
    }
    GetCount -> {
      #(state, option.Some(Count(state.count)))
    }
    SetCount(n) -> {
      let new_state = CounterState(count: n)
      #(new_state, option.Some(Acknowledged))
    }
  }
}

pub fn start_registers_process_with_name_test() {
  let name = process.new_name("test_counter_1")
  let initial_state = CounterState(count: 0)

  case singleton.start(name, initial_state, handle_counter_message) {
    Ok(_pid) -> {
      singleton.is_running(name) |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn start_returns_error_if_already_started_test() {
  let name = process.new_name("test_counter_2")
  let initial_state = CounterState(count: 0)

  case singleton.start(name, initial_state, handle_counter_message) {
    Ok(_pid) -> {
      case singleton.start(name, initial_state, handle_counter_message) {
        Ok(_) -> should.fail()
        Error(_) -> Nil
        // Expected
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn call_synchronously_returns_reply_test() {
  let name = process.new_name("test_counter_3")
  let initial_state = CounterState(count: 5)

  case singleton.start(name, initial_state, handle_counter_message) {
    Ok(_pid) -> {
      case singleton.call(name, GetCount, 1000) {
        Ok(Count(n)) -> n |> should.equal(5)
        Ok(_) -> should.fail()
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn call_returns_error_if_not_started_test() {
  let name = process.new_name("test_counter_not_started")

  case singleton.call(name, GetCount, 1000) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
    // Expected
  }
}

pub fn cast_asynchronously_updates_state_test() {
  let name = process.new_name("test_counter_4")
  let initial_state = CounterState(count: 0)

  case singleton.start(name, initial_state, handle_counter_message) {
    Ok(_pid) -> {
      // Cast increment
      case singleton.cast(name, Increment) {
        Ok(_) -> {
          // Wait a bit for async processing
          process.sleep(10)
          // Verify state changed
          case singleton.call(name, GetCount, 1000) {
            Ok(Count(n)) -> n |> should.equal(1)
            Ok(_) -> should.fail()
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn cast_returns_error_if_not_started_test() {
  let name = process.new_name("test_counter_not_started_cast")

  case singleton.cast(name, Increment) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
    // Expected
  }
}

pub fn state_persists_across_multiple_messages_test() {
  let name = process.new_name("test_counter_5")
  let initial_state = CounterState(count: 0)

  case singleton.start(name, initial_state, handle_counter_message) {
    Ok(_pid) -> {
      // Increment multiple times
      case singleton.call(name, Increment, 1000) {
        Ok(_) -> {
          case singleton.call(name, Increment, 1000) {
            Ok(_) -> {
              case singleton.call(name, Increment, 1000) {
                Ok(_) -> {
                  // Verify final count
                  case singleton.call(name, GetCount, 1000) {
                    Ok(Count(n)) -> n |> should.equal(3)
                    Ok(_) -> should.fail()
                    Error(_) -> should.fail()
                  }
                }
                Error(_) -> should.fail()
              }
            }
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn multiple_processes_communicate_with_same_singleton_test() {
  let name = process.new_name("test_counter_multi")
  let initial_state = CounterState(count: 0)

  case singleton.start(name, initial_state, handle_counter_message) {
    Ok(_pid) -> {
      // Spawn multiple processes, each calling the singleton
      let process1 =
        process.spawn(fn() {
          case singleton.call(name, Increment, 1000) {
            Ok(_) -> Nil
            Error(_) -> Nil
          }
        })

      let process2 =
        process.spawn(fn() {
          case singleton.call(name, Increment, 1000) {
            Ok(_) -> Nil
            Error(_) -> Nil
          }
        })

      let process3 =
        process.spawn(fn() {
          case singleton.call(name, Increment, 1000) {
            Ok(_) -> Nil
            Error(_) -> Nil
          }
        })

      // Verify all processes are different
      should.be_true(process1 != process2)
      should.be_true(process2 != process3)
      should.be_true(process1 != process3)

      // Wait for all processes to complete
      process.sleep(100)

      // Verify final state reflects all increments
      case singleton.call(name, GetCount, 1000) {
        Ok(Count(n)) -> n |> should.equal(3)
        Ok(_) -> should.fail()
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn call_times_out_after_specified_time_test() {
  let name = process.new_name("test_counter_timeout")
  let initial_state = CounterState(count: 0)

  // Create a handler that doesn't reply
  let no_reply_handler = fn(_msg: CounterMessage, state: CounterState) -> #(
    CounterState,
    option.Option(CounterReply),
  ) {
    #(state, option.None)
    // No reply
  }

  case singleton.start(name, initial_state, no_reply_handler) {
    Ok(_pid) -> {
      case singleton.call(name, GetCount, 10) {
        // Very short timeout
        Ok(_) -> should.fail()
        Error(_) -> Nil
        // Expected timeout
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn is_running_returns_false_when_not_started_test() {
  let name = process.new_name("test_counter_not_running")

  singleton.is_running(name) |> should.be_false()
}

pub fn is_running_returns_true_when_started_test() {
  let name = process.new_name("test_counter_running")
  let initial_state = CounterState(count: 0)

  case singleton.start(name, initial_state, handle_counter_message) {
    Ok(_pid) -> {
      singleton.is_running(name) |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}
