Feature: Streaming Example

    Background:
        Given the server is running on port 3003

    Scenario: GET root endpoint returns streaming content
        When I send a GET request to "/"
        Then the response status should be 200
        And the response should start with "Streaming"
        And the response should contain "Example"

    Scenario: GET fetch endpoint returns content
        When I send a GET request to "/fetch"
        Then the response status should be 200
        And the response should contain "Fetched"

    Scenario: GET stream endpoint returns streamed content
        When I send a GET request to "/stream"
        Then the response status should be 200
        And the response should have at least 1 lines
        And the response should contain "Streaming"

    Scenario: GET non-existent endpoint returns 404
        When I send a GET request to "/nonexistent"
        Then the response status should be 404

    Scenario: Streaming response contains multiple lines
        When I send a GET request to "/stream"
        Then the response status should be 200
        And the response should have at least 3 lines

