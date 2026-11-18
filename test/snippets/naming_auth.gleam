//// Naming conventions: Authentication and Authorization
////
//// `authenticate_{noun}` finds out who someone is, `authorize_{noun}`
//// finds out what they can do, and `check_{noun}_permission` tests one
//// permission.

import dream/http.{type Request}
import gleam/list
import gleam/option.{Some}
import gleam/result

pub type Role {
  Reader
  Editor
}

pub type User {
  User(id: Int, name: String, role: Role)
}

pub type Credentials {
  Credentials(username: String, password: String)
}

pub type Article {
  Article(id: Int, author_id: Int)
}

pub type Permission {
  ReadArticles
  EditArticles
}

pub type AuthError {
  InvalidCredentials
  InvalidToken
  Forbidden
}

const ada = User(id: 1, name: "Ada", role: Editor)

pub fn authenticate_user(credentials: Credentials) -> Result(User, AuthError) {
  case credentials {
    Credentials(username: "ada", password: "correct-horse") -> Ok(ada)
    _ -> Error(InvalidCredentials)
  }
}

pub fn authenticate_token(token: String) -> Result(User, AuthError) {
  case token {
    "token-ada" -> Ok(ada)
    _ -> Error(InvalidToken)
  }
}

pub fn authenticate_request(request: Request) -> Result(User, AuthError) {
  case http.get_header(request.headers, "Authorization") {
    Some("Bearer " <> token) -> authenticate_token(token)
    _ -> Error(InvalidToken)
  }
}

pub fn authorize_user(user: User, article: Article) -> Result(Nil, AuthError) {
  case user.id == article.author_id || user.role == Editor {
    True -> Ok(Nil)
    False -> Error(Forbidden)
  }
}

pub fn authorize_request(
  request: Request,
  article: Article,
) -> Result(Nil, AuthError) {
  use user <- result.try(authenticate_request(request))
  authorize_user(user, article)
}

pub fn check_user_permission(user: User, permission: Permission) -> Bool {
  list.contains(role_permissions(user.role), permission)
}

pub fn check_request_permission(
  request: Request,
  permission: Permission,
) -> Bool {
  case authenticate_request(request) {
    Ok(user) -> check_user_permission(user, permission)
    Error(_error) -> False
  }
}

fn role_permissions(role: Role) -> List(Permission) {
  case role {
    Reader -> [ReadArticles]
    Editor -> [ReadArticles, EditArticles]
  }
}
