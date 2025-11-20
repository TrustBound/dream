import dream_config/loader
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn get_with_non_existing_var_returns_error_test() {
  // Arrange
  let var_name = "NONEXISTENT_VAR_THAT_SHOULD_NOT_EXIST_12345"

  // Act
  let result = loader.get(var_name)

  // Assert
  result |> should.be_error()
}

pub fn get_bool_with_non_existing_var_returns_false_test() {
  // Arrange
  let var_name = "NONEXISTENT_BOOL_VAR_12345"

  // Act
  let result = loader.get_bool(var_name)

  // Assert
  result |> should.equal(False)
}

pub fn get_int_with_non_existing_var_returns_error_test() {
  // Arrange
  let var_name = "NONEXISTENT_INT_VAR_12345"

  // Act
  let result = loader.get_int(var_name)

  // Assert
  result |> should.be_error()
}
