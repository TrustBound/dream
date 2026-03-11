Feature: Server-Sent Events

    Background:
        Given the server is running on port 8081

    Scenario: SSE endpoint streams events with correct headers
        When I connect to SSE at "/events"
        Then the SSE response header "content-type" should contain "text/event-stream"
        And the SSE response header "cache-control" should contain "no-cache"
        And I should receive at least 3 SSE events within 5 seconds
        And each event should have a "data" field

    Scenario: SSE events with names and IDs
        When I connect to SSE at "/events/named"
        Then I should receive an SSE event with name "tick"
        And the event should have an "id" field

    Scenario: SSE events do not stall after initial events
        When I connect to SSE at "/events"
        And I wait for 10 events
        Then all 10 events should arrive within 15 seconds

    Scenario: CORS middleware headers appear on SSE response
        When I connect to SSE at "/events/cors"
        Then the SSE response header "access-control-allow-origin" should contain "*"
        And the SSE response header "access-control-allow-methods" should contain "GET, POST, OPTIONS"
        And the SSE response header "content-type" should contain "text/event-stream"
        And I should receive at least 2 SSE events within 5 seconds

    Scenario: Multiple middleware headers all appear on SSE response
        When I connect to SSE at "/events/stacked"
        Then the SSE response header "access-control-allow-origin" should contain "*"
        And the SSE response header "x-content-type-options" should contain "nosniff"
        And the SSE response header "x-frame-options" should contain "DENY"
        And I should receive at least 2 SSE events within 5 seconds

    Scenario: Middleware rejection prevents SSE upgrade
        When I send a GET request to "/events/rejected"
        Then the response status should be 401

    Scenario: CORS middleware does not interfere with event streaming
        When I connect to SSE at "/events/cors"
        And I wait for 5 events
        Then all 5 events should arrive within 10 seconds
        And each event should have a "data" field
