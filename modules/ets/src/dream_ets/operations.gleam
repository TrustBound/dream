import dream_ets/internal
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/option

/// Insert or update a key-value pair in the table
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
pub fn delete(table: table.Table(k, v), key: k) -> Result(Nil, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  internal.delete_key(table_ref, encoded_key)
  Ok(Nil)
}

/// Check if a key exists in the table
pub fn member(table: table.Table(k, v), key: k) -> Bool {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  internal.member(table_ref, encoded_key)
}

/// Delete the entire table
pub fn delete_table(table: table.Table(k, v)) -> Result(Nil, table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.delete_table(table_ref)
  Ok(Nil)
}

/// Get the number of objects in the table
///
/// Note: This counts by iterating keys. For large tables, this may be slow.
pub fn size(table: table.Table(k, v)) -> Int {
  // Simple implementation: count the keys
  keys(table) |> list.length
}

/// Get all keys from the table
pub fn keys(table: table.Table(k, v)) -> List(k) {
  let table_ref = table.table_ref(table)
  collect_all_keys(table, table_ref)
}

/// Get all values from the table
pub fn values(table: table.Table(k, v)) -> List(v) {
  let table_ref = table.table_ref(table)
  collect_all_values(table, table_ref)
}

/// Convert table to a list of key-value pairs
pub fn to_list(table: table.Table(k, v)) -> List(#(k, v)) {
  let table_ref = table.table_ref(table)
  collect_all_pairs(table, table_ref)
}

/// Insert only if the key doesn't exist
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

/// Lookup and delete a key-value pair
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
    Error(_) -> Error(table.OperationFailed("Unknown error"))
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

fn collect_all_keys(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> List(k) {
  case internal.first_key(table_ref) {
    Ok(first_dyn_key) ->
      collect_keys_from_first(table, table_ref, first_dyn_key)
    Error(_) -> []
  }
}

fn collect_keys_from_first(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
  first_dyn_key: dynamic.Dynamic,
) -> List(k) {
  case table.decode_key(table, first_dyn_key) {
    Ok(first_key) ->
      collect_remaining_keys(table, table_ref, first_dyn_key, [first_key])
    Error(_) -> []
  }
}

fn collect_remaining_keys(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
  current_dyn_key: dynamic.Dynamic,
  acc: List(k),
) -> List(k) {
  case internal.next_key(table_ref, current_dyn_key) {
    Ok(next_dyn_key) -> {
      case table.decode_key(table, next_dyn_key) {
        Ok(next_key) ->
          collect_remaining_keys(table, table_ref, next_dyn_key, [
            next_key,
            ..acc
          ])
        Error(_) -> acc
      }
    }
    Error(_) -> acc
  }
}

fn collect_all_values(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> List(v) {
  let keys_list = collect_all_keys(table, table_ref)
  list.map(keys_list, map_key_to_value(table, _))
}

fn map_key_to_value(table: table.Table(k, v), key: k) -> v {
  case get(table, key) {
    Ok(option.Some(value)) -> value
    Ok(option.None) -> panic as "Key should exist"
    Error(_) -> panic as "Should not error"
  }
}

fn collect_all_pairs(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> List(#(k, v)) {
  let keys_list = collect_all_keys(table, table_ref)
  list.map(keys_list, map_key_to_pair(table, _))
}

fn map_key_to_pair(table: table.Table(k, v), key: k) -> #(k, v) {
  case get(table, key) {
    Ok(option.Some(value)) -> #(key, value)
    Ok(option.None) -> panic as "Key should exist"
    Error(_) -> panic as "Should not error"
  }
}
