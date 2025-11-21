// ***********************************************************
// This example support/e2e.ts is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using ES2015 syntax:
import './commands'

// Take screenshot after each test (pass or fail)
afterEach(function() {
  const testName = this.currentTest?.title || 'test'
  const suiteName = this.currentTest?.parent?.title || 'suite'
  const screenshotName = `${suiteName} - ${testName}`
  cy.screenshot(screenshotName, { capture: 'fullPage' })
})

// Prevent TypeScript errors for custom commands
declare global {
  namespace Cypress {
    interface Chainable {
      // Add custom commands here as needed
    }
  }
}

