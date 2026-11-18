//// Doc comment example: dream/servers/mist/request.generate_request_id

import dream/servers/mist/request.{generate_request_id}

pub fn new_request_id() -> String {
  let request_id = generate_request_id()
  // Returns something like: "//erl(<0.123.0>)"
  request_id
}
