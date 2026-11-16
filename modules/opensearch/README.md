<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
  
  <a href="https://hexdocs.pm/dream_opensearch">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
</div>

# dream_opensearch

**Simple OpenSearch client for Gleam.**

A standalone HTTP client for interacting with OpenSearch (or Elasticsearch) clusters. Provides clean interfaces for indexing, searching, and managing documents. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ Document indexing and deletion
- ✅ Full-text search
- ✅ Index management
- ✅ Bulk operations
- ✅ Query builder helpers
- ✅ Zero dependencies on Dream or other frameworks

## Installation

```bash
gleam add dream_opensearch
```

## Quick Start <a href="https://github.com/TrustBound/dream/blob/dream_opensearch-2.0.0/modules/opensearch/test/snippets/readme_quick_start.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}
import dream_opensearch/document
import dream_opensearch/query
import gleam/json

// Create client
pub fn create_client() -> Client {
  client.new("http://localhost:9200")
}

// Index a document
pub fn index_alice(opensearch: Client) -> Result(String, String) {
  let user =
    json.object([
      #("name", json.string("Alice")),
      #("email", json.string("alice@example.com")),
    ])
  document.index(opensearch, "users", "123", json.to_string(user))
}

// Search documents
pub fn search_for_alice(opensearch: Client) -> Result(String, String) {
  let search_query = query.match("name", "Alice")
  document.search(opensearch, "users", search_query)
}

// Delete document
pub fn delete_alice(opensearch: Client) -> Result(String, String) {
  document.delete(opensearch, "users", "123")
}
```

## Usage

### Client Setup <a href="https://github.com/TrustBound/dream/blob/dream_opensearch-2.0.0/modules/opensearch/test/snippets/readme_client_setup.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}

// Basic setup
pub fn create_local_client() -> Client {
  client.new("http://localhost:9200")
}

// Do not do this: the client does not read a user name and password from
// the URL, so the request does not authenticate.
pub fn create_client_with_credentials_in_url() -> Client {
  client.new("https://user:pass@search.example.com:9200")
}
```

The second function is a bad example. The client keeps the URL as you give it, but it sends no `authorization` header, so OpenSearch gets no credentials. This version of `dream_opensearch` has no way to send credentials.

### Indexing Documents <a href="https://github.com/TrustBound/dream/blob/dream_opensearch-2.0.0/modules/opensearch/test/snippets/readme_indexing_documents.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

pub fn index_user(opensearch: Client) -> String {
  let user =
    json.object([
      #("name", json.string("Alice")),
      #("email", json.string("alice@example.com")),
      #("age", json.int(30)),
    ])

  case document.index(opensearch, "users", "123", json.to_string(user)) {
    Ok(_response) -> "Indexed successfully"
    Error(message) -> "Error: " <> message
  }
}
```

### Searching

Use query builders for common queries:

#### Search with each query builder <a href="https://github.com/TrustBound/dream/blob/dream_opensearch-2.0.0/modules/opensearch/test/snippets/readme_searching.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}
import dream_opensearch/document
import dream_opensearch/query

// Full-text search
pub fn search_by_name(opensearch: Client) -> Result(String, String) {
  let name_query = query.match("name", "Alice")
  document.search(opensearch, "users", name_query)
}

// Exact term match
pub fn search_by_status(opensearch: Client) -> Result(String, String) {
  let status_query = query.term("status", "active")
  document.search(opensearch, "users", status_query)
}

// Range query
pub fn search_by_age(opensearch: Client) -> Result(String, String) {
  let age_query = query.range("age", "18", "65")
  document.search(opensearch, "users", age_query)
}

// Match all
pub fn search_all(opensearch: Client) -> Result(String, String) {
  let all_query = query.match_all()
  document.search(opensearch, "users", all_query)
}
```

### Custom Queries

For complex queries, build JSON manually:

#### Search with a bool query <a href="https://github.com/TrustBound/dream/blob/dream_opensearch-2.0.0/modules/opensearch/test/snippets/readme_custom_queries.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

pub fn search_active_users_named_alice(
  opensearch: Client,
) -> Result(String, String) {
  let bool_query =
    json.object([
      #(
        "query",
        json.object([
          #(
            "bool",
            json.object([
              #(
                "must",
                json.preprocessed_array([
                  json.object([
                    #("match", json.object([#("name", json.string("Alice"))])),
                  ]),
                ]),
              ),
              #(
                "filter",
                json.preprocessed_array([
                  json.object([
                    #("term", json.object([#("status", json.string("active"))])),
                  ]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  document.search(opensearch, "users", json.to_string(bool_query))
}
```

### Index Management <a href="https://github.com/TrustBound/dream/blob/dream_opensearch-2.0.0/modules/opensearch/test/snippets/readme_index_management.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

// Create index with mapping
pub fn create_users_index(opensearch: Client) -> Result(String, String) {
  let mapping =
    json.object([
      #(
        "mappings",
        json.object([
          #(
            "properties",
            json.object([
              #("name", json.object([#("type", json.string("text"))])),
              #("email", json.object([#("type", json.string("keyword"))])),
            ]),
          ),
        ]),
      ),
    ])
  document.create_index(opensearch, "users", json.to_string(mapping))
}

// Delete index
pub fn delete_old_index(opensearch: Client) -> Result(String, String) {
  document.delete_index(opensearch, "old_index")
}
```

### Bulk Operations <a href="https://github.com/TrustBound/dream/blob/dream_opensearch-2.0.0/modules/opensearch/test/snippets/readme_bulk_operations.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}
import dream_opensearch/document

pub fn bulk_index_users(opensearch: Client) -> Result(String, String) {
  // NDJSON format: action and document on alternating lines
  let ndjson =
    "{ \"index\": { \"_index\": \"users\", \"_id\": \"1\" } }\n"
    <> "{ \"name\": \"Alice\", \"email\": \"alice@example.com\" }\n"
    <> "{ \"index\": { \"_index\": \"users\", \"_id\": \"2\" } }\n"
    <> "{ \"name\": \"Bob\", \"email\": \"bob@example.com\" }\n"

  document.bulk(opensearch, ndjson)
}
```

## API Reference

### Client

- `client.new(base_url)` - Create new OpenSearch client

### Document Operations

- `document.index(client, index, id, json)` - Index a document
- `document.search(client, index, query_json)` - Search documents
- `document.delete(client, index, id)` - Delete a document
- `document.create_index(client, index, mapping_json)` - Create index
- `document.delete_index(client, index)` - Delete index
- `document.bulk(client, ndjson)` - Bulk index documents

### Query Builders

- `query.match_all()` - Match all documents
- `query.match(field, text)` - Full-text search
- `query.term(field, value)` - Exact term match
- `query.range(field, gte, lte)` - Range query

## Design Principles

This module follows the same quality standards as [Dream](https://github.com/TrustBound/dream):

- **No nested cases** - Clear, flat control flow
- **No anonymous functions** - Named functions for clarity
- **Builder pattern** - Consistent, composable APIs
- **Type safety** - `Result` types force error handling
- **Quality testing** - Comprehensive test coverage

## About Dream

This module was originally built for the [Dream](https://github.com/TrustBound/dream) web toolkit, but it's completely standalone and can be used in any Gleam project. It follows Dream's design principles and will be maintained as part of the Dream ecosystem.

## License

MIT License - see LICENSE file for details.
