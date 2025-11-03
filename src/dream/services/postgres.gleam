//// PostgreSQL service using singleton pattern
////
//// This module provides a PostgreSQL service that uses the singleton pattern
//// for managing database connections. Uses dependency injection for testability.

import dream/core/singleton
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/result
import pog

/// State type for PostgreSQL singleton
pub type PostgresState {
  PostgresState(connection: pog.Connection)
}

/// Message types for PostgreSQL singleton
pub type PostgresMessage {
  Query(sql: String, params: List(pog.Value))
  Execute(sql: String, params: List(pog.Value))
  GetConnection
}

/// Reply types for PostgreSQL singleton
pub type PostgresReply {
  QueryResult(Result(pog.Returned(dynamic.Dynamic), pog.QueryError))
  ExecuteResult(Result(pog.Returned(dynamic.Dynamic), pog.QueryError))
  ConnectionResult(Result(pog.Connection, String))
}

/// Error type for PostgreSQL operations
pub type PostgresError {
  QueryError(pog.QueryError)
  ConnectionError(String)
  SingletonError(String)
}

/// Start PostgreSQL singleton with an injected connection
/// The connection is provided via dependency injection for testability
pub fn start_with_connection(
  name: process.Name(singleton.SingletonMessage(PostgresMessage, PostgresReply)),
  connection: pog.Connection,
) -> Result(Nil, String) {
  let initial_state = PostgresState(connection: connection)

  singleton.start(name, initial_state, handle_postgres_message)
  |> result.map(fn(_) { Nil })
}

fn handle_postgres_message(
  msg: PostgresMessage,
  state: PostgresState,
) -> #(PostgresState, option.Option(PostgresReply)) {
  case msg {
    Query(sql, params) -> {
      // Build query with parameters
      let query = pog.query(sql)
      let query_with_params =
        list.fold(over: params, from: query, with: fn(acc, param) {
          pog.parameter(acc, param)
        })

      // Execute query with dynamic decoder
      case
        pog.execute(
          pog.returning(query_with_params, decode.dynamic),
          on: state.connection,
        )
      {
        Ok(result) -> #(state, option.Some(QueryResult(Ok(result))))
        Error(e) -> #(state, option.Some(QueryResult(Error(e))))
      }
    }
    Execute(sql, params) -> {
      // Build query with parameters
      let query = pog.query(sql)
      let query_with_params =
        list.fold(over: params, from: query, with: fn(acc, param) {
          pog.parameter(acc, param)
        })

      // Execute query without decoder (for INSERT/UPDATE/DELETE)
      case
        pog.execute(
          pog.returning(query_with_params, decode.dynamic),
          on: state.connection,
        )
      {
        Ok(result) -> #(state, option.Some(ExecuteResult(Ok(result))))
        Error(e) -> #(state, option.Some(ExecuteResult(Error(e))))
      }
    }
    GetConnection -> {
      // Return the connection from state
      #(state, option.Some(ConnectionResult(Ok(state.connection))))
    }
  }
}

/// Query the database (returns rows)
pub fn query(
  name: process.Name(singleton.SingletonMessage(PostgresMessage, PostgresReply)),
  sql: String,
  params: List(pog.Value),
  timeout: Int,
) -> Result(pog.Returned(dynamic.Dynamic), PostgresError) {
  case singleton.call(name, Query(sql: sql, params: params), timeout) {
    Ok(QueryResult(Ok(result))) -> Ok(result)
    Ok(QueryResult(Error(e))) -> Error(QueryError(e))
    Ok(_) -> Error(QueryError(pog.UnexpectedResultType([])))
    Error(e) -> Error(SingletonError(e))
  }
}

/// Execute a statement (INSERT/UPDATE/DELETE)
pub fn execute(
  name: process.Name(singleton.SingletonMessage(PostgresMessage, PostgresReply)),
  sql: String,
  params: List(pog.Value),
  timeout: Int,
) -> Result(pog.Returned(dynamic.Dynamic), PostgresError) {
  case singleton.call(name, Execute(sql: sql, params: params), timeout) {
    Ok(ExecuteResult(Ok(result))) -> Ok(result)
    Ok(ExecuteResult(Error(e))) -> Error(QueryError(e))
    Ok(_) -> Error(QueryError(pog.UnexpectedResultType([])))
    Error(e) -> Error(SingletonError(e))
  }
}

/// Get the connection from the singleton
/// This allows using Squirrel-generated functions directly
pub fn get_connection(
  name: process.Name(singleton.SingletonMessage(PostgresMessage, PostgresReply)),
  timeout: Int,
) -> Result(pog.Connection, PostgresError) {
  case singleton.call(name, GetConnection, timeout) {
    Ok(ConnectionResult(Ok(connection))) -> Ok(connection)
    Ok(ConnectionResult(Error(e))) -> Error(SingletonError(e))
    Ok(_) -> Error(SingletonError("Unexpected reply type"))
    Error(e) -> Error(SingletonError(e))
  }
}
