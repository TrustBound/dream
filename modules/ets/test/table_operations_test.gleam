import dream_ets/config
import dream_ets/operations
import gleam/list
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// AAA Pattern: Arrange, Act, Assert with blank lines

pub fn set_with_valid_key_value_stores_value_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_set_valid")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  // Act
  let result = operations.set(table, "key1", "value1")

  // Assert
  result |> should.be_ok()
  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn set_with_existing_key_updates_value_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_set_update")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "original")

  // Act
  let assert Ok(_) = operations.set(table, "key1", "updated")
  let result = operations.get(table, "key1")

  // Assert
  case result {
    Ok(option.Some(value)) -> value |> should.equal("updated")
    Ok(option.None) -> should.fail()
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn get_with_existing_key_returns_value_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_get_existing")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")

  // Act
  let result = operations.get(table, "key1")

  // Assert
  case result {
    Ok(option.Some(value)) -> value |> should.equal("value1")
    Ok(option.None) -> should.fail()
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn get_with_non_existent_key_returns_none_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_get_nonexistent")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  // Act
  let result = operations.get(table, "nonexistent_key")

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

pub fn delete_with_existing_key_removes_key_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_delete_existing")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")

  // Act
  let assert Ok(_) = operations.delete(table, "key1")
  let result = operations.get(table, "key1")

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

pub fn member_with_existing_key_returns_true_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_member_exists")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")

  // Act
  let result = operations.member(table, "key1")

  // Assert
  result |> should.be_true()

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn member_with_non_existent_key_returns_false_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_member_nonexistent")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  // Act
  let result = operations.member(table, "nonexistent_key")

  // Assert
  result |> should.be_false()

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn keys_returns_all_keys_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_keys")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")
  let assert Ok(_) = operations.set(table, "key2", "value2")
  let assert Ok(_) = operations.set(table, "key3", "value3")

  // Act
  let result = operations.keys(table)

  // Assert - ETS doesn't guarantee order, so sort first
  result |> list.sort(string.compare) |> should.equal(["key1", "key2", "key3"])

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn values_returns_all_values_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_values")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")
  let assert Ok(_) = operations.set(table, "key2", "value2")

  // Act
  let result = operations.values(table)

  // Assert - ETS doesn't guarantee order, so sort first
  result |> list.sort(string.compare) |> should.equal(["value1", "value2"])

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn to_list_returns_all_pairs_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_to_list")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")
  let assert Ok(_) = operations.set(table, "key2", "value2")

  // Act
  let result = operations.to_list(table)

  // Assert - ETS doesn't guarantee order, so sort first
  let sorted = list.sort(result, fn(a, b) { string.compare(a.0, b.0) })
  sorted |> should.equal([#("key1", "value1"), #("key2", "value2")])

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn size_returns_number_of_objects_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_size")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")
  let assert Ok(_) = operations.set(table, "key2", "value2")
  let assert Ok(_) = operations.set(table, "key3", "value3")

  // Act
  let result = operations.size(table)

  // Assert
  result |> should.equal(3)

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn insert_new_with_non_existent_key_inserts_and_returns_true_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_insert_new_success")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  // Act
  let result = operations.insert_new(table, "key1", "value1")

  // Assert
  case result {
    Ok(inserted) -> inserted |> should.be_true()
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn insert_new_with_existing_key_returns_false_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_insert_new_fail")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "original")

  // Act
  let result = operations.insert_new(table, "key1", "new_value")

  // Assert
  case result {
    Ok(inserted) -> inserted |> should.be_false()
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn take_with_existing_key_returns_value_and_deletes_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_take_existing")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")

  // Act
  let result = operations.take(table, "key1")

  // Assert
  case result {
    Ok(option.Some(value)) -> value |> should.equal("value1")
    Ok(option.None) -> should.fail()
    Error(_) -> should.fail()
  }

  // Verify key was deleted
  case operations.get(table, "key1") {
    Ok(option.None) -> Nil
    Ok(option.Some(_)) -> should.fail()
    Error(_) -> should.fail()
  }

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn delete_all_objects_clears_table_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_delete_all")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")
  let assert Ok(_) = operations.set(table, "key2", "value2")
  let assert Ok(_) = operations.set(table, "key3", "value3")

  // Act
  let result = operations.delete_all_objects(table)

  // Assert
  result |> should.be_ok()
  operations.size(table) |> should.equal(0)

  case operations.delete_table(table) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn delete_table_removes_entire_table_test() {
  // Arrange
  let assert Ok(table) =
    config.new("test_delete_table")
    |> config.key_string()
    |> config.value_string()
    |> config.create()

  let assert Ok(_) = operations.set(table, "key1", "value1")

  // Act
  let result = operations.delete_table(table)

  // Assert
  result |> should.be_ok()
}
