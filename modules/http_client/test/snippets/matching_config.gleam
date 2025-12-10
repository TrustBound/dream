//// Request Matching Configuration
////
//// Example showing how to configure request matching for recordings.

import dream_http_client/matching

pub fn create_default_matching() -> matching.MatchingConfig {
  // Default: Match on method + URL only
  matching.match_url_only()
}

pub fn create_custom_matching() -> matching.MatchingConfig {
  // Custom matching - ignore headers and body
  matching.MatchingConfig(
    match_method: True,
    match_url: True,
    match_headers: False,
    match_body: False,
  )
}
