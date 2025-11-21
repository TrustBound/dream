/// <reference types="cypress" />

describe('Tasks Application - Simple Test', () => {
  it('should load the main page', () => {
    cy.visit('/')
    cy.contains('My Tasks').should('be.visible')
  })
})

