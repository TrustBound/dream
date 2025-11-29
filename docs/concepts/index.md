# Concepts

High-level concepts and mental models for building with Dream. These docs explain **how Dream works** and how to structure applications, not step-by-step tasks or API minutiae.

Use this section when you want to understand the system, not just copy a snippet.

---

## Understanding Dream

- [Dream vs Mist](dream-vs-mist.md)  
  What Dream provides on top of Mist and when to use each.

- [Architecture](architecture.md)  
  How Dream's components fit together: routers, middleware, context, services, and the request lifecycle.

- [Design Principles](design-principles.md)  
  The philosophy behind Dream's design: library not framework, explicit over implicit, simple over clever.

- [Why the BEAM?](why-beam.md)  
  The runtime advantages of building web applications on the BEAM (Erlang VM).

## Request Lifecycle

- [How It Works](how-it-works.md)  
  End-to-end walkthrough of what happens to a request in Dream, from arrival at the server through routing, middleware, controllers, and response.

## Project & Code Structure

- [Project Structure](project-structure.md)  
  How to lay out a real Dream application: where controllers, models, views, operations, services, and templates live, and how they relate.

## Core Patterns

- [Core Patterns](patterns.md)  
  Catalog of key patterns: router + thin controllers, context & services, middleware "onion", MVC, operations, multi-format responses, auth, streaming, WebSockets, templates, and testing.

## Deeper Dives

- [Dream Concepts (overview)](../concepts.md)  
  Narrative, long-form explanation of all the major Dream components with inline examples.

---

**Where to go next:**

- Need concrete "how do I do X?" recipes? → See the [Guides](../guides/).
- Need exact behavior and API guarantees? → See the [Reference](../reference/).
- Want a linear tutorial path? → Follow the [Learning Path](../learn/).
