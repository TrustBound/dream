Feature: Multi Format Example

    Background:
        Given the server is running on port 3000
        And the database is clean

    Scenario: GET products endpoint returns HTML list
        When I send a GET request to "/products"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/html"

    Scenario: GET products.json endpoint returns valid JSON array
        When I send a GET request to "/products.json"
        Then the response status should be 200
        And the response header "Content-Type" should be "application/json"
        And the response should be valid JSON
        And the JSON response should be an array

    Scenario: GET products.csv endpoint returns valid CSV
        When I send a GET request to "/products.csv"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/csv"
        And the response should contain CSV headers

    Scenario: GET product by id endpoint returns HTML
        When I send a GET request to "/products/1"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/html"

    Scenario: GET product.json endpoint returns valid JSON object
        When I send a GET request to "/products/1.json"
        Then the response status should be 200
        And the response header "Content-Type" should be "application/json"
        And the response should be valid JSON
        And the JSON response should be an object

    Scenario: GET product.htmx endpoint returns HTMX partial
        When I send a GET request to "/products/1.htmx"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/html"

    Scenario: GET product.csv endpoint returns valid CSV
        When I send a GET request to "/products/1.csv"
        Then the response status should be 200
        And the response should contain CSV headers

    Scenario: GET non-existent product returns 404
        When I send a GET request to "/products/999"
        Then the response status should be 404

    Scenario: GET non-existent product.json returns 404
        When I send a GET request to "/products/999.json"
        Then the response status should be 404

    Scenario: JSON response contains expected product fields
        When I send a GET request to "/products/1.json"
        Then the response status should be 200
        And the response should be valid JSON
        And the JSON response should be an object
        And the JSON response should contain field "id"
        And the JSON response should contain field "name"

    Scenario: CSV response contains comma-separated values
        When I send a GET request to "/products/1.csv"
        Then the response status should be 200
        And the response should contain ","

