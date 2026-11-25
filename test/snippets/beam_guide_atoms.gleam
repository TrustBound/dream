//// BEAM guide: atoms made from user input

import gleam/erlang/atom.{type Atom}

/// Wrong: makes a new atom for each new value that a client sends. The
/// runtime never frees an atom.
pub fn sort_key_from_input(text: String) -> Atom {
  atom.create(text)
}

pub type SortKey {
  ByName
  ByDate
}

/// Fix: accept only the values that you know, as a custom type
pub fn sort_key(text: String) -> Result(SortKey, Nil) {
  case text {
    "name" -> Ok(ByName)
    "date" -> Ok(ByDate)
    _ -> Error(Nil)
  }
}
