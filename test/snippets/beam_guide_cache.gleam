//// BEAM guide: an ETS table that request processes read directly

pub type Table

/// Makes a table. The process that calls this owns the table.
@external(erlang, "beam_guide_cache_ffi", "new_table")
pub fn new_table() -> Table

@external(erlang, "beam_guide_cache_ffi", "insert")
pub fn insert(table: Table, key: String, value: Int) -> Nil

@external(erlang, "beam_guide_cache_ffi", "lookup")
pub fn lookup(table: Table, key: String) -> Result(Int, Nil)

/// Adds 1 to the number under `key` and returns the new number
@external(erlang, "beam_guide_cache_ffi", "increment")
pub fn increment(table: Table, key: String) -> Int

/// True while the table is there
@external(erlang, "beam_guide_cache_ffi", "exists")
pub fn exists(table: Table) -> Bool
