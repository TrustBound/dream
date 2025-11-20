/// <reference types="cypress" />

describe("Tasks Application", () => {
  beforeEach(() => {
    // Clear database and visit the main page before each test
    cy.exec("make db-reset", { cwd: "examples/tasks" });
    cy.visit("/");
  });

  describe("Task List Display", () => {
    it("should display the main tasks page", () => {
      cy.contains("h1", "My Tasks").should("be.visible");
      cy.get("#add-task-btn").should("be.visible");
      cy.get("#task-list").should("exist");
    });

    it("should show empty state when no tasks exist", () => {
      cy.get("article").should("not.exist");
    });
  });

  describe("Inline Task Creation", () => {
    it("should create new inline task via + button", () => {
      cy.get("#add-task-btn").click();
      
      // Inline editor should appear
      cy.get('article:has(input[name="title"])').should("be.visible");
      cy.get('input[name="title"]').should("have.focus");
      
      // Type and save
      cy.get('input[name="title"]').type("New Task{enter}");
      
      // Task should be created and new editor should appear
      cy.contains("article", "New Task").should("be.visible");
    });

    it("should create new inline task via Cmd+N keyboard shortcut", () => {
      cy.get("body").type("{meta}n");
      
      // Inline editor should appear
      cy.get('article:has(input[name="title"])').should("be.visible");
      cy.get('input[name="title"]').type("Keyboard Task{enter}");
      
      cy.contains("article", "Keyboard Task").should("be.visible");
    });

    it("should create task with all fields in inline editor", () => {
      cy.get("body").type("{meta}n");
      
      cy.get('input[name="title"]').type("Full Task");
      cy.get('textarea[name="description"]').type("Full description");
      cy.get('select[name="priority"]').select("1"); // Urgent
      cy.get('input[name="due_date"]').type("2025-12-31");
      
      // Save by pressing Enter in title field
      cy.get('input[name="title"]').type("{enter}");
      
      cy.contains("article", "Full Task").should("be.visible");
      cy.contains("Full description").should("be.visible");
      cy.contains("Urgent").should("be.visible");
    });

    it("should close editor with Escape key", () => {
      cy.get("body").type("{meta}n");
      cy.get('input[name="title"]').type("Task to close");
      cy.get('input[name="title"]').type("{esc}");
      
      // Editor should be closed (no input visible)
      cy.get('article:has(input[name="title"])').should("not.exist");
    });

    it("should create new task after selected task with Cmd+N", () => {
      // Create a task first
      cy.get("body").type("{meta}n");
      cy.get('input[name="title"]').type("First Task{enter}");
      cy.contains("article", "First Task").should("be.visible");
      
      // Click to select it
      cy.contains("article", "First Task").click();
      cy.contains("article", "First Task").should("have.attr", "data-selected", "true");
      
      // Press Cmd+N to create new task after selected one
      cy.get("body").type("{meta}n");
      
      // New inline editor should appear
      cy.get('article:has(input[name="title"])').should("be.visible");
    });
  });

  describe("Task Completion Toggle", () => {
    beforeEach(() => {
      // Create a task first
      cy.get("body").type("{meta}n");
      cy.get('input[name="title"]').type("Toggle Test Task{enter}");
    });

    it("should toggle task completion when checkbox is clicked", () => {
      cy.contains("article", "Toggle Test Task")
        .find('input[type="checkbox"]')
        .should("not.be.checked")
        .check();
      
      cy.contains("article", "Toggle Test Task")
        .find('input[type="checkbox"]')
        .should("be.checked");
    });

    it("should toggle back to incomplete", () => {
      cy.contains("article", "Toggle Test Task")
        .find('input[type="checkbox"]')
        .check()
        .uncheck();
      
      cy.contains("article", "Toggle Test Task")
        .find('input[type="checkbox"]')
        .should("not.be.checked");
    });
  });

  describe("Task Editing", () => {
    beforeEach(() => {
      // Create a task first
      cy.get("body").type("{meta}n");
      cy.get('input[name="title"]').type("Edit Test Task{enter}");
    });

    it("should open edit form when Edit button is clicked", () => {
      cy.contains("article", "Edit Test Task")
        .find("button")
        .contains("Edit")
        .click();
      
      // Edit form should be visible
      cy.get('input[name="title"]').should("have.value", "Edit Test Task");
    });

    it("should open edit form when task is double-clicked", () => {
      cy.contains("article", "Edit Test Task").dblclick();
      
      // Edit form should be visible
      cy.get('input[name="title"]').should("have.value", "Edit Test Task");
    });

    it("should update task when edit form is submitted", () => {
      cy.contains("article", "Edit Test Task")
        .find("button")
        .contains("Edit")
        .click();
      
      // Update fields
      cy.get('input[name="title"]').clear().type("Updated Task Title");
      cy.get('textarea[name="description"]').clear().type("Updated description");
      cy.get('select[name="priority"]').select("1");
      
      // Save by pressing Enter
      cy.get('input[name="title"]').type("{enter}");
      
      // Verify task was updated
      cy.contains("article", "Updated Task Title").should("be.visible");
      cy.contains("Updated description").should("be.visible");
      cy.contains("Urgent").should("be.visible");
    });

    it("should close editor with Escape key", () => {
      cy.contains("article", "Edit Test Task")
        .find("button")
        .contains("Edit")
        .click();
      
      cy.get('input[name="title"]').type("Unsaved Change{esc}");
      
      // Editor should be closed (back to card view)
      cy.contains("article", "Edit Test Task").should("be.visible");
      cy.contains("article", "Unsaved Change").should("not.exist");
    });
  });

  describe("Task Deletion", () => {
    beforeEach(() => {
      // Create a task first
      cy.get("body").type("{meta}n");
      cy.get('input[name="title"]').type("Delete Test Task{enter}");
    });

    it("should delete task when Delete button is clicked and confirmed", () => {
      cy.window().then((win) => {
        cy.stub(win, "confirm").returns(true);
      });
      
      cy.contains("article", "Delete Test Task")
        .find("button")
        .contains("Delete")
        .click();
      
      cy.contains("article", "Delete Test Task").should("not.exist");
    });

    it("should not delete task when confirmation is cancelled", () => {
      cy.window().then((win) => {
        cy.stub(win, "confirm").returns(false);
      });
      
      cy.contains("article", "Delete Test Task")
        .find("button")
        .contains("Delete")
        .click();
      
      cy.contains("article", "Delete Test Task").should("be.visible");
    });
  });

  describe("Task Selection", () => {
    beforeEach(() => {
      // Create multiple tasks
      cy.get("body").type("{meta}n");
      cy.get('input[name="title"]').type("Task 1{enter}");
      cy.get("body").type("{meta}n");
      cy.get('input[name="title"]').type("Task 2{enter}");
    });

    it("should select task when clicked", () => {
      cy.contains("article", "Task 1").click();
      cy.contains("article", "Task 1").should("have.attr", "data-selected", "true");
    });

    it("should deselect previous task when new task is clicked", () => {
      cy.contains("article", "Task 1").click();
      cy.contains("article", "Task 2").click();
      
      cy.contains("article", "Task 1").should("not.have.attr", "data-selected");
      cy.contains("article", "Task 2").should("have.attr", "data-selected", "true");
    });
  });

  describe("Projects Integration", () => {
    it("should navigate to projects page", () => {
      cy.visit("/projects");
      cy.contains("h1", "Projects").should("be.visible");
    });

    it("should create a new project", () => {
      cy.visit("/projects");
      cy.contains("button", "Create Project").click();
      
      // Project should appear in list
      cy.contains("article", "New Project").should("be.visible");
    });

    it("should display project details with tasks", () => {
      // Create a project via API
      cy.request("POST", "/projects").then((response) => {
        expect(response.status).to.eq(200);
        // Extract project ID from response or visit projects page to find it
        cy.visit("/projects");
        cy.contains("article", "New Project").should("be.visible");
        
        // Create a task for the project (we'll need to get the project ID)
        // For now, just verify the project page loads
        cy.contains("article", "New Project").click();
        cy.url().should("match", /\/projects\/\d+/);
      });
    });

    it("should create task within project context", () => {
      // Create a project via API
      cy.request("POST", "/projects").then(() => {
        cy.visit("/projects");
        cy.contains("article", "New Project").click();
        cy.url().should("match", /\/projects\/\d+/);
        
        // Extract project ID from URL
        cy.url().then((url) => {
          const projectId = url.match(/\/projects\/(\d+)/)?.[1];
          
          // Create task via + button
          cy.get("#add-task-btn").click();
          cy.get('input[name="title"]').type("Project Task{enter}");
          
          // Task should be created and associated with project
          cy.contains("article", "Project Task").should("be.visible");
          
          // Verify it's in the project (refresh to see)
          cy.reload();
          cy.contains("article", "Project Task").should("be.visible");
        });
      });
    });

    it("should delete a project", () => {
      // Create a project via API
      cy.request("POST", "/projects").then(() => {
        cy.visit("/projects");
        cy.contains("article", "New Project")
          .find("button")
          .contains("Delete")
          .click();
        
        cy.window().then((win) => {
          cy.stub(win, "confirm").returns(true);
        });
        
        cy.contains("article", "New Project").should("not.exist");
      });
    });
  });

  describe("Error Handling", () => {
    it("should display 404 for non-existent task", () => {
      cy.visit("/tasks/99999", { failOnStatusCode: false });
      cy.contains("h1", "Not Found").should("be.visible");
      cy.contains("Task not found").should("be.visible");
    });

    it("should display 404 for non-existent project", () => {
      cy.visit("/projects/99999", { failOnStatusCode: false });
      cy.contains("h1", "Not Found").should("be.visible");
      cy.contains("Project not found").should("be.visible");
    });
  });

  describe("Navigation", () => {
    it("should navigate between pages", () => {
      cy.visit("/");
      cy.contains("My Tasks").should("be.visible");
      
      cy.visit("/projects");
      cy.url().should("include", "/projects");
      
      cy.visit("/");
      cy.url().should("eq", Cypress.config().baseUrl + "/");
    });
  });
});
