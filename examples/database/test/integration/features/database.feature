Feature: Database Example

    Background:
        Given the server is running on port 3002
        And the database is clean

    Scenario: GET users endpoint returns list
        When I send a GET request to "/users"
        Then the response status should be 200
        And the response should be valid JSON
        And the JSON response should be an array

    Scenario: POST users endpoint creates a user
        When I send a POST request to "/users" with a unique email
        Then the response status should be 201
        And the response should be valid JSON
        And the JSON response should contain field "name"
        And the JSON response should contain field "email"

    Scenario: GET user by id endpoint returns user with persisted data
        Given I send a POST request to "/users" with a unique email
        And I capture the user ID from the response
        When I send a GET request to "/users/<captured_id>"
        Then the response status should be 200
        And the response should be valid JSON
        And the JSON response should contain field "name"
        And the JSON response should contain field "email"

    Scenario: GET non-existent user returns 404
        When I send a GET request to "/users/999"
        Then the response status should be 404

    Scenario: PUT user endpoint updates user and persists changes
        Given I send a POST request to "/users" with a unique email
        And I capture the user ID from the response
        When I send a PUT request to "/users/<captured_id>" with the following JSON:
            """
            {"name":"Updated User","email":"updated@example.com"}
            """
        Then the response status should be 200
        And the response should be valid JSON
        And the JSON response should contain field "name" with value "Updated User"
        And the JSON response should contain field "email" with value "updated@example.com"
        When I send a GET request to "/users/<captured_id>"
        Then the response status should be 200
        And the JSON response should contain field "name" with value "Updated User"
        And the JSON response should contain field "email" with value "updated@example.com"

    Scenario: GET user posts endpoint returns posts list
        Given I send a POST request to "/users" with a unique email
        And I capture the user ID from the response
        When I send a GET request to "/users/<captured_id>/posts"
        Then the response status should be 200
        And the response should be valid JSON
        And the JSON response should be an array with 0 items

    Scenario: POST user posts endpoint creates a post
        Given I send a POST request to "/users" with a unique email
        And I capture the user ID from the response
        When I send a POST request to "/users/<captured_id>/posts" with the following JSON:
            """
            {"title":"Test Post","content":"Test content"}
            """
        Then the response status should be 201
        And the response should be valid JSON
        And the JSON response should contain field "title" with value "Test Post"
        And the JSON response should contain field "content" with value "Test content"
        When I send a GET request to "/users/<captured_id>/posts"
        Then the response status should be 200
        And the JSON response should be an array with 1 items

    Scenario: DELETE user endpoint deletes user
        Given I send a POST request to "/users" with the following JSON:
            """
            {"name":"Test User","email":"test@example.com"}
            """
        When I send a DELETE request to "/users/1"
        Then the response status should be 200
        When I send a GET request to "/users/1"
        Then the response status should be 404

    Scenario: POST users with invalid JSON returns 400
        When I send a POST request to "/users" with the following JSON:
            """
            {"name":"Test User","email":"invalid-json
            """
        Then the response status should be 400

    Scenario: POST users with missing required fields returns 400
        When I send a POST request to "/users" with the following JSON:
            """
            {"name":"Test User"}
            """
        Then the response status should be 400

    Scenario: PUT non-existent user returns 404
        When I send a PUT request to "/users/999" with the following JSON:
            """
            {"name":"Updated User","email":"updated@example.com"}
            """
        Then the response status should be 404

    Scenario: DELETE non-existent user returns 200
        When I send a DELETE request to "/users/999"
        Then the response status should be 200

    Scenario: POST post to non-existent user returns 500
        When I send a POST request to "/users/999/posts" with the following JSON:
            """
            {"title":"Test Post","content":"Test content"}
            """
        Then the response status should be 500

    Scenario: POST post with missing required fields returns 400
        Given I send a POST request to "/users" with a unique email
        And I capture the user ID from the response
        When I send a POST request to "/users/<captured_id>/posts" with the following JSON:
            """
            {"title":"Test Post"}
            """
        Then the response status should be 400

