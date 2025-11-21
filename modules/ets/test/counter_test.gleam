import dream_ets/helpers
import dream_ets/operations
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn new_counter_creates_counter_table_test() {
  // Arrange & Act
  let result = helpers.new_counter("test_counter_create")

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

pub fn increment_with_new_key_initializes_to_one_test() {
  // Arrange
  let assert Ok(counter) = helpers.new_counter("test_increment_new")

  // Act
  let result = helpers.increment(counter, "new_key")

  // Assert
  case result {
    Ok(count) -> count |> should.equal(1)
    Error(_) -> should.fail()
  }

  case operations.delete_table(counter) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn increment_with_existing_key_increments_value_test() {
  // Arrange
  let assert Ok(counter) = helpers.new_counter("test_increment_existing")
  let assert Ok(_) = operations.set(counter, "key1", 5)

  // Act
  let result = helpers.increment(counter, "key1")

  // Assert
  case result {
    Ok(count) -> count |> should.equal(6)
    Error(_) -> should.fail()
  }

  case operations.delete_table(counter) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn increment_by_adds_amount_to_existing_value_test() {
  // Arrange
  let assert Ok(counter) = helpers.new_counter("test_increment_by")
  let assert Ok(_) = operations.set(counter, "key1", 10)

  // Act
  let result = helpers.increment_by(counter, "key1", 5)

  // Assert
  case result {
    Ok(count) -> count |> should.equal(15)
    Error(_) -> should.fail()
  }

  case operations.delete_table(counter) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn decrement_with_existing_key_decrements_value_test() {
  // Arrange
  let assert Ok(counter) = helpers.new_counter("test_decrement_existing")
  let assert Ok(_) = operations.set(counter, "key1", 10)

  // Act
  let result = helpers.decrement(counter, "key1")

  // Assert
  case result {
    Ok(count) -> count |> should.equal(9)
    Error(_) -> should.fail()
  }

  case operations.delete_table(counter) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn decrement_by_subtracts_amount_from_existing_value_test() {
  // Arrange
  let assert Ok(counter) = helpers.new_counter("test_decrement_by")
  let assert Ok(_) = operations.set(counter, "key1", 20)

  // Act
  let result = helpers.decrement_by(counter, "key1", 7)

  // Assert
  case result {
    Ok(count) -> count |> should.equal(13)
    Error(_) -> should.fail()
  }

  case operations.delete_table(counter) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}
