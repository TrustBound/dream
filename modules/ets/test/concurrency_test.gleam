import dream_ets/config
import dream_ets/operations
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn read_concurrency_enabled_creates_table_test() {
  // Arrange & Act
  let result =
    config.new("test_read_concurrency")
    |> config.key_string()
    |> config.value_string()
    |> config.read_concurrency(True)
    |> config.create()

  // Assert
  result |> should.be_ok()

  case result {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn write_concurrency_enabled_creates_table_test() {
  // Arrange & Act
  let result =
    config.new("test_write_concurrency")
    |> config.key_string()
    |> config.value_string()
    |> config.write_concurrency(True)
    |> config.create()

  // Assert
  result |> should.be_ok()

  case result {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn both_concurrency_options_creates_table_test() {
  // Arrange & Act
  let result =
    config.new("test_both_concurrency")
    |> config.key_string()
    |> config.value_string()
    |> config.read_concurrency(True)
    |> config.write_concurrency(True)
    |> config.create()

  // Assert
  result |> should.be_ok()

  case result {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
