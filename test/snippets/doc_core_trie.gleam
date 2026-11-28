//// Examples for the doc comments of `dream/router/trie`.

import dream/router/trie.{Literal, Match, Param, insert, lookup, new}
import gleam/option.{None, Some}

pub fn users_trie(user_handler) {
  let trie =
    new()
    |> insert("GET", [Literal("users")], user_handler)
  trie
}

pub fn user_trie(handler, create_handler) {
  let trie =
    new()
    |> insert("GET", [Literal("users"), Param("id")], handler)
    |> insert("POST", [Literal("users")], create_handler)
  trie
}

pub fn find_user(trie) {
  let result = lookup(trie, "GET", ["users", "123"])
  case result {
    Some(Match(route, params)) -> {
      // params = [#("id", "123")]
      // route is the handler
      Ok(#(route, params))
    }
    // No matching route
    None -> Error(Nil)
  }
}
