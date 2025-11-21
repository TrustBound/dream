/// <reference types="cypress" />

// ***********************************************
// This example commands.ts shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

/**
 * Wait for HTMX request to complete
 * Just a small delay - Cypress auto-waits for network requests
 */
Cypress.Commands.add('waitForHtmx', () => {
  // Cypress automatically waits for network requests
  // Just a small delay for DOM updates
  cy.wait(300)
})

/**
 * Wait for HTMX swap to complete
 * Useful after form submissions or button clicks
 */
Cypress.Commands.add('waitForHtmxSwap', (selector?: string) => {
  // Cypress automatically waits for network requests
  // Just a small delay for DOM updates
  cy.wait(300)
})

// Prevent TypeScript errors
declare global {
  namespace Cypress {
    interface Chainable {
      /**
       * Wait for HTMX request to complete
       * @example cy.waitForHtmx()
       */
      waitForHtmx(): Chainable<void>
      
      /**
       * Wait for HTMX swap to complete
       * @example cy.waitForHtmxSwap('#task-list')
       */
      waitForHtmxSwap(selector?: string): Chainable<void>
    }
  }
}

export {}

