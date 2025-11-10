import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn new_creates_config_with_defaults_test() {
  // Arrange & Act
  let config = config.new("test_table")

  // Assert - verify defaults by creating table
  let result =
    config
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  case result {
    Ok(table) -> {
      table.table_name(table) |> should.equal("test_table")
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn table_type_set_changes_table_type_test() {
  // Arrange - use helper functions
  let set_config =
    config.new("test_set_type")
    |> config.key_string()
    |> config.value_string()
    |> config.table_type(config.table_type_set())

  let ordered_config =
    config.new("test_ordered_type")
    |> config.key_string()
    |> config.value_string()
    |> config.table_type(config.table_type_ordered_set())

  // Assert - both should create successfully
  case config.create(set_config) {
    Ok(set_table) -> {
      case config.create(ordered_config) {
        Ok(ordered_table) -> {
          case operations.delete_table(set_table) {
            Ok(_) -> {
              case operations.delete_table(ordered_table) {
                Ok(_) -> Nil
                Error(_) -> should.fail()
              }
            }
            Error(_) -> should.fail()
          }
        }
        Error(_) -> {
          case operations.delete_table(set_table) {
            Ok(_) -> should.fail()
            Error(_) -> should.fail()
          }
        }
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn access_protected_sets_access_mode_test() {
  // Arrange
  let base_config =
    config.new("test_protected")
    |> config.key_string()
    |> config.value_string()

  // Act
  let protected_config = config.access(base_config, config.access_protected())

  // Assert
  case config.create(protected_config) {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn read_concurrency_enables_read_concurrency_test() {
  // Arrange
  let base_config =
    config.new("test_read_concurrency")
    |> config.key_string()
    |> config.value_string()

  // Act
  let concurrency_config = config.read_concurrency(base_config, True)

  // Assert
  case config.create(concurrency_config) {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn write_concurrency_enables_write_concurrency_test() {
  // Arrange
  let base_config =
    config.new("test_write_concurrency")
    |> config.key_string()
    |> config.value_string()

  // Act
  let concurrency_config = config.write_concurrency(base_config, True)

  // Assert
  case config.create(concurrency_config) {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn compressed_enables_compression_test() {
  // Arrange
  let base_config =
    config.new("test_compressed")
    |> config.key_string()
    |> config.value_string()

  // Act
  let compressed_config = config.compressed(base_config, True)

  // Assert
  case config.create(compressed_config) {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn key_string_sets_string_key_encoding_test() {
  // Arrange
  let base_config =
    config.new("test_key_string")
    |> config.value_string()

  // Act
  let string_key_config = config.key_string(base_config)

  // Assert
  case config.create(string_key_config) {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn value_string_sets_string_value_encoding_test() {
  // Arrange
  let base_config =
    config.new("test_value_string")
    |> config.key_string()

  // Act
  let string_value_config = config.value_string(base_config)

  // Assert
  case config.create(string_value_config) {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn counter_configures_counter_table_test() {
  // Arrange
  let base_config = config.new("test_counter")

  // Act
  let counter_config = config.counter(base_config)

  // Assert
  case config.create(counter_config) {
    Ok(table) -> {
      case operations.delete_table(table) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn create_requires_key_and_value_encoders_test() {
  // Arrange - config without encoders
  let incomplete_config = config.new("test_incomplete")

  // Act & Assert
  case config.create(incomplete_config) {
    Ok(_) -> should.fail()
    Error(table.InvalidKey) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn create_returns_error_for_duplicate_table_name_test() {
  // Arrange
  let config1 =
    config.new("duplicate_test")
    |> config.key_string()
    |> config.value_string()

  let config2 =
    config.new("duplicate_test")
    |> config.key_string()
    |> config.value_string()

  // Act
  case config.create(config1) {
    Ok(table1) -> {
      // Try to create second table with same name
      case config.create(config2) {
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
    Error(_) -> should.fail()
  }
}
