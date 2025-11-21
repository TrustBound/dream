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

## Quick Start

```gleam
import dream_opensearch/client
import dream_opensearch/document
import dream_opensearch/query
import gleam/json

// Create client
let client = client.new("http://localhost:9200")

// Index a document
let doc = json.object([
  #("name", json.string("Alice")),
  #("email", json.string("alice@example.com")),
])
document.index(client, "users", "123", json.to_string(doc))

// Search documents
let search_query = query.match("name", "Alice")
case document.search(client, "users", search_query) {
  Ok(results) -> process_results(results)
  Error(msg) -> handle_error(msg)
}

// Delete document
document.delete(client, "users", "123")
```

## Usage

### Client Setup

```gleam
import dream_opensearch/client

// Basic setup
let client = client.new("http://localhost:9200")

// With authentication
let client = client.new("https://user:pass@search.example.com:9200")
```

### Indexing Documents

```gleam
import dream_opensearch/document
import gleam/json

let doc = json.object([
  #("name", json.string("Alice")),
  #("email", json.string("alice@example.com")),
  #("age", json.int(30)),
])

case document.index(client, "users", "123", json.to_string(doc)) {
  Ok(response) -> io.println("Indexed successfully")
  Error(msg) -> io.println("Error: " <> msg)
}
```

### Searching

Use query builders for common queries:

```gleam
import dream_opensearch/document
import dream_opensearch/query

// Full-text search
let query = query.match("name", "Alice")
document.search(client, "users", query)

// Exact term match
let query = query.term("status", "active")
document.search(client, "users", query)

// Range query
let query = query.range("age", "18", "65")
document.search(client, "users", query)

// Match all
let query = query.match_all()
document.search(client, "users", query)
```

### Custom Queries

For complex queries, build JSON manually:

```gleam
import gleam/json

let query = json.object([
  #("query", json.object([
    #("bool", json.object([
      #("must", json.array([
        json.object([#("match", json.object([#("name", json.string("Alice"))]))]),
      ])),
      #("filter", json.array([
        json.object([#("term", json.object([#("status", json.string("active"))]))]),
      ])),
    ])),
  ])),
])

document.search(client, "users", json.to_string(query))
```

### Index Management

```gleam
import dream_opensearch/document
import gleam/json

// Create index with mapping
let mapping = json.object([
  #("mappings", json.object([
    #("properties", json.object([
      #("name", json.object([#("type", json.string("text"))])),
      #("email", json.object([#("type", json.string("keyword"))])),
    ])),
  ])),
])
document.create_index(client, "users", json.to_string(mapping))

// Delete index
document.delete_index(client, "old_index")
```

### Bulk Operations

```gleam
import dream_opensearch/document

// NDJSON format: action and document on alternating lines
let ndjson = "{ \"index\": { \"_index\": \"users\", \"_id\": \"1\" } }\n"
  <> "{ \"name\": \"Alice\", \"email\": \"alice@example.com\" }\n"
  <> "{ \"index\": { \"_index\": \"users\", \"_id\": \"2\" } }\n"
  <> "{ \"name\": \"Bob\", \"email\": \"bob@example.com\" }\n"

document.bulk(client, ndjson)
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
