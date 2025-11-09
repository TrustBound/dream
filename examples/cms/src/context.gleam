//// Request context

pub type Context {
  Context(request_id: String)
}

pub fn new() -> Context {
  Context(request_id: "")
}

