//// Example for the doc of `error.Forbidden`.

import dream/http/error.{type Error, Forbidden}

pub fn require_admin(is_admin: Bool) -> Result(Nil, Error) {
  case is_admin {
    True -> Ok(Nil)
    False -> Error(Forbidden("Admin access required"))
  }
}

pub fn check_post_owner(user_id: Int, author_id: Int) -> Result(Nil, Error) {
  case user_id == author_id {
    True -> Ok(Nil)
    False -> Error(Forbidden("Cannot delete another user's post"))
  }
}
