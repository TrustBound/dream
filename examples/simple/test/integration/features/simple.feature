Feature: Simple Example

    Background:
        Given the server is running on port 3000

    Scenario: GET root endpoint returns hello world
        When I send a GET request to "/"
        Then the response status should be 200
        And the response should contain "Hello, World!"

    Scenario: GET users posts endpoint with path parameters
        When I send a GET request to "/users/1/posts/2"
        Then the response status should be 200
        And the response should contain "User: 1"
        And the response should contain "Post: 2"

    Scenario: GET non-existent endpoint returns 404
        When I send a GET request to "/nonexistent"
        Then the response status should be 404

