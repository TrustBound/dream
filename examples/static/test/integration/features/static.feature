Feature: Static Example

    Background:
        Given the server is running on port 3000

    Scenario: GET public root serves index.html with correct content type
        When I send a GET request to "/public/"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/html"
        And the response should contain "<html"

    Scenario: GET public styles.css serves CSS file with correct content type
        When I send a GET request to "/public/styles.css"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/css"
        And the response should contain "font-family"

    Scenario: GET public images cat.svg serves SVG file with correct content type
        When I send a GET request to "/public/images/cat.svg"
        Then the response status should be 200
        And the response header "Content-Type" should be "image/svg+xml"

    Scenario: GET assets data.json serves JSON file with correct content type
        When I send a GET request to "/assets/data.json"
        Then the response status should be 200
        And the response header "Content-Type" should be "application/json"

    Scenario: GET images cat.svg with extension filter serves SVG file
        When I send a GET request to "/images/cat.svg"
        Then the response status should be 200
        And the response header "Content-Type" should be "image/svg+xml"

    Scenario: GET path traversal attempt is blocked
        When I send a GET request to "/public/../../../etc/passwd"
        Then the response status should be 404

    Scenario: GET non-existent file returns 404
        When I send a GET request to "/public/nonexistent.html"
        Then the response status should be 404

    Scenario: GET assets data.json returns correct JSON content
        When I send a GET request to "/assets/data.json"
        Then the response status should be 200
        And the response header "Content-Type" should be "application/json"
        And the response should be valid JSON
        And the JSON response should contain field "message"

    Scenario: GET public index.html returns HTML content
        When I send a GET request to "/public/"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/html"
        And the response should contain "<html"
        And the response should contain "</html>"

