Feature: Custom Context Example

    Background:
        Given the server is running on port 3001

    Scenario: GET root endpoint is public
        When I send a GET request to "/"
        Then the response status should be 200

    Scenario: GET users posts endpoint without auth returns unauthorized
        When I send a GET request to "/users/1/posts/2"
        Then the response status should be 401

    Scenario: GET users posts endpoint with user token succeeds
        When I send a GET request to "/users/1/posts/2" with header "Authorization" set to "Bearer user-token"
        Then the response status should be 200

    Scenario: GET admin endpoint with user token returns forbidden
        When I send a GET request to "/admin" with header "Authorization" set to "Bearer user-token"
        Then the response status should be 403

    Scenario: GET admin endpoint with admin token succeeds
        When I send a GET request to "/admin" with header "Authorization" set to "Bearer admin-token"
        Then the response status should be 200

    Scenario: GET non-existent endpoint returns 404
        When I send a GET request to "/nonexistent"
        Then the response status should be 404

    Scenario: GET users posts with invalid token format returns 401
        When I send a GET request to "/users/1/posts/2" with header "Authorization" set to "InvalidToken"
        Then the response status should be 401

