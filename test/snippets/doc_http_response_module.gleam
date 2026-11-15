import dream/http/response
import dream/http/status
import gleam/json

// Text response
pub fn greeting() {
  response.text_response(status.ok, "Hello, World!")
}

// JSON response
pub fn user(user_json: json.Json) {
  response.json_response(status.ok, json.to_string(user_json))
}

// HTML response
pub fn welcome_page() {
  response.html_response(status.ok, "<h1>Welcome</h1>")
}

// Redirect
pub fn login_redirect() {
  response.redirect_response(status.see_other, "/login")
}
