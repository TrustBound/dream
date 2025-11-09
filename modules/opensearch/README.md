# dream_opensearch

OpenSearch client for Dream applications.

Provides simple HTTP wrapper for indexing, searching, and managing documents in OpenSearch.

## Usage

```gleam
import dream_opensearch/client
import dream_opensearch/document

// Create client
let opensearch = client.new("http://localhost:9200")

// Index a document
document.index(opensearch, "logs", "doc-id-123", json_string)

// Search documents
document.search(opensearch, "logs", search_query_json)

// Delete document
document.delete(opensearch, "logs", "doc-id-123")
```

