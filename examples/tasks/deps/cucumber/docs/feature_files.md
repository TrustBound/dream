# Writing Feature Files

Feature files are the heart of Cucumber testing. They're written in Gherkin syntax, a business-readable domain-specific language that lets you describe application behavior without detailing how that behavior is implemented.

## Feature File Structure

Feature files consist of several components:

### Feature

Every feature file starts with the `Feature:` keyword followed by a name and optional description:

```gherkin
Feature: Shopping Cart
  As a user
  I want to add items to my cart
  So that I can purchase them later
```

### Background

The `Background:` section contains steps that are executed before each scenario:

```gherkin
Background:
  Given I am logged in as a customer
  And the product catalog is available
```

### Scenarios

Scenarios are concrete examples of how the feature should behave:

```gherkin
Scenario: Adding an item to an empty cart
  Given I am on the product page for "Ergonomic Keyboard"
  When I click "Add to Cart"
  Then I should see "Item added to cart" message
  And my cart should contain 1 item
```

### Steps

Steps use keywords like `Given`, `When`, `Then`, `And`, and `But`:

- `Given`: Establishes preconditions
- `When`: Describes actions
- `Then`: Specifies expected outcomes
- `And`/`But`: Continues the previous step type

## Step Arguments

Gherkin supports several types of step arguments:

### Data Tables

```gherkin
Scenario: Adding multiple items to cart
  Given I have the following items in my cart:
    | Product Name    | Quantity | Price |
    | Smartphone      | 1        | 699.99|
    | Protection Plan | 1        | 79.99 |
  When I proceed to checkout
  Then the total should be 779.98
```

### Doc Strings

```gherkin
Scenario: Submit feedback
  When I submit the following feedback:
    """
    I really like your product, but I think
    it could be improved by adding more features.
    Keep up the good work!
    """
  Then my feedback should be recorded
```

## File Organization

Feature files should be placed in a `test/features/` directory and have a `.feature` extension. Organize them logically by feature or domain area:

```
test/
└── features/
    ├── authentication/
    │   ├── login.feature
    │   └── registration.feature
    ├── shopping/
    │   ├── cart.feature
    │   └── checkout.feature
    └── user_profile.feature
```

## Tags

Tags are used to categorize scenarios and can be used for filtering which tests to run:

```gherkin
@authentication @important
Feature: User Login

@happy_path
Scenario: Successful login with valid credentials
  Given I am on the login page
  When I enter valid credentials
  Then I should be logged in

@error_handling
Scenario: Failed login with invalid credentials
  Given I am on the login page
  When I enter invalid credentials
  Then I should see an error message
```

Tags can be used at the Feature level (applies to all scenarios) or at the Scenario level.

### Special Tags

#### @async

The `@async` tag enables concurrent test execution for features that don't share state:

```gherkin
@async
Feature: Independent Calculator Operations
  This feature can run concurrently with other async tests

Scenario: Addition
  Given I have a calculator
  When I add 5 and 3
  Then the result should be 8

Scenario: Multiplication
  Given I have a calculator
  When I multiply 4 and 7
  Then the result should be 28
```

Use `@async` only for features that:
- Don't share state with other tests
- Don't rely on test execution order
- Are truly independent of other tests

Note: Database tests can safely run async when using Ecto's SQL sandbox in shared mode. For non-Ecto resources (files, external APIs, etc.), ensure they can handle concurrent access.

## Best Practices for Feature Files

1. **Keep language simple and consistent** - Use clear, business-focused terminology
2. **One scenario per behavior** - Each scenario should test one specific behavior
3. **Be specific in examples** - Use concrete values rather than vague descriptions
4. **Use background wisely** - Only for steps that are truly common to all scenarios
5. **Limit scenario length** - If a scenario has many steps, consider breaking it down
6. **Organize with tags** - Use tags to categorize and group related scenarios
7. **Think like a user** - Write scenarios from the user's perspective
8. **Don't get too technical** - Avoid technical implementation details in Gherkin
