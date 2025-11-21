//// Internal ETS operations
////
//// Low-level wrappers around FFI. No public API.

import gleam/dynamic
import gleam/erlang/atom

pub type EtsTableRef

pub type EtsFfiError {
  NotFound
  AlreadyExists
  InvalidOperation(String)
  EmptyTable
  EndOfTable
}

@external(erlang, "internal_ffi", "ets_new")
fn ets_new_ffi(
  name_atom: atom.Atom,
  options: List(dynamic.Dynamic),
) -> Result(Int, EtsFfiError)

pub fn ets_new(
  name: String,
  options: List(dynamic.Dynamic),
) -> Result(Int, EtsFfiError) {
  let name_atom = atom.create(name)
  case ets_new_ffi(name_atom, options) {
    Ok(table_id) -> Ok(table_id)
    Error(err) -> handle_new_table_error(name_atom, err)
  }
}

fn handle_new_table_error(
  name_atom: atom.Atom,
  err: EtsFfiError,
) -> Result(Int, EtsFfiError) {
  case err {
    _ -> check_if_duplicate_table(name_atom, err)
  }
}

fn check_if_duplicate_table(
  name_atom: atom.Atom,
  original_error: EtsFfiError,
) -> Result(Int, EtsFfiError) {
  // Try to get table info by name (named tables can be accessed by name atom)
  // If we can get info, table exists (duplicate)
  // If not, the original error was from invalid options
  case check_table_exists_by_name(name_atom) {
    True -> Error(AlreadyExists)
    False -> Error(original_error)
  }
}

fn check_table_exists_by_name(name_atom: atom.Atom) -> Bool {
  case ets_info_ffi_by_name(name_atom) {
    Ok(_) -> True
    Error(_) -> False
  }
}

@external(erlang, "internal_ffi", "ets_info_by_name")
fn ets_info_ffi_by_name(
  name_atom: atom.Atom,
) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "ets_match")
pub fn ets_match(
  table_id: Int,
  pattern: dynamic.Dynamic,
) -> List(dynamic.Dynamic)

@external(erlang, "internal_ffi", "ets_match_object")
pub fn ets_match_object(
  table_id: Int,
  pattern: dynamic.Dynamic,
) -> List(dynamic.Dynamic)

@external(erlang, "internal_ffi", "ets_select")
pub fn ets_select(
  table_id: Int,
  match_spec: dynamic.Dynamic,
) -> List(dynamic.Dynamic)

@external(erlang, "internal_ffi", "ets_tab2file")
pub fn ets_tab2file(table_id: Int, filename: String) -> Result(Nil, EtsFfiError)

@external(erlang, "internal_ffi", "ets_file2tab")
pub fn ets_file2tab(filename: String) -> Result(Int, EtsFfiError)

@external(erlang, "internal_ffi", "ets_insert")
pub fn ets_insert(table_id: Int, object: dynamic.Dynamic) -> Nil

@external(erlang, "internal_ffi", "ets_lookup")
pub fn ets_lookup(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError)

@external(erlang, "internal_ffi", "ets_delete_table")
pub fn ets_delete_table(table_id: Int) -> Nil

@external(erlang, "internal_ffi", "ets_delete_key")
pub fn ets_delete_key(table_id: Int, key: dynamic.Dynamic) -> Nil

@external(erlang, "internal_ffi", "ets_delete_object")
pub fn ets_delete_object(table_id: Int, object: dynamic.Dynamic) -> Nil

@external(erlang, "internal_ffi", "ets_delete_all_objects")
pub fn ets_delete_all_objects(table_id: Int) -> Nil

@external(erlang, "internal_ffi", "ets_first")
pub fn ets_first(table_id: Int) -> Result(dynamic.Dynamic, EtsFfiError)

@external(erlang, "internal_ffi", "ets_next")
pub fn ets_next(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError)

@external(erlang, "internal_ffi", "ets_member")
pub fn ets_member(table_id: Int, key: dynamic.Dynamic) -> Bool

@external(erlang, "internal_ffi", "ets_insert_new")
pub fn ets_insert_new(table_id: Int, object: dynamic.Dynamic) -> Bool

@external(erlang, "internal_ffi", "ets_take")
pub fn ets_take(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError)

@external(erlang, "internal_ffi", "ets_update_element")
pub fn ets_update_element(
  table_id: Int,
  key: dynamic.Dynamic,
  update_tuple: dynamic.Dynamic,
) -> Result(Nil, EtsFfiError)

@external(erlang, "internal_ffi", "ets_info")
pub fn ets_info(table_id: Int) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "to_dynamic")
pub fn to_dynamic(value: a) -> dynamic.Dynamic

@external(erlang, "internal_ffi", "wrap_table_ref")
pub fn wrap_table_ref_ffi(table_id: Int) -> EtsTableRef

@external(erlang, "internal_ffi", "unwrap_table_ref")
pub fn unwrap_table_ref_ffi(table: EtsTableRef) -> Int

pub fn new_table(
  name: String,
  options: List(dynamic.Dynamic),
) -> Result(EtsTableRef, EtsFfiError) {
  case ets_new(name, options) {
    Ok(table_id) -> Ok(wrap_table_ref(table_id))
    Error(err) -> Error(err)
  }
}

pub fn insert(table: EtsTableRef, object: dynamic.Dynamic) -> Nil {
  let table_id = unwrap_table_ref(table)
  ets_insert(table_id, object)
  Nil
}

pub fn lookup(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_lookup(table_id, key)
}

pub fn delete_table(table: EtsTableRef) -> Nil {
  let table_id = unwrap_table_ref(table)
  ets_delete_table(table_id)
  Nil
}

pub fn delete_key(table: EtsTableRef, key: dynamic.Dynamic) -> Nil {
  let table_id = unwrap_table_ref(table)
  ets_delete_key(table_id, key)
  Nil
}

pub fn delete_object(table: EtsTableRef, object: dynamic.Dynamic) -> Nil {
  let table_id = unwrap_table_ref(table)
  ets_delete_object(table_id, object)
  Nil
}

pub fn delete_all_objects(table: EtsTableRef) -> Nil {
  let table_id = unwrap_table_ref(table)
  ets_delete_all_objects(table_id)
  Nil
}

pub fn first_key(table: EtsTableRef) -> Result(dynamic.Dynamic, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_first(table_id)
}

pub fn next_key(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_next(table_id, key)
}

pub fn member(table: EtsTableRef, key: dynamic.Dynamic) -> Bool {
  let table_id = unwrap_table_ref(table)
  ets_member(table_id, key)
}

pub fn insert_new(table: EtsTableRef, object: dynamic.Dynamic) -> Bool {
  let table_id = unwrap_table_ref(table)
  ets_insert_new(table_id, object)
}

pub fn take(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_take(table_id, key)
}

pub fn update_element(
  table: EtsTableRef,
  key: dynamic.Dynamic,
  pos: Int,
  value: dynamic.Dynamic,
) -> Result(Nil, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  let update_tuple = to_dynamic(#(pos, value))
  ets_update_element(table_id, key, update_tuple)
}

pub fn table_info(
  table: EtsTableRef,
) -> Result(List(dynamic.Dynamic), EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_info(table_id)
}

pub fn match(
  table: EtsTableRef,
  pattern: dynamic.Dynamic,
) -> List(dynamic.Dynamic) {
  let table_id = unwrap_table_ref(table)
  ets_match(table_id, pattern)
}

pub fn match_object(
  table: EtsTableRef,
  pattern: dynamic.Dynamic,
) -> List(dynamic.Dynamic) {
  let table_id = unwrap_table_ref(table)
  ets_match_object(table_id, pattern)
}

pub fn select(
  table: EtsTableRef,
  match_spec: dynamic.Dynamic,
) -> List(dynamic.Dynamic) {
  let table_id = unwrap_table_ref(table)
  ets_select(table_id, match_spec)
}

pub fn tab2file(
  table: EtsTableRef,
  filename: String,
) -> Result(Nil, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_tab2file(table_id, filename)
}

pub fn file2tab(filename: String) -> Result(EtsTableRef, EtsFfiError) {
  case ets_file2tab(filename) {
    Ok(table_id) -> Ok(wrap_table_ref(table_id))
    Error(err) -> Error(err)
  }
}

// Private helper functions

fn wrap_table_ref(table_id: Int) -> EtsTableRef {
  wrap_table_ref_ffi(table_id)
}

fn unwrap_table_ref(table: EtsTableRef) -> Int {
  unwrap_table_ref_ffi(table)
}
