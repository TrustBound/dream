//// ETS table operations
////
//// This module provides all operations for working with ETS tables. Every
//// function is type-safe and returns `Result` to force explicit error handling.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_ets/helpers
//// import dream_ets/operations
//// import gleam/option
////
//// // Create table
//// let assert Ok(cache) = helpers.new_string_table("cache")
////
//// // Basic CRUD
//// let assert Ok(_) = operations.set(cache, "user:123", "Alice")
//// let assert Ok(option.Some("Alice")) = operations.get(cache, "user:123")
//// let assert Ok(_) = operations.delete(cache, "user:123")
//// ```
////
//// ## Operation Categories
////
//// ### Basic Operations
////
//// - `set()` - Insert or update a key-value pair
//// - `get()` - Retrieve a value by key
//// - `delete()` - Remove a key-value pair
//// - `member()` - Check if a key exists
////
//// ### Advanced Operations
////
//// - `insert_new()` - Insert only if key doesn't exist
//// - `take()` - Get and remove atomically
//// - `update_element()` - Update tuple elements in-place
////
//// ### Bulk Operations
////
//// - `keys()` - Get all keys
//// - `values()` - Get all values
//// - `to_list()` - Get all key-value pairs
//// - `size()` - Count entries
////
//// ### Table Management
////
//// - `delete_table()` - Remove the entire table
//// - `delete_all_objects()` - Clear all entries
////
//// ### Persistence
////
//// - `save_to_file()` - Save table to disk
//// - `load_from_file()` - Load table from disk
////
//// ### Advanced (Low-level)
////
//// - `match()` - Pattern matching
//// - `match_object()` - Object pattern matching
//// - `select()` - SQL-like queries with match specifications
////
//// ## Error Handling
////
//// All operations return `Result(_, EtsError)`. Common errors:
////
//// - `TableNotFound` - Table was deleted
//// - `DecodeError` - Failed to decode value
//// - `EncodeError` - Failed to encode value
//// - `OperationFailed` - General operation failure
////
//// ## Performance Notes
////
//// - `set()`, `get()`, `delete()` - O(1) constant time
//// - `keys()`, `values()`, `to_list()` - O(n) iterates entire table
//// - `size()` - O(n) counts by iterating (no cached counter)
////
//// ## Concurrency
////
//// All operations are safe for concurrent access. Enable `read_concurrency`
//// and `write_concurrency` in table configuration for better performance
//// under high concurrent load.

import dream_ets/internal
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result

/// Insert or update a key-value pair in the table
///
/// Sets a key-value pair in the table. If the key already exists, the value
/// is updated. If the key doesn't exist, it's created.
///
/// This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to set
/// - `value`: The value to associate with the key
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully set the key-value pair
/// - `Error(EtsError)`: An error occurred (encoding failure, etc.)
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// let assert Ok(_) = ets.set(table, "user:123", "Alice")
/// let assert Ok(_) = ets.set(table, "user:123", "Bob")  // Updates existing
/// ```
pub fn set(
  table: table.Table(k, v),
  key: k,
  value: v,
) -> Result(Nil, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let encoded_value = table.encode_value(table, value)
  let object = #(encoded_key, encoded_value)
  let table_ref = table.table_ref(table)

  internal.insert(table_ref, internal.to_dynamic(object))
  Ok(Nil)
}

/// Lookup a value by key
///
/// Retrieves the value associated with a key. Returns `None` if the key
/// doesn't exist, or `Some(value)` if it does.
///
/// This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to query
/// - `key`: The key to look up
///
/// ## Returns
///
/// - `Ok(Some(value))`: Key exists, returns the value
/// - `Ok(None)`: Key doesn't exist
/// - `Error(EtsError)`: An error occurred (decoding failure, etc.)
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
/// import gleam/option
///
/// case ets.get(table, "user:123") {
///   Ok(option.Some(name)) -> io.println("Found: " <> name)
///   Ok(option.None) -> io.println("User not found")
///   Error(err) -> handle_error(err)
/// }
/// ```
pub fn get(
  table: table.Table(k, v),
  key: k,
) -> Result(option.Option(v), table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  case internal.lookup(table_ref, encoded_key) {
    Ok(dyn_object) -> decode_lookup_result(table, dyn_object)
    Error(internal.NotFound) -> Ok(option.None)
    Error(err) -> map_internal_error(err)
  }
}

/// Delete a key from the table
///
/// Removes a key-value pair from the table. If the key doesn't exist,
/// this is a no-op (no error).
///
/// This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to delete
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully deleted (or key didn't exist)
/// - `Error(EtsError)`: An error occurred
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// let assert Ok(_) = ets.delete(table, "user:123")
/// ```
pub fn delete(table: table.Table(k, v), key: k) -> Result(Nil, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  internal.delete_key(table_ref, encoded_key)
  Ok(Nil)
}

/// Check if a key exists in the table
///
/// Returns `True` if the key exists in the table, `False` otherwise.
/// This is more efficient than `get()` when you only need to check existence
/// without retrieving the value.
///
/// ## Parameters
///
/// - `table`: The table to query
/// - `key`: The key to check
///
/// ## Returns
///
/// - `True`: Key exists in the table
/// - `False`: Key doesn't exist
///
/// ## Example
///
/// ```gleam
/// import dream_ets/operations
///
/// // Check before inserting
/// if !operations.member(table, "user:123") {
///   let assert Ok(_) = operations.set(table, "user:123", "Alice")
/// }
/// ```
///
/// ## Performance
///
/// `member()` is faster than `get()` because it doesn't need to decode
/// the value. Use it when you only care about existence.
///
/// ```gleam
/// // Slower - decodes value
/// case operations.get(table, key) {
///   Ok(option.Some(_)) -> True
///   Ok(option.None) -> False
///   Error(_) -> False
/// }
///
/// // Faster - just checks existence
/// operations.member(table, key)
/// ```
///
/// ## See Also
///
/// - `get()` - Retrieve the value if you need it
/// - `insert_new()` - Insert only if key doesn't exist
pub fn member(table: table.Table(k, v), key: k) -> Bool {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  internal.member(table_ref, encoded_key)
}

/// Delete the entire table
///
/// Permanently deletes the table and all its data. After calling this,
/// the table cannot be used for any operations.
///
/// ## Parameters
///
/// - `table`: The table to delete
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully deleted
/// - `Error(EtsError)`: An error occurred
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// let assert Ok(_) = ets.delete_table(table)
/// ```
pub fn delete_table(table: table.Table(k, v)) -> Result(Nil, table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.delete_table(table_ref)
  Ok(Nil)
}

/// Get the number of objects in the table
///
/// Returns the total number of key-value pairs in the table.
///
/// ## Parameters
///
/// - `table`: The table to count
///
/// ## Returns
///
/// - `Ok(Int)`: The number of entries in the table (>= 0)
/// - `Error(DecodeError)`: A key failed to decode during iteration
///
/// ## Example
///
/// ```gleam
/// import dream_ets/operations
/// import gleam/int
/// import gleam/io
///
/// case operations.size(table) {
///   Ok(count) -> io.println("Table has " <> int.to_string(count) <> " entries")
///   Error(err) -> handle_error(err)
/// }
/// ```
///
/// ## Performance Warning
///
/// **This function is O(n)** - it iterates through all keys to count them.
/// For large tables (>10,000 entries), this can be slow.
///
/// ### Better Alternatives for Large Tables
///
/// If you need frequent size checks on large tables, maintain a counter:
///
/// ```gleam
/// import dream_ets/helpers
/// import dream_ets/operations
///
/// // Separate counter for table size
/// let assert Ok(stats) = helpers.new_counter("cache_stats")
///
/// // Increment on insert
/// let assert Ok(_) = operations.set(cache, key, value)
/// let assert Ok(_) = helpers.increment(stats, "size")
///
/// // Decrement on delete
/// let assert Ok(_) = operations.delete(cache, key)
/// let assert Ok(_) = helpers.decrement(stats, "size")
///
/// // Fast O(1) size lookup
/// let assert Ok(option.Some(size)) = operations.get(stats, "size")
/// ```
///
/// ## See Also
///
/// - `keys()` - If you need the keys anyway
/// - `member()` - Check single key existence (O(1))
pub fn size(table: table.Table(k, v)) -> Result(Int, table.EtsError) {
  // Simple implementation: count the keys
  use all_keys <- result.try(keys(table))
  Ok(list.length(all_keys))
}

/// Get all keys from the table
///
/// Returns a list of all keys in the table. The order is undefined and
/// may vary between calls.
///
/// **Performance Note**: This function iterates the entire table, which
/// can be slow for large tables. Consider using iteration patterns if
/// you don't need all keys at once.
///
/// ## Parameters
///
/// - `table`: The table to get keys from
///
/// ## Returns
///
/// - `Ok(List)`: All keys successfully decoded
/// - `Error(DecodeError)`: A key failed to decode (data corruption or encoder mismatch)
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// case ets.keys(table) {
///   Ok(all_keys) -> list.each(all_keys, fn(key) {
///     io.println("Key: " <> key)
///   })
///   Error(err) -> handle_corruption(err)
/// }
/// ```
pub fn keys(table: table.Table(k, v)) -> Result(List(k), table.EtsError) {
  let table_ref = table.table_ref(table)
  collect_all_keys(table, table_ref)
}

/// Get all values from the table
///
/// Returns a list of all values in the table. The order is undefined and
/// may vary between calls.
///
/// **Performance Note**: This function iterates the entire table, which
/// can be slow for large tables. Consider using iteration patterns if
/// you don't need all values at once.
///
/// ## Parameters
///
/// - `table`: The table to get values from
///
/// ## Returns
///
/// - `Ok(List)`: All values successfully decoded
/// - `Error(DecodeError)`: A value failed to decode (data corruption or encoder mismatch)
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// case ets.values(table) {
///   Ok(all_values) -> list.each(all_values, process_value)
///   Error(err) -> handle_corruption(err)
/// }
/// ```
pub fn values(table: table.Table(k, v)) -> Result(List(v), table.EtsError) {
  let table_ref = table.table_ref(table)
  collect_all_values(table, table_ref)
}

/// Convert table to a list of key-value pairs
///
/// Returns a list of all key-value pairs in the table as tuples.
/// The order is undefined and may vary between calls.
///
/// **Performance Note**: This function iterates the entire table, which
/// can be slow for large tables.
///
/// ## Parameters
///
/// - `table`: The table to convert
///
/// ## Returns
///
/// - `Ok(List)`: All key-value pairs successfully decoded
/// - `Error(DecodeError)`: A key or value failed to decode (data corruption or encoder mismatch)
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// case ets.to_list(table) {
///   Ok(pairs) -> list.each(pairs, fn(#(key, value)) {
///     io.println(key <> " => " <> value)
///   })
///   Error(err) -> handle_corruption(err)
/// }
/// ```
pub fn to_list(
  table: table.Table(k, v),
) -> Result(List(#(k, v)), table.EtsError) {
  let table_ref = table.table_ref(table)
  collect_all_pairs(table, table_ref)
}

/// Insert only if the key doesn't exist
///
/// Atomically inserts a key-value pair only if the key doesn't already exist.
/// This is the atomic equivalent of "check then insert" and is safe for
/// concurrent access without race conditions.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to insert
/// - `value`: The value to associate with the key
///
/// ## Returns
///
/// - `Ok(True)`: Key was inserted successfully (didn't exist before)
/// - `Ok(False)`: Key already existed, no change made
/// - `Error(EtsError)`: An error occurred during encoding or insertion
///
/// ## Example
///
/// ```gleam
/// import dream_ets/operations
///
/// case operations.insert_new(table, "user:123", "Alice") {
///   Ok(True) -> io.println("User created")
///   Ok(False) -> io.println("User already exists")
///   Error(error) -> handle_error(error)
/// }
/// ```
///
/// ## Use Cases
///
/// ### Preventing Duplicate Registrations
///
/// ```gleam
/// fn register_user(users, user_id, name) {
///   case operations.insert_new(users, user_id, name) {
///     Ok(True) -> Ok("User registered")
///     Ok(False) -> Error("User ID already taken")
///     Error(error) -> Error("Database error")
///   }
/// }
/// ```
///
/// ### Distributed Locks
///
/// ```gleam
/// fn acquire_lock(locks, resource_id, owner_id) {
///   case operations.insert_new(locks, resource_id, owner_id) {
///     Ok(True) -> Ok("Lock acquired")
///     Ok(False) -> Error("Resource locked by another process")
///     Error(error) -> Error("Lock system error")
///   }
/// }
/// ```
///
/// ## Why Not Use `member()` + `set()`?
///
/// ```gleam
/// // ❌ RACE CONDITION - Not safe for concurrent access
/// if !operations.member(table, key) {
///   operations.set(table, key, value)  // Another process might insert here!
/// }
///
/// // ✅ ATOMIC - Safe for concurrent access
/// operations.insert_new(table, key, value)
/// ```
///
/// ## See Also
///
/// - `set()` - Insert or update (always succeeds)
/// - `member()` - Check existence only
pub fn insert_new(
  table: table.Table(k, v),
  key: k,
  value: v,
) -> Result(Bool, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let encoded_value = table.encode_value(table, value)
  let object = #(encoded_key, encoded_value)
  let table_ref = table.table_ref(table)

  let inserted = internal.insert_new(table_ref, internal.to_dynamic(object))
  Ok(inserted)
}

/// Lookup and delete a key-value pair atomically
///
/// Retrieves a value and removes it from the table in a single atomic operation.
/// This is safer than separate `get()` + `delete()` calls for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to take and remove
///
/// ## Returns
///
/// - `Ok(Some(value))`: Key existed, returns the value (now removed from table)
/// - `Ok(None)`: Key didn't exist (table unchanged)
/// - `Error(EtsError)`: An error occurred during retrieval or deletion
///
/// ## Example
///
/// ```gleam
/// import dream_ets/operations
/// import gleam/option
///
/// case operations.take(table, "job:123") {
///   Ok(option.Some(job)) -> {
///     process_job(job)
///     // Job is now removed from queue
///   }
///   Ok(option.None) -> io.println("Job not found")
///   Error(error) -> handle_error(error)
/// }
/// ```
///
/// ## Use Cases
///
/// ### Work Queue
///
/// ```gleam
/// import dream_ets/operations
/// import gleam/option
///
/// fn claim_next_job(queue, worker_id) {
///   case operations.take(queue, "next_job") {
///     Ok(option.Some(job)) -> {
///       // Atomically claimed the job
///       process_job(job, worker_id)
///     }
///     Ok(option.None) -> {
///       // No jobs available
///       wait_for_jobs()
///     }
///     Error(error) -> handle_error(error)
///   }
/// }
/// ```
///
/// ### Cache Eviction
///
/// ```gleam
/// fn evict_entry(cache, key) {
///   case operations.take(cache, key) {
///     Ok(option.Some(old_value)) -> {
///       log_eviction(key, old_value)
///       Ok(old_value)
///     }
///     Ok(option.None) -> Error("Key not in cache")
///     Error(error) -> Error("Cache error")
///   }
/// }
/// ```
///
/// ### Token Consumption
///
/// ```gleam
/// fn use_token(tokens, token_id) {
///   case operations.take(tokens, token_id) {
///     Ok(option.Some(token_data)) -> {
///       // Token can only be used once
///       Ok(token_data)
///     }
///     Ok(option.None) -> Error("Invalid or already used token")
///     Error(error) -> Error("Token system error")
///   }
/// }
/// ```
///
/// ## Why Not Use `get()` + `delete()`?
///
/// ```gleam
/// // ❌ RACE CONDITION - Value might change between get and delete
/// case operations.get(table, key) {
///   Ok(option.Some(value)) -> {
///     operations.delete(table, key)  // Another process might have changed it!
///     value
///   }
///   _ -> panic
/// }
///
/// // ✅ ATOMIC - Get and delete in one operation
/// case operations.take(table, key) {
///   Ok(option.Some(value)) -> value
///   _ -> panic
/// }
/// ```
///
/// ## See Also
///
/// - `get()` - Retrieve without deleting
/// - `delete()` - Delete without retrieving
/// - `insert_new()` - Insert only if doesn't exist
pub fn take(
  table: table.Table(k, v),
  key: k,
) -> Result(option.Option(v), table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  case internal.take(table_ref, encoded_key) {
    Ok(dyn_object) -> decode_take_result(table, dyn_object)
    Error(internal.NotFound) -> Ok(option.None)
    Error(err) -> map_internal_error(err)
  }
}

/// Update an element in a tuple at the specified position
pub fn update_element(
  table: table.Table(k, v),
  key: k,
  pos: Int,
  value: dynamic.Dynamic,
) -> Result(Nil, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  case internal.update_element(table_ref, encoded_key, pos, value) {
    Ok(_) -> Ok(Nil)
    Error(internal.NotFound) -> Error(table.TableNotFound)
    Error(internal.InvalidOperation(msg)) -> Error(table.OperationFailed(msg))
    Error(internal.AlreadyExists) -> Error(table.TableAlreadyExists)
    Error(internal.EmptyTable) -> Error(table.EmptyTable)
    Error(internal.EndOfTable) -> Error(table.EndOfTable)
  }
}

/// Delete all objects from the table (keeps the table)
pub fn delete_all_objects(
  table: table.Table(k, v),
) -> Result(Nil, table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.delete_all_objects(table_ref)
  Ok(Nil)
}

/// Pattern matching - advanced ETS feature
///
/// Returns list of matches based on Erlang match pattern.
/// This is a low-level function - most users should use get/keys/values instead.
///
/// See: https://erlang.org/doc/man/ets.html#match-2
pub fn match(
  table: table.Table(k, v),
  pattern: dynamic.Dynamic,
) -> List(dynamic.Dynamic) {
  let table_ref = table.table_ref(table)
  internal.match(table_ref, pattern)
}

/// Match objects - advanced ETS feature
///
/// Returns complete objects matching the pattern.
/// This is a low-level function - most users should use get/to_list instead.
///
/// See: https://erlang.org/doc/man/ets.html#match_object-2
pub fn match_object(
  table: table.Table(k, v),
  pattern: dynamic.Dynamic,
) -> List(dynamic.Dynamic) {
  let table_ref = table.table_ref(table)
  internal.match_object(table_ref, pattern)
}

/// Select with match specification - advanced ETS feature
///
/// SQL-like queries with match specifications.
/// This is a low-level function for complex queries.
///
/// See: https://erlang.org/doc/man/ets.html#select-2
pub fn select(
  table: table.Table(k, v),
  match_spec: dynamic.Dynamic,
) -> List(dynamic.Dynamic) {
  let table_ref = table.table_ref(table)
  internal.select(table_ref, match_spec)
}

/// Save table to file
///
/// Persists the entire table to disk. Useful for caching across restarts.
pub fn save_to_file(
  table: table.Table(k, v),
  filename: String,
) -> Result(Nil, table.EtsError) {
  let table_ref = table.table_ref(table)
  case internal.tab2file(table_ref, filename) {
    Ok(_) -> Ok(Nil)
    Error(err) -> map_ffi_error_to_ets_error(err)
  }
}

/// Load table from file
///
/// Note: This returns a raw table reference without type information.
/// Advanced usage only - prefer creating tables with the builder.
pub fn load_from_file(
  filename: String,
) -> Result(internal.EtsTableRef, table.EtsError) {
  case internal.file2tab(filename) {
    Ok(table_ref) -> Ok(table_ref)
    Error(err) -> map_ffi_error_to_ets_error(err)
  }
}

fn map_ffi_error_to_ets_error(
  err: internal.EtsFfiError,
) -> Result(a, table.EtsError) {
  case err {
    internal.NotFound -> Error(table.TableNotFound)
    internal.AlreadyExists -> Error(table.TableAlreadyExists)
    internal.InvalidOperation(msg) -> Error(table.OperationFailed(msg))
    internal.EmptyTable -> Error(table.EmptyTable)
    internal.EndOfTable -> Error(table.EndOfTable)
  }
}

// Private helper functions

fn decode_lookup_result(
  table: table.Table(k, v),
  dyn_object: dynamic.Dynamic,
) -> Result(option.Option(v), table.EtsError) {
  case extract_value_from_tuple(table, dyn_object) {
    Ok(dyn_value) -> decode_value_to_option(table, dyn_value)
    Error(err) -> Error(err)
  }
}

fn decode_take_result(
  table: table.Table(k, v),
  dyn_object: dynamic.Dynamic,
) -> Result(option.Option(v), table.EtsError) {
  case extract_value_from_tuple(table, dyn_object) {
    Ok(dyn_value) -> decode_value_to_option(table, dyn_value)
    Error(err) -> Error(err)
  }
}

fn extract_value_from_tuple(
  _table: table.Table(k, v),
  dyn_object: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, table.EtsError) {
  // ETS returns tuples as {Key, Value} in Erlang
  // When decoded through Dynamic, we need to extract the second element (index 1)
  // Use decode.at to access tuple elements
  case decode.run(dyn_object, decode.at([1], decode.dynamic)) {
    Ok(dyn_value) -> Ok(dyn_value)
    Error(errors) -> {
      case list.first(errors) {
        Ok(error) -> Error(table.DecodeError(error))
        Error(_) ->
          Error(
            table.DecodeError(
              decode.DecodeError("tuple", "failed to extract value", []),
            ),
          )
      }
    }
  }
}

fn decode_value_to_option(
  table: table.Table(k, v),
  dyn_value: dynamic.Dynamic,
) -> Result(option.Option(v), table.EtsError) {
  case table.decode_value(table, dyn_value) {
    Ok(value) -> Ok(option.Some(value))
    Error(decode_err) -> Error(table.DecodeError(decode_err))
  }
}

fn map_internal_error(
  err: internal.EtsFfiError,
) -> Result(option.Option(v), table.EtsError) {
  case err {
    internal.NotFound -> Ok(option.None)
    internal.AlreadyExists -> Error(table.TableAlreadyExists)
    internal.InvalidOperation(msg) -> Error(table.OperationFailed(msg))
    internal.EmptyTable -> Error(table.EmptyTable)
    internal.EndOfTable -> Error(table.EndOfTable)
  }
}

fn map_internal_error_to_ets(
  err: internal.EtsFfiError,
) -> Result(a, table.EtsError) {
  case err {
    internal.NotFound -> Error(table.TableNotFound)
    internal.AlreadyExists -> Error(table.TableAlreadyExists)
    internal.InvalidOperation(msg) -> Error(table.OperationFailed(msg))
    internal.EmptyTable -> Error(table.EmptyTable)
    internal.EndOfTable -> Error(table.EndOfTable)
  }
}

fn collect_all_keys(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> Result(List(k), table.EtsError) {
  case internal.first_key(table_ref) {
    Ok(first_dyn_key) ->
      collect_keys_from_first(table, table_ref, first_dyn_key)
    Error(internal.EmptyTable) -> Ok([])
    Error(internal.EndOfTable) -> Ok([])
    Error(err) -> map_internal_error_to_ets(err)
  }
}

fn collect_keys_from_first(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
  first_dyn_key: dynamic.Dynamic,
) -> Result(List(k), table.EtsError) {
  case table.decode_key(table, first_dyn_key) {
    Ok(first_key) ->
      collect_remaining_keys(table, table_ref, first_dyn_key, [first_key])
    Error(decode_err) -> Error(table.DecodeError(decode_err))
  }
}

fn collect_remaining_keys(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
  current_dyn_key: dynamic.Dynamic,
  acc: List(k),
) -> Result(List(k), table.EtsError) {
  case internal.next_key(table_ref, current_dyn_key) {
    Ok(next_dyn_key) -> {
      case table.decode_key(table, next_dyn_key) {
        Ok(next_key) ->
          collect_remaining_keys(table, table_ref, next_dyn_key, [
            next_key,
            ..acc
          ])
        Error(decode_err) -> Error(table.DecodeError(decode_err))
      }
    }
    Error(internal.EndOfTable) -> Ok(acc)
    Error(err) -> map_internal_error_to_ets(err)
  }
}

fn collect_all_values(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> Result(List(v), table.EtsError) {
  use keys_list <- result.try(collect_all_keys(table, table_ref))
  collect_values_for_keys(table, keys_list, [])
}

fn collect_values_for_keys(
  table: table.Table(k, v),
  keys: List(k),
  acc: List(v),
) -> Result(List(v), table.EtsError) {
  case keys {
    [] -> Ok(list.reverse(acc))
    [key, ..rest] -> {
      use value <- result.try(get(table, key))
      case value {
        option.Some(v) -> collect_values_for_keys(table, rest, [v, ..acc])
        option.None ->
          Error(table.OperationFailed(
            "Key disappeared during iteration (concurrent delete?)",
          ))
      }
    }
  }
}

fn collect_all_pairs(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> Result(List(#(k, v)), table.EtsError) {
  use keys_list <- result.try(collect_all_keys(table, table_ref))
  collect_pairs_for_keys(table, keys_list, [])
}

fn collect_pairs_for_keys(
  table: table.Table(k, v),
  keys: List(k),
  acc: List(#(k, v)),
) -> Result(List(#(k, v)), table.EtsError) {
  case keys {
    [] -> Ok(list.reverse(acc))
    [key, ..rest] -> {
      use value <- result.try(get(table, key))
      case value {
        option.Some(v) ->
          collect_pairs_for_keys(table, rest, [#(key, v), ..acc])
        option.None ->
          Error(table.OperationFailed(
            "Key disappeared during iteration (concurrent delete?)",
          ))
      }
    }
  }
}
