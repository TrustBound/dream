//// Request Matching Configuration
////
//// Example showing how to configure request key generation for recordings.

import dream_http_client/matching

pub fn create_default_key() -> matching.MatchKey {
  // Default: match on method + URL only
  matching.request_key(method: True, url: True, headers: False, body: False)
}

pub fn create_custom_key() -> matching.MatchKey {
  // Custom: match on method + URL + headers + body
  matching.request_key(method: True, url: True, headers: True, body: True)
}
