//// Custom matcher to extract table name from a Table.

import dream_ets/table
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract the table name from a Table for further assertions.
pub fn extract_table_name(
  result: MatchResult(Result(table.Table(k, v), table.EtsError)),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(Ok(tab)) -> MatchOk(table.table_name(tab))
    MatchOk(Error(error)) -> table_creation_failed(error)
  }
}

fn table_creation_failed(_error: table.EtsError) -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_table_name",
    message: "Expected Ok result but got Error",
    payload: Some(CustomMatcherFailure(
      actual: "Error(...)",
      description: "Table creation failed",
    )),
  ))
}
