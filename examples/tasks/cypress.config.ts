import { defineConfig } from "cypress";

export default defineConfig({
  e2e: {
    baseUrl: "http://localhost:3000",
    viewportWidth: 1920,
    viewportHeight: 1080,
    video: true,
    videoCompression: 32,
    screenshotOnRunFailure: true,
    screenshotsFolder: "cypress/screenshots",
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000,
    specPattern: "cypress/e2e/**/*.cy.{js,jsx,ts,tsx}",
    supportFile: "cypress/support/e2e.ts",
    setupNodeEvents(on, config) {
      // implement node event listeners here
      on("before:browser:launch", (browser, launchOptions) => {
        // Remove problematic Chrome flags on macOS
        if (browser.family === "chromium") {
          const argsToRemove = ["--no-sandbox", "--disable-dev-shm-usage"];
          launchOptions.args = launchOptions.args.filter(
            (arg) => !argsToRemove.includes(arg)
          );
        }
        return launchOptions;
      });

      // Take screenshot after each test (pass or fail)
      on("after:screenshot", (details) => {
        console.log("Screenshot taken:", details.path);
      });
    },
  },
  env: {
    // Environment variables can be overridden in cypress.env.json
  },
  retries: {
    runMode: 0, // No retries - fail fast
    openMode: 0,
  },
  chromeWebSecurity: false,
  // Force headless mode
  headless: true,
});

