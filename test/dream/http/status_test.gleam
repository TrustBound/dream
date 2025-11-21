import dream/http/status
import gleeunit/should

pub fn ok_has_correct_value_test() {
  // Arrange & Act & Assert
  status.ok |> should.equal(200)
}

pub fn created_has_correct_value_test() {
  // Arrange & Act & Assert
  status.created |> should.equal(201)
}

pub fn bad_request_has_correct_value_test() {
  // Arrange & Act & Assert
  status.bad_request |> should.equal(400)
}

pub fn not_found_has_correct_value_test() {
  // Arrange & Act & Assert
  status.not_found |> should.equal(404)
}

pub fn conflict_has_correct_value_test() {
  // Arrange & Act & Assert
  status.conflict |> should.equal(409)
}

pub fn internal_server_error_has_correct_value_test() {
  // Arrange & Act & Assert
  status.internal_server_error |> should.equal(500)
}
