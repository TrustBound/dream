import dream/http/request.{type Method, type Request, Http, Http1, Request, Text}
import gleam/option

pub fn create_request(method: Method, path: String) -> Request {
  Request(
    method: method,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn create_request_with_body(
  method: Method,
  path: String,
  body: String,
) -> Request {
  Request(..create_request(method, path), body: Text(body))
}
