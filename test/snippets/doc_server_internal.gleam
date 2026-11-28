//// Example for the docs of `put`, `get`, `to_dynamic` and `unsafe_coerce`
//// in `dream/servers/mist/internal`.

import dream/servers/mist/internal
import gleam/erlang/atom

pub fn stash_and_read() -> String {
  let key = atom.create("doc_example_key")
  // put stores a value in the process dictionary of this process
  let _previous = internal.put(key, internal.to_dynamic("hello"))
  // get reads it back as a Dynamic, and unsafe_coerce gives back its type:
  // "hello"
  internal.unsafe_coerce(internal.get(key))
}
