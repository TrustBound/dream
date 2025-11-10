import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import gleam/list
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn table_enforces_string_key_type_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_string_key_type")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  // Act - This compiles because key type is String
  let result = operations.set(table, "string_key", "value")

  // Assert
  result |> should.be_ok()

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn table_enforces_int_value_type_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_int_value_type")
    |> config.key_string()
    |> config.value(encoders.int_encoder, encoders.int_decoder())
    |> config.create()

  // Act - This compiles because value type is Int
  let result = operations.set(table, "key1", 42)

  // Assert
  result |> should.be_ok()

  case result {
    Ok(_) -> {
      case operations.get(table, "key1") {
        Ok(option.Some(value)) -> value |> should.equal(42)
        Ok(option.None) -> should.fail()
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn counter_table_enforces_string_int_types_test() {
  // Arrange
  let assert Ok(counter) =
    config.new("test_counter_types")
    |> config.counter()
    |> config.create()

  // Act - Counter is Table(String, Int)
  let result = operations.set(counter, "count1", 100)

  // Assert
  result |> should.be_ok()

  case operations.get(counter, "count1") {
    Ok(option.Some(value)) -> value |> should.equal(100)
    Ok(option.None) -> should.fail()
    Error(_) -> should.fail()
  }

  case operations.delete_table(counter) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn get_returns_typed_value_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_typed_get")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "typed_value")

  // Act
  let result = operations.get(table, "key1")

  // Assert - Result type is Result(Option(String), _)
  case result {
    Ok(option.Some(value)) -> {
      // value is guaranteed to be String by type system
      value |> should.equal("typed_value")
    }
    Ok(option.None) -> should.fail()
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn keys_returns_typed_key_list_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_typed_keys")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")
  let assert Ok(_) = operations.set(table, "key2", "value2")

  // Act
  let result = operations.keys(table)

  // Assert - result is List(String) by type system
  result
  |> list.length
  |> should.equal(2)

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn values_returns_typed_value_list_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_typed_values")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")
  let assert Ok(_) = operations.set(table, "key2", "value2")

  // Act
  let result = operations.values(table)

  // Assert - result is List(String) by type system
  result
  |> list.length
  |> should.equal(2)

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn to_list_returns_typed_pairs_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_typed_pairs")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")

  // Act
  let result = operations.to_list(table)

  // Assert - result is List(#(String, String)) by type system
  case result {
    [pair, ..] -> {
      let #(key, value) = pair
      key |> should.equal("key1")
      value |> should.equal("value1")
    }
    [] -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}
