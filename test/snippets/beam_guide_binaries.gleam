//// BEAM guide: a slice of a large binary

import gleam/bit_array

/// Wrong: a slice of more than 64 bytes points into the upload, so the
/// whole upload stays in memory while you keep the slice
pub fn preview_slice(upload: BitArray, size: Int) -> Result(BitArray, Nil) {
  bit_array.slice(upload, at: 0, take: size)
}

/// Fix: copy the slice, so the runtime can free the upload
pub fn preview_copy(upload: BitArray, size: Int) -> Result(BitArray, Nil) {
  case bit_array.slice(upload, at: 0, take: size) {
    Ok(preview) -> Ok(copy(preview))
    Error(Nil) -> Error(Nil)
  }
}

@external(erlang, "binary", "copy")
fn copy(bits: BitArray) -> BitArray
