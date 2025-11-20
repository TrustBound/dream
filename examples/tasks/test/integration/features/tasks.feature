Feature: Tasks API

    Background:
        Given the server is running on port 3000
        And I clear all test tables

    # Task CRUD Operations
    Scenario: List tasks when empty
        When I send a GET request to "/"
        Then the response status should be 200
        And the response should contain "My Tasks"
        And there should be 0 tasks in the database

    Scenario: Create a task and verify it persists
        When I send a POST request to "/tasks" with form data "title=New%20Task&description=Task%20description&priority=2"
        Then the response status should be 200
        And the response should contain "New Task"
        And the task with id 1 should exist in the database with title "New Task"
        And there should be 1 tasks in the database

    Scenario: Create task and verify it appears in list
        Given I send a POST request to "/tasks" with form data "title=First%20Task&description=First&priority=1"
        And I send a POST request to "/tasks" with form data "title=Second%20Task&description=Second&priority=2"
        When I send a GET request to "/"
        Then the response status should be 200
        And the response should contain "First Task"
        And the response should contain "Second Task"
        And there should be 2 tasks in the database

    Scenario: Get task by ID returns correct task
        Given a task exists with title "Specific Task"
        When I send a GET request to "/tasks/1"
        Then the response status should be 200
        And the response should contain "Specific Task"

    Scenario: Get non-existent task returns 404
        When I send a GET request to "/tasks/999"
        Then the response status should be 404

    Scenario: Update task and verify changes persist
        Given a task exists with title "Original Title"
        When I send a PUT request to "/tasks/1.htmx" with form data "title=Updated%20Title&description=Updated%20description&priority=1"
        Then the response status should be 200
        And the response should contain "Updated Title"
        And the task with id 1 should exist in the database with title "Updated Title"

    Scenario: Toggle task completion changes state
        Given a task exists with title "Toggle Test"
        And the task with id 1 should not be completed
        When I send a POST request to "/tasks/1/toggle"
        Then the response status should be 200
        And the task with id 1 should be completed
        When I send a POST request to "/tasks/1/toggle"
        Then the response status should be 200
        And the task with id 1 should not be completed

    Scenario: Reorder task updates position
        Given a task exists with title "Position Test"
        And the task with id 1 should have position 1
        When I send a POST request to "/tasks/1/reorder" with form data "position=5"
        Then the response status should be 200
        And the task with id 1 should have position 5

    Scenario: Delete task removes it from database
        Given a task exists with title "To Delete"
        And there should be 1 tasks in the database
        When I send a DELETE request to "/tasks/1"
        Then the response status should be 204
        And the task with id 1 should not exist in the database
        And there should be 0 tasks in the database

    Scenario: Delete non-existent task returns 404
        When I send a DELETE request to "/tasks/999"
        Then the response status should be 404

    # Projects
    Scenario: List projects when empty
        When I send a GET request to "/projects"
        Then the response status should be 200

    Scenario: Create project and verify it persists
        When I send a POST request to "/projects"
        Then the response status should be 200
        And the response should contain "New Project"

    Scenario: Get project by ID
        Given a project exists with name "Test Project"
        When I send a GET request to "/projects/1"
        Then the response status should be 200
        And the response should contain "Test Project"

    Scenario: Delete project
        Given a project exists with name "To Delete"
        When I send a DELETE request to "/projects/1"
        Then the response status should be 204

    # Tags
    Scenario: List tags returns JSON array
        When I send a GET request to "/tags"
        Then the response status should be 200
        And the response header "Content-Type" should be "application/json"
        And the response should be valid JSON
        And the JSON response should be an array with 0 items

    Scenario: Create tag and verify it appears in list
        Given a tag exists with name "Important"
        When I send a GET request to "/tags"
        Then the response status should be 200
        And the response should be valid JSON
        And the JSON response should be an array with 1 items
        And there should be 1 tags in the database

    Scenario: Add tag to task creates relationship
        Given a task exists with title "Tagged Task"
        And a tag exists with name "Important"
        When I send a POST request to "/tasks/1/tags" with form data "tag_id=1"
        Then the response status should be 200
        And the task with id 1 should have tag with id 1

    Scenario: Create and add tag to task in one operation
        Given a task exists with title "New Tag Task"
        When I send a POST request to "/tasks/1/tags/create" with form data "tag_name=Urgent"
        Then the response status should be 200
        And there should be 1 tags in the database
        And the task with id 1 should have tag with id 1

    Scenario: Remove tag from task removes relationship
        Given a task exists with title "Tagged Task"
        And a tag exists with name "Important"
        And tag "1" is attached to task "1"
        And the task with id 1 should have tag with id 1
        When I send a DELETE request to "/tasks/1/tags/1"
        Then the response status should be 200
        And the task with id 1 should not have tag with id 1

    Scenario: Remove non-existent tag from task returns 404
        Given a task exists with title "Test Task"
        When I send a DELETE request to "/tasks/1/tags/999"
        Then the response status should be 404

    # Error Cases
    Scenario: Create task with missing required field uses defaults
        When I send a POST request to "/tasks" with form data "title=Minimal%20Task"
        Then the response status should be 200
        And the response should contain "Minimal Task"
        And the task with id 1 should exist in the database with title "Minimal Task"

    Scenario: Update non-existent task returns 404
        When I send a PUT request to "/tasks/999.htmx" with form data "title=Updated"
        Then the response status should be 404

    Scenario: Toggle non-existent task returns 404
        When I send a POST request to "/tasks/999/toggle"
        Then the response status should be 404

    # Static Files
    Scenario: Serve CSS file
        When I send a GET request to "/public/styles.css"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/css"

    Scenario: Serve non-existent static file returns 404
        When I send a GET request to "/public/nonexistent.css"
        Then the response status should be 404
