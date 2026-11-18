import dream_config/loader
import envoy
import gleam/list
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

// ---------------------------------------------------------------------------
// load_dotenv_from and load_dotenv
// ---------------------------------------------------------------------------

@external(erlang, "loader_test_ffi", "write_file")
fn write_file(path: String, contents: String) -> Result(Nil, Nil)

@external(erlang, "loader_test_ffi", "make_unreadable")
fn make_unreadable(path: String) -> Result(Nil, Nil)

@external(erlang, "loader_test_ffi", "delete_file")
fn delete_file(path: String) -> Result(Nil, Nil)

pub fn load_dotenv_from_with_valid_file_sets_variables_test() {
  // Arrange
  envoy.unset("DREAM_CONFIG_SNIPPET_GREETING")

  // Act
  let result = loader.load_dotenv_from("test/fixtures/myapp.env")
  let greeting = envoy.get("DREAM_CONFIG_SNIPPET_GREETING")
  envoy.unset("DREAM_CONFIG_SNIPPET_GREETING")

  // Assert
  result |> should.equal(Ok(Nil))
  greeting |> should.equal(Ok("hello from myapp.env"))
}

pub fn load_dotenv_from_with_missing_file_returns_error_test() {
  // Act
  let result = loader.load_dotenv_from("test/fixtures/does_not_exist.env")

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at test/fixtures/does_not_exist.env: the file does not exist",
  ))
}

pub fn load_dotenv_from_with_directory_returns_error_test() {
  // Act
  let result = loader.load_dotenv_from("test/fixtures")

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at test/fixtures: illegal operation on a directory",
  ))
}

pub fn load_dotenv_from_with_unreadable_file_returns_error_test() {
  // Arrange
  let path = "build/dream_config_unreadable_test.env"
  write_file(path, "DREAM_CONFIG_TEST_UNREADABLE=1\n") |> should.be_ok()
  make_unreadable(path) |> should.be_ok()

  // Act
  let result = loader.load_dotenv_from(path)
  delete_file(path) |> should.be_ok()

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at build/dream_config_unreadable_test.env: permission denied",
  ))
}

pub fn load_dotenv_from_with_invalid_utf8_returns_error_test() {
  // Act
  let result = loader.load_dotenv_from("test/fixtures/not_utf8.env")

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at test/fixtures/not_utf8.env: the file is not valid UTF-8",
  ))
}

pub fn load_dotenv_from_with_line_without_equals_returns_error_test() {
  // Arrange
  envoy.unset("DREAM_CONFIG_TEST_GOOD_NAME")

  // Act
  let result = loader.load_dotenv_from("test/fixtures/missing_equals.env")
  let good_name = envoy.get("DREAM_CONFIG_TEST_GOOD_NAME")
  envoy.unset("DREAM_CONFIG_TEST_GOOD_NAME")

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at test/fixtures/missing_equals.env: line 2: expected NAME=VALUE",
  ))
  good_name |> should.equal(Error(Nil))
}

pub fn load_dotenv_from_with_unclosed_quote_returns_error_test() {
  // Act
  let result = loader.load_dotenv_from("test/fixtures/unclosed_quote.env")

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at test/fixtures/unclosed_quote.env: line 1: the double quote is not closed",
  ))
}

pub fn load_dotenv_without_default_file_returns_ok_test() {
  // Act
  let result = loader.load_dotenv()

  // Assert
  result |> should.equal(Ok(Nil))
}

pub fn load_dotenv_with_malformed_default_file_returns_error_test() {
  // Arrange
  write_file(".env", "DREAM_CONFIG_TEST_DEFAULT\n") |> should.be_ok()

  // Act
  let result = loader.load_dotenv()
  delete_file(".env") |> should.be_ok()

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at .env: line 1: expected NAME=VALUE",
  ))
}

// ---------------------------------------------------------------------------
// get_bool
// ---------------------------------------------------------------------------

fn get_bool_for(value: String) -> Bool {
  envoy.set("DREAM_CONFIG_TEST_BOOL", value)
  let result = loader.get_bool("DREAM_CONFIG_TEST_BOOL")
  envoy.unset("DREAM_CONFIG_TEST_BOOL")
  result
}

pub fn get_bool_with_true_in_any_case_returns_true_test() {
  // Act
  let results = list.map(["true", "True", "TRUE", "tRUE", "trUe"], get_bool_for)

  // Assert
  results |> should.equal([True, True, True, True, True])
}

pub fn get_bool_with_yes_in_any_case_returns_true_test() {
  // Act
  let results = list.map(["yes", "Yes", "YES", "yEs", "yeS"], get_bool_for)

  // Assert
  results |> should.equal([True, True, True, True, True])
}

pub fn get_bool_with_one_returns_true_test() {
  // Act
  let result = get_bool_for("1")

  // Assert
  result |> should.equal(True)
}

pub fn get_bool_with_other_values_returns_false_test() {
  // Act
  let results =
    list.map(
      ["false", "FALSE", "0", "no", "No", "", "on", " true", "yes ", "2"],
      get_bool_for,
    )

  // Assert
  results
  |> should.equal([
    False,
    False,
    False,
    False,
    False,
    False,
    False,
    False,
    False,
    False,
  ])
}
