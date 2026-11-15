//// Naming conventions: State Management
////
//// `load_{noun}` and `save_{noun}` read and write lasting storage.
//// `store_{noun}` keeps a value in memory, and `restore_{noun}` brings
//// back a saved copy.

import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import simplifile

pub type User {
  User(id: Int, name: String)
}

pub type Session {
  Session(id: String, user_id: Int)
}

pub type Database {
  Database(users: Dict(Int, User))
}

pub fn load_user(database: Database, id: Int) -> Result(User, Nil) {
  dict.get(database.users, id)
}

pub fn load_config(path: String) -> Result(String, simplifile.FileError) {
  simplifile.read(path)
}

pub fn save_user(database: Database, user: User) -> Database {
  Database(users: dict.insert(database.users, user.id, user))
}

pub fn save_config(
  config: String,
  path: String,
) -> Result(Nil, simplifile.FileError) {
  simplifile.write(to: path, contents: config)
}

pub fn store_session(
  sessions: Dict(String, Session),
  session: Session,
) -> Dict(String, Session) {
  dict.insert(sessions, session.id, session)
}

pub fn restore_sessions(snapshot: List(Session)) -> Dict(String, Session) {
  list.fold(snapshot, dict.new(), store_session)
}

pub fn restore_config(
  backup_path: String,
  path: String,
) -> Result(Nil, simplifile.FileError) {
  use backup <- result.try(simplifile.read(backup_path))
  simplifile.write(to: path, contents: backup)
}
