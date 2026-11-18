//// Example for the doc of `error.NotFound`.

import dream/http/error.{type Error, NotFound}
import gleam/int
import gleam/list
import gleam/result

pub fn find_user(
  users: List(#(Int, String)),
  id: Int,
) -> Result(String, Error) {
  list.key_find(users, id)
  |> result.replace_error(NotFound("User not found"))
}

pub fn find_post(
  posts: List(#(Int, String)),
  id: Int,
) -> Result(String, Error) {
  list.key_find(posts, id)
  |> result.replace_error(NotFound(
    "Post with ID " <> int.to_string(id) <> " does not exist",
  ))
}
