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
