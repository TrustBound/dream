# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.x     | ✅ Active support  |
| < 2.0   | ❌ Not supported (beta versions) |

## What Dream Is Responsible For

Dream is a library that provides:
- **Router** - Path matching and parameter extraction
- **HTTP types** - Request/Response builders
- **Validation helpers** - `require_int()`, `require_string()`, etc.
- **Streaming APIs** - Chunked response handling

Dream is **not a framework**. You build the application. You write the auth. You write the SQL.

This means Dream's security surface is small:
- Router vulnerabilities (path traversal in routing logic, parameter injection)
- Streaming API bugs (memory issues, resource exhaustion)
- Type system bypasses in validation helpers

## What You're Responsible For

Your application code handles:
- **Authentication** - You implement it
- **Authorization** - You control access
- **SQL injection** - You write queries (use parameterized queries)
- **Input validation** - Beyond what `require_*` provides
- **File uploads** - Your controllers handle this
- **Rate limiting** - Implement as middleware if needed
- **TLS/HTTPS** - Your reverse proxy (nginx, Caddy)
- **Session management** - You build this
- **CSRF protection** - Implement as middleware if needed

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues.**

Email: **engineering@trustbound.ai**

### What to Include

- **Type of vulnerability** (e.g., path traversal in router, parameter injection)
- **Location** in Dream's code (file/function)
- **Steps to reproduce** with minimal example
- **Impact** - What can an attacker do?
- **Proof-of-concept** if you have one

Focus on vulnerabilities in **Dream's code**, not in your application code.

### What to Expect

1. **Acknowledgment** within 48 hours
2. **Assessment** within 7 days
3. **Fix** coordinated with you on timing
4. **Release** with security advisory
5. **Credit** in the advisory (if desired)

## Security in Dream

### Type Safety

Gleam's type system prevents many vulnerabilities:
- ✅ No null pointer exceptions
- ✅ No buffer overflows
- ✅ Exhaustive pattern matching
- ✅ Immutable data structures

### What Dream Validates

Dream's `require_*` functions validate types, not business rules:

```gleam
// Dream validates this is an integer
case require_int(request, "user_id") {
  Ok(user_id) -> {
    // YOU must validate business rules
    case user_id > 0 {
      True -> fetch_user(db, user_id)
      False -> text_response(bad_request, "Invalid user ID")
    }
  }
  Error(error) -> text_response(bad_request, error.message)
}
```

Dream extracts and type-checks. You validate and authorize.

### What Dream Doesn't Do

Dream provides no built-in:
- ❌ Authentication middleware
- ❌ Authorization checks
- ❌ SQL query builders (use Squirrel or raw SQL)
- ❌ Input sanitization (beyond type validation)
- ❌ Rate limiting
- ❌ CSRF tokens
- ❌ Session management

This is intentional. Dream provides building blocks. You compose them.

## Known Non-Issues

These are not Dream vulnerabilities (they're your application's responsibility):

- SQL injection from unparameterized queries
- Missing authentication checks
- Missing authorization checks
- HTTPS not configured (reverse proxy's job)
- Weak session tokens (you implement sessions)
- Missing rate limiting (implement as middleware if needed)

## Dependencies

Dream's dependencies:
- **Mist** - HTTP server (wraps Erlang's Cowboy)
- **Gleam stdlib** - Type-safe, battle-tested
- **BEAM/OTP** - 30+ years of production use

We monitor dependencies and update promptly for security issues.

## Questions?

- **Security questions**: engineering@trustbound.ai
- **Non-security issues**: [GitHub Issues](https://github.com/TrustBound/dream/issues)
- **General discussion**: [GitHub Discussions](https://github.com/TrustBound/dream/discussions)

---

**Remember:** Dream is a library. It provides tools. You write the application. You're responsible for your application's security.
