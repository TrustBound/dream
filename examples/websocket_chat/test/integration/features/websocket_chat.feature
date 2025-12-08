Feature: WebSocket Chat

    Background:
        Given the server is running on port 8080

    Scenario: Home page returns HTML
        When I send a GET request to "/"
        Then the response status should be 200
        And the response should contain "Dream WebSocket Chat"
        And the response should contain "Enter your name to join the chat"

    Scenario: WebSocket upgrade connection
        When I upgrade to WebSocket at "/chat?user=Alice"
        Then the WebSocket connection should be established
        And I should receive a "joined" message for "Alice"

    Scenario: Send and receive chat messages
        Given I connect to WebSocket at "/chat?user=Bob"
        When I send WebSocket text "Hello, World!"
        Then I should receive a "message" from "Bob" with text "Hello, World!"

    Scenario: Multiple users in chat
        Given user "Alice" connects to the chat
        And user "Bob" connects to the chat
        When user "Alice" sends message "Hi Bob!"
        Then user "Bob" should receive message from "Alice" saying "Hi Bob!"
        When user "Bob" sends message "Hi Alice!"
        Then user "Alice" should receive message from "Bob" saying "Hi Alice!"

    Scenario: User join notifications
        Given user "Charlie" connects to the chat
        When user "Dave" connects to the chat
        Then user "Charlie" should receive "joined" notification for "Dave"

    Scenario: User leave notifications
        Given user "Eve" connects to the chat
        And user "Frank" connects to the chat
        When user "Frank" disconnects
        Then user "Eve" should receive "left" notification for "Frank"

    Scenario: Anonymous user defaults
        When I upgrade to WebSocket at "/chat"
        Then the WebSocket connection should be established
        And I should receive a "joined" message for "Anonymous"

    Scenario: Static assets are served
        When I send a GET request to "/assets/scripts/chat.js"
        Then the response status should be 200
        And the response should contain "WebSocket"
        When I send a GET request to "/assets/styles/chat.css"
        Then the response status should be 200
        And the response should contain ".welcome-screen"


