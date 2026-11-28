//// README: Ordering gotcha

import dream_mock_server/config.{type MockRoute, Exact, MockRoute, Prefix}
import gleam/option.{None}

// Good: specific before broad prefix
pub fn api_routes() -> List(MockRoute) {
  [
    MockRoute("/api/special", Exact, None, 200, "special"),
    MockRoute("/api", Prefix, None, 200, "general"),
  ]
}
