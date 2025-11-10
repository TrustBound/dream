import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn create_with_missing_key_encoder_returns_invalid_key_error_test() {
  // Arrange
  let incomplete_config = config.new("test_missing_key_encoder")

  // Act
  let result = config.create(incomplete_config)

  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(table.InvalidKey) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn create_with_missing_value_encoder_returns_invalid_value_error_test() {
  // Arrange
  let incomplete_config =
    config.new("test_missing_value_encoder")
    |> config.key_string()

  // Act
  let result = config.create(incomplete_config)

  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(table.InvalidValue) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn create_with_duplicate_name_returns_already_exists_error_test() {
  // Arrange
  let assert Ok(table1) =
    config.new("test_duplicate_name")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let config2 =
    config.new("test_duplicate_name")
    |> config.key_string()
    |> config.value_string()

  // Act
  let result = config.create(config2)

  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(table.TableAlreadyExists) -> {
      case operations.delete_table(table1) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn get_from_empty_table_returns_none_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_get_empty")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  // Act
  let result = operations.get(table, "nonexistent")

  // Assert
  case result {
    Ok(option.None) -> Nil
    Ok(option.Some(_)) -> should.fail()
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn delete_nonexistent_key_succeeds_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_delete_nonexistent")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  // Act
  let result = operations.delete(table, "nonexistent")

  // Assert
  result |> should.be_ok()

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}
