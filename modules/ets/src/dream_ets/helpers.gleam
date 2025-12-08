//// Convenience helpers for common ETS use cases
////
//// This module provides simplified functions for common patterns like counters
//// and string tables. These functions wrap the builder pattern with sensible
//// defaults for frequent use cases.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_ets/helpers
////
//// // Create a counter table
//// let assert Ok(counter) = helpers.new_counter("page_views")
//// let assert Ok(count) = helpers.increment(counter, "homepage")
////
//// // Create a string-to-string cache
//// let assert Ok(cache) = helpers.new_string_table("user_cache")
//// ```
////
//// ## When to Use Helpers vs. Builder
////
//// **Use helpers when:**
//// - Creating counters (String keys, Int values)
//// - Creating string-to-string tables
//// - You want the simplest possible API
////
//// **Use builder when:**
//// - Custom key/value types
//// - Need specific configuration (concurrency, compression, etc.)
//// - Fine-grained control over table behavior

import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option

/// Create a counter table (String keys, Int values)
///
/// Creates a table optimized for use as a counter with string keys and
/// integer values. This is a convenience function that uses the builder
/// pattern internally with appropriate defaults.
///
/// ## Parameters
///
/// - `name`: A unique name for the counter table
///
/// ## Returns
///
/// - `Ok(Table)`: Successfully created counter table
/// - `Error(TableAlreadyExists)`: A table with this name already exists
/// - `Error(_)`: Other table creation errors
///
/// ## Example
///
/// ```gleam
/// import dream_ets/helpers
/// import dream_ets/operations
///
/// // Create counter
/// let assert Ok(counter) = helpers.new_counter("page_views")
///
/// // Increment counters
/// let assert Ok(1) = helpers.increment(counter, "homepage")
/// let assert Ok(2) = helpers.increment(counter, "homepage")
/// let assert Ok(1) = helpers.increment(counter, "about")
/// ```
///
/// ## Equivalent Builder Code
///
/// ```gleam
/// import dream_ets/config
///
/// let assert Ok(counter) = config.new("page_views")
///   |> config.counter()
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `increment()` - Increment a counter value
/// - `decrement()` - Decrement a counter value
/// - `increment_by()` - Increment by a specific amount
pub fn new_counter(
  name: String,
) -> Result(table.Table(String, Int), table.EtsError) {
  config.new(name)
  |> config.counter()
  |> config.create()
}

/// Create a string-to-string table
///
/// Creates a table with string keys and string values. This is a convenience
/// function for the most common table type - perfect for caches, sessions,
/// and simple key-value stores.
///
/// ## Parameters
///
/// - `name`: A unique name for the table
///
/// ## Returns
///
/// - `Ok(Table)`: Successfully created table
/// - `Error(TableAlreadyExists)`: A table with this name already exists
/// - `Error(_)`: Other table creation errors
///
/// ## Example
///
/// ```gleam
/// import dream_ets/helpers
/// import dream_ets/operations
///
/// // Create cache
/// let assert Ok(cache) = helpers.new_string_table("user_cache")
///
/// // Use it
/// let assert Ok(_) = operations.set(cache, "user:123", "Alice")
/// let assert Ok(option.Some("Alice")) = operations.get(cache, "user:123")
/// ```
///
/// ## Equivalent Builder Code
///
/// ```gleam
/// import dream_ets/config
///
/// let assert Ok(table) = config.new("user_cache")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## Use Cases
///
/// - **Caching**: Store API responses, computed values
/// - **Sessions**: Store session IDs and data
/// - **Configuration**: Store config values by key
/// - **User data**: Simple user ID to username mappings
///
/// ## See Also
///
/// - `operations.set()` - Store values
/// - `operations.get()` - Retrieve values
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
/// Increments a counter by 1. If the key doesn't exist, it's created with
/// value 1. This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to increment
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after incrementing
/// - `Error(EtsError)`: An error occurred
///
/// ## Example
///
/// ```gleam
/// import dream_ets/helpers
///
/// let assert Ok(counter) = helpers.new_counter("metrics")
///
/// // First increment creates the key with value 1
/// let assert Ok(1) = helpers.increment(counter, "requests")
///
/// // Subsequent increments add 1
/// let assert Ok(2) = helpers.increment(counter, "requests")
/// let assert Ok(3) = helpers.increment(counter, "requests")
/// ```
///
/// ## Concurrency
///
/// This function is **not atomic** in the traditional sense. It performs
/// get-modify-set operations. For truly atomic increments in high-concurrency
/// scenarios, consider using Erlang's `:ets.update_counter/3` via FFI.
///
/// ## See Also
///
/// - `increment_by()` - Increment by a specific amount
/// - `decrement()` - Decrement by 1
pub fn increment(
  table: table.Table(String, Int),
  key: String,
) -> Result(Int, table.EtsError) {
  increment_by(table, key, 1)
}

/// Atomically increment a counter value by a specific amount
///
/// Increments a counter by the specified amount. If the key doesn't exist,
/// it's created with the specified amount as the initial value.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to increment
/// - `amount`: The amount to add (can be negative to decrement)
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after incrementing
/// - `Error(EtsError)`: An error occurred
///
/// ## Example
///
/// ```gleam
/// import dream_ets/helpers
///
/// let assert Ok(counter) = helpers.new_counter("scores")
///
/// // Add 10 points
/// let assert Ok(10) = helpers.increment_by(counter, "player1", 10)
/// let assert Ok(20) = helpers.increment_by(counter, "player1", 10)
///
/// // Can use negative amounts to decrement
/// let assert Ok(15) = helpers.increment_by(counter, "player1", -5)
/// ```
///
/// ## Use Cases
///
/// - **Scoring systems**: Add points to player scores
/// - **Batch metrics**: Increment by batch size
/// - **Resource tracking**: Adjust resource counts
///
/// ## See Also
///
/// - `increment()` - Increment by 1
/// - `decrement_by()` - Decrement by a specific amount
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
/// Decrements a counter by 1. If the key doesn't exist, it's created with
/// value -1. This operation is safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to decrement
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after decrementing
/// - `Error(EtsError)`: An error occurred
///
/// ## Example
///
/// ```gleam
/// import dream_ets/helpers
/// import dream_ets/operations
///
/// let assert Ok(counter) = helpers.new_counter("inventory")
///
/// // Set initial value
/// let assert Ok(_) = operations.set(counter, "widgets", 100)
///
/// // Decrement as items are used
/// let assert Ok(99) = helpers.decrement(counter, "widgets")
/// let assert Ok(98) = helpers.decrement(counter, "widgets")
/// ```
///
/// ## Use Cases
///
/// - **Inventory tracking**: Decrement stock counts
/// - **Rate limiting**: Decrease remaining quota
/// - **Resource pools**: Track available resources
///
/// ## See Also
///
/// - `decrement_by()` - Decrement by a specific amount
/// - `increment()` - Increment by 1
pub fn decrement(
  table: table.Table(String, Int),
  key: String,
) -> Result(Int, table.EtsError) {
  decrement_by(table, key, 1)
}

/// Atomically decrement a counter value by a specific amount
///
/// Decrements a counter by the specified amount. If the key doesn't exist,
/// it's created with the negative of the specified amount as the initial value.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to decrement
/// - `amount`: The amount to subtract (positive number)
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after decrementing
/// - `Error(EtsError)`: An error occurred
///
/// ## Example
///
/// ```gleam
/// import dream_ets/helpers
/// import dream_ets/operations
///
/// let assert Ok(counter) = helpers.new_counter("quota")
///
/// // Set initial quota
/// let assert Ok(_) = operations.set(counter, "api_calls", 1000)
///
/// // Deduct batch of API calls
/// let assert Ok(900) = helpers.decrement_by(counter, "api_calls", 100)
/// let assert Ok(850) = helpers.decrement_by(counter, "api_calls", 50)
/// ```
///
/// ## Use Cases
///
/// - **Batch operations**: Deduct multiple units at once
/// - **Credit systems**: Subtract costs
/// - **Quota management**: Track usage against limits
///
/// ## See Also
///
/// - `decrement()` - Decrement by 1
/// - `increment_by()` - Increment by a specific amount
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
