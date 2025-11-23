Feature: Streaming Capabilities API

    Background:
        Given the server is running on port 3000

    # Ingress Streaming (Upload)
    Scenario: Upload small file via streaming endpoint
        When I send a POST request to "/upload" with body "Hello, World!"
        Then the response status should be 200
        And the response should contain "Uploaded"
        And the response should contain "bytes successfully"

    Scenario: Upload empty body via streaming endpoint
        When I send a POST request to "/upload" with body ""
        Then the response status should be 200
        And the response should contain "Uploaded 0 bytes successfully"

    Scenario: Upload large data via streaming endpoint
        When I send a POST request to "/upload" with body containing 10000 bytes
        Then the response status should be 200
        And the response should contain "Uploaded"
        And the response should contain "bytes successfully"
        And the uploaded bytes count should be 10000

    # Egress Streaming (Download)
    Scenario: Download streamed data
        When I send a GET request to "/download"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/plain"
        And the response should contain "Line 1"
        And the response should contain "Line 1000"
        And the response should contain exactly 1000 lines

    Scenario: Download streamed data has correct format
        When I send a GET request to "/download"
        Then the response status should be 200
        And the response should start with "Line 1"
        And each line should match pattern "Line \\d+"

    # Bi-Directional Streaming with Middleware
    Scenario: Echo transform with middleware converts input to uppercase and spaces to underscores
        When I send a POST request to "/echo_transform" with body "hello world"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/plain"
        And the response should be "HELLO_WORLD"

    Scenario: Echo transform with middleware handles multiple words
        When I send a POST request to "/echo_transform" with body "this is a test"
        Then the response status should be 200
        And the response should be "THIS_IS_A_TEST"

    Scenario: Echo transform with middleware handles empty input
        When I send a POST request to "/echo_transform" with body ""
        Then the response status should be 200
        And the response should be ""

    Scenario: Echo transform with middleware handles special characters
        When I send a POST request to "/echo_transform" with body "test 123 !@#"
        Then the response status should be 200
        And the response should be "TEST_123_!@#"

    # Proxy Streaming
    Scenario: Proxy endpoint returns streamed data
        When I send a GET request to "/proxy"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/plain"
        And the response should contain "Proxying data"
        And the response should contain "From upstream"
        And the response should contain "To client"

    # Error Cases
    Scenario: Upload without body accepts empty stream
        When I send a POST request to "/upload" without body
        Then the response status should be 200
        And the response should contain "Uploaded 0 bytes successfully"

    Scenario: Echo transform without body accepts empty stream
        When I send a POST request to "/echo_transform" without body
        Then the response status should be 200
        And the response should be ""

    Scenario: Non-existent endpoint returns 404
        When I send a GET request to "/nonexistent"
        Then the response status should be 404

