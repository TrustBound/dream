import dream_postgres/query
import gleeunit
import gleeunit/should
import pog

pub fn main() {
  gleeunit.main()
}

pub fn first_row_with_single_row_returns_row_test() {
  // Arrange
  let returned = pog.Returned(count: 1, rows: [42])
  
  // Act
  let result = query.first_row(Ok(returned))
  
  // Assert
  case result {
    Ok(value) -> value |> should.equal(42)
    Error(_) -> should.fail()
  }
}

pub fn first_row_with_no_rows_returns_not_found_test() {
  // Arrange
  let returned = pog.Returned(count: 0, rows: [])
  
  // Act
  let result = query.first_row(Ok(returned))
  
  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(query.NotFound) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn first_row_with_query_error_returns_database_error_test() {
  // Arrange
  let query_error = Error(pog.ConnectionUnavailable)
  
  // Act
  let result = query.first_row(query_error)
  
  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(query.DatabaseError) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn all_rows_with_multiple_rows_returns_list_test() {
  // Arrange
  let returned = pog.Returned(count: 3, rows: [1, 2, 3])
  
  // Act
  let result = query.all_rows(Ok(returned))
  
  // Assert
  case result {
    Ok(rows) -> rows |> should.equal([1, 2, 3])
    Error(_) -> should.fail()
  }
}

pub fn all_rows_with_empty_returns_empty_list_test() {
  // Arrange
  let returned = pog.Returned(count: 0, rows: [])
  
  // Act
  let result = query.all_rows(Ok(returned))
  
  // Assert
  case result {
    Ok(rows) -> rows |> should.equal([])
    Error(_) -> should.fail()
  }
}

