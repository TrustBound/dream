//// Naming conventions: a `user` module
////
//// The module name is the namespace. `find` reads as `user.find` where it
//// is called. `user_find` repeats the module name: `user.user_find`.

import gleam/list

pub type User {
  User(id: Int, name: String)
}

const users = [User(id: 1, name: "Ada"), User(id: 2, name: "Grace")]

pub fn find(id: Int) -> Result(User, Nil) {
  list.find(users, fn(user) { user.id == id })
}

pub fn user_find(id: Int) -> Result(User, Nil) {
  list.find(users, fn(user) { user.id == id })
}
