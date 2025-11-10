//// Convenience helpers for common ETS use cases
////
//// All convenience functions that create tables MUST use the builder internally.

import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option

/// Create a counter table (String keys, Int values)
///
/// This convenience function uses the builder pattern internally.
/// Equivalent to: `ets.new(name) |> ets.counter() |> ets.create()`
pub fn new_counter(
  name: String,
) -> Result(table.Table(String, Int), table.EtsError) {
  config.new(name)
  |> config.counter()
  |> config.create()
}

/// Create a string-to-string table
///
/// This convenience function uses the builder pattern internally.
pub fn new_string_table(
  name: String,
) -> Result(table.Table(String, String), table.EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

/// Atomically increment a counter value
///
/// If the key doesn't exist, it's created with value 1.
/// Returns the new value after incrementing.
pub fn increment(
  table: table.Table(String, Int),
  key: String,
) -> Result(Int, table.EtsError) {
  increment_by(table, key, 1)
}

/// Atomically increment a counter value by a specific amount
///
/// If the key doesn't exist, it's created with the specified amount.
/// Returns the new value after incrementing.
pub fn increment_by(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  case operations.get(table, key) {
    Ok(option.Some(current)) ->
      increment_existing_key(table, key, current, amount)
    Ok(option.None) -> create_new_counter_key(table, key, amount)
    Error(err) -> Error(err)
  }
}

fn increment_existing_key(
  table: table.Table(String, Int),
  key: String,
  current: Int,
  amount: Int,
) -> Result(Int, table.EtsError) {
  let new_value = current + amount
  case operations.set(table, key, new_value) {
    Ok(_) -> Ok(new_value)
    Error(err) -> Error(err)
  }
}

fn create_new_counter_key(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  case operations.set(table, key, amount) {
    Ok(_) -> Ok(amount)
    Error(err) -> Error(err)
  }
}

/// Atomically decrement a counter value
///
/// If the key doesn't exist, it's created with value -1.
/// Returns the new value after decrementing.
pub fn decrement(
  table: table.Table(String, Int),
  key: String,
) -> Result(Int, table.EtsError) {
  decrement_by(table, key, 1)
}

/// Atomically decrement a counter value by a specific amount
///
/// If the key doesn't exist, it's created with the negative of the specified amount.
/// Returns the new value after decrementing.
pub fn decrement_by(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  case operations.get(table, key) {
    Ok(option.Some(current)) ->
      decrement_existing_key(table, key, current, amount)
    Ok(option.None) -> create_new_negative_counter_key(table, key, amount)
    Error(err) -> Error(err)
  }
}

fn decrement_existing_key(
  table: table.Table(String, Int),
  key: String,
  current: Int,
  amount: Int,
) -> Result(Int, table.EtsError) {
  let new_value = current - amount
  case operations.set(table, key, new_value) {
    Ok(_) -> Ok(new_value)
    Error(err) -> Error(err)
  }
}

fn create_new_negative_counter_key(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  let initial_value = 0 - amount
  case operations.set(table, key, initial_value) {
    Ok(_) -> Ok(initial_value)
    Error(err) -> Error(err)
  }
}
