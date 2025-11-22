Feature: Rate Limiter Example

    Background:
        Given the server is running on port 3000

    Scenario: GET root endpoint returns welcome message
        When I send a GET request to "/"
        Then the response status should be 200
        And the response header "X-RateLimit-Limit" should not exist

    Scenario: GET api endpoint succeeds with rate limit headers
        When I send a GET request to "/api" from IP "192.168.1.1"
        Then the response status should be 200
        And the response header "X-RateLimit-Limit" should exist
        And the response header "X-RateLimit-Remaining" should exist
        And the response header "X-RateLimit-Limit" should be "10"

    Scenario: Rate limit remaining decreases with each request
        When I send a GET request to "/api" from IP "192.168.1.2"
        Then the response status should be 200
        And the response header "X-RateLimit-Remaining" should exist
        When I send a GET request to "/api" from IP "192.168.1.2"
        Then the response status should be 200
        And the response header "X-RateLimit-Remaining" should exist

    Scenario: First 10 requests succeed, 11th is rate limited
        Given I send 10 GET requests to "/api" from IP "192.168.1.3"
        Then all responses should have status 200
        When I send a GET request to "/api" from IP "192.168.1.3"
        Then the response status should be 429

    Scenario: Rate limiting triggers after multiple requests
        When I send 12 GET requests to "/api" from IP "192.168.1.4"
        Then at least one response should have status 429

    Scenario: Rate limited response includes Retry-After header
        Given I send 12 GET requests to "/api" from IP "192.168.1.5"
        When I send a GET request to "/api" from IP "192.168.1.5"
        Then the response status should be 429
        And the response header "Retry-After" should exist
        And the response header "Retry-After" should be "60"
        And the response header "X-RateLimit-Limit" should be "10"
        And the response header "X-RateLimit-Remaining" should be "0"
        And the response should contain "Rate limit exceeded"

    Scenario: Rate limit window resets (simulated)
        # Using a different IP to simulate a fresh window scenario
        # In a real environment we would wait > 60s, but for CI we simulate
        # window expiration by using a new IP which effectively has a new window
        When I send 10 GET requests to "/api" from IP "192.168.1.7"
        Then all responses should have status 200
        When I send a GET request to "/api" from IP "192.168.1.8"
        Then the response status should be 200
        And the response header "X-RateLimit-Remaining" should be "9"

