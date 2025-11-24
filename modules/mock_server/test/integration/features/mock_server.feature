Feature: Mock Server

    Background:
        Given the server is running on port 3004

    Scenario: GET root endpoint returns info page
        When I send a GET request to "/"
        Then the response status should be 200
        And the response should start with "Mock"
        And the response should contain "Non-Streaming Endpoints"
        And the response should contain "Streaming Endpoints"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /get returns JSON with request info
        When I send a GET request to "/get"
        Then the response status should be 200
        And the response should contain valid JSON
        And the response should contain "GET"
        And the response should contain "/get"
        And the response header "Content-Type" should contain "application/json"

    Scenario: POST /post echoes request body as JSON
        When I send a POST request to "/post"
        Then the response status should be 201
        And the response should contain valid JSON
        And the response should contain "POST"
        And the response should contain "/post"
        And the response header "Content-Type" should contain "application/json"

    Scenario: PUT /put echoes request body as JSON
        When I send a PUT request to "/put"
        Then the response status should be 200
        And the response should contain valid JSON
        And the response should contain "PUT"
        And the response should contain "/put"
        And the response header "Content-Type" should contain "application/json"

    Scenario: DELETE /delete returns success response
        When I send a DELETE request to "/delete"
        Then the response status should be 200
        And the response should contain valid JSON
        And the response should contain "DELETE"
        And the response should contain "/delete"
        And the response header "Content-Type" should contain "application/json"

    Scenario: GET /json returns simple JSON object
        When I send a GET request to "/json"
        Then the response status should be 200
        And the response should contain valid JSON
        And the response should contain "Hello, World!"
        And the response should contain "success"
        And the response header "Content-Type" should contain "application/json"

    Scenario: GET /text returns plain text
        When I send a GET request to "/text"
        Then the response status should be 200
        And the response should contain "Hello, World!"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /uuid returns UUID-like string
        When I send a GET request to "/uuid"
        Then the response status should be 200
        And the response should contain valid JSON
        And the response should contain "uuid"
        And the response header "Content-Type" should contain "application/json"

    Scenario: GET /status/200 returns 200 status
        When I send a GET request to "/status/200"
        Then the response status should be 200
        And the response should contain valid JSON
        And the response should contain "200"

    Scenario: GET /status/404 returns 404 status
        When I send a GET request to "/status/404"
        Then the response status should be 404
        And the response should contain valid JSON
        And the response should contain "404"

    Scenario: GET /status/500 returns 500 status
        When I send a GET request to "/status/500"
        Then the response status should be 500
        And the response should contain valid JSON
        And the response should contain "500"

    Scenario: GET /large returns very large response body
        When I send a GET request to "/large"
        Then the response status should be 200
        And the response body size should be at least 100000 bytes
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /empty returns empty response body
        When I send a GET request to "/empty"
        Then the response status should be 200
        And the response body should be empty
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /slow returns response after delay
        When I send a GET request to "/slow"
        Then the response status should be 200
        And the response should contain "Slow response"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /stream/fast returns exactly 10 chunks
        When I send a GET request to "/stream/fast"
        Then the response status should be 200
        And the response should have exactly 10 lines
        And the response should contain "Chunk 1"
        And the response should contain "Chunk 10"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /stream/slow returns exactly 5 chunks with delays
        When I send a GET request to "/stream/slow"
        Then the response status should be 200
        And the response should have exactly 5 lines
        And the response should contain "Chunk 1"
        And the response should contain "Chunk 5"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /stream/burst returns exactly 7 chunks
        When I send a GET request to "/stream/burst"
        Then the response status should be 200
        And the response should have exactly 7 lines
        And the response should contain "Burst 1"
        And the response should contain "Burst 7"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /stream/error returns error status with partial content
        When I send a GET request to "/stream/error"
        Then the response status should be 500
        And the response should have exactly 3 lines
        And the response should contain "Error test chunk 1"
        And the response should contain "Error test chunk 3"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /stream/huge returns exactly 100 chunks
        When I send a GET request to "/stream/huge"
        Then the response status should be 200
        And the response should have exactly 100 lines
        And the response should contain "Huge chunk 1"
        And the response should contain "Huge chunk 100"
        And the response header "Content-Type" should contain "text/plain"

    Scenario: GET /stream/json returns valid JSON objects
        When I send a GET request to "/stream/json"
        Then the response status should be 200
        And the response should have exactly 5 lines
        And the response should contain valid JSON
        And the response should contain "JSON event 1"
        And the response should contain "JSON event 5"
        And the response header "Content-Type" should contain "application/json"

    Scenario: GET /stream/binary returns binary data
        When I send a GET request to "/stream/binary"
        Then the response status should be 200
        And the response body should not be empty
        And the response body size should be at least 1000 bytes
        And the response header "Content-Type" should contain "application/octet-stream"

    Scenario: GET non-existent endpoint returns 404
        When I send a GET request to "/nonexistent"
        Then the response status should be 404

    Scenario: Concurrent requests to fast stream work correctly
        When I send 3 concurrent GET requests to "/stream/fast"
        Then all 3 responses should have status 200
        And all 3 responses should have exactly 10 lines

    Scenario: Different endpoints can be called concurrently
        When I concurrently request "/stream/fast" and "/stream/burst"
        Then both responses should have status 200
        And the first response should have exactly 10 lines
        And the second response should have exactly 7 lines

