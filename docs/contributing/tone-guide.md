# Documentation Tone Guide

This guide defines the voice, tone, and style for Dream documentation. It's for contributors writing or reviewing docs.

---

## Our Philosophy

Dream's documentation should be:

1. **Helpful** - Exists to accomplish tasks, not showcase cleverness
2. **Honest** - Acknowledge tradeoffs and limitations
3. **Respectful** - Of readers' time and of other tools

---

## Voice by Document Type

### README & Marketing

**Audience:** Skeptics evaluating Dream  
**Goal:** Make the case for Dream  
**Tone:** Confident, opinionated, specific

✅ **Do:**
- Make strong claims backed by evidence
- Use memorable, concrete examples
- Show working code quickly
- Include real-world metrics and case studies
- Be honest about tradeoffs
- Use strategic snark to build connection with battle-tested engineers

❌ **Don't:**
- Disparage other tools without specifics
- Use vague superiority claims ("better," "faster" without context)
- Be snarky about common pain points in ways that feel punching down

**Examples:**

✅ **Good (specific, memorable):**
```markdown
The BEAM was built for massive concurrency and fault tolerance. 
WhatsApp handles 2.8M connections per server. Discord serves 
12M+ concurrent users with a 5-person team.
```

✅ **Good (strategic snark):**
```markdown
Because finding where that database connection came from 
shouldn't require a treasure map.
```

✅ **Good (honest about tradeoffs):**
```markdown
Gleam is young. The ecosystem is small. You won't find a package 
for everything. But you get types that actually work and a runtime 
built for the web.
```

❌ **Avoid (vague negativity):**
```markdown
Tired of Node.js falling over? Python too slow? Dream actually 
works in production.
```

❌ **Avoid (attacking users):**
```markdown
If you're still using JavaScript, you're doing it wrong.
```

---

### Quickstart & Getting Started

**Audience:** New users trying Dream for first time  
**Goal:** Working code in a few minutes  
**Tone:** Direct, encouraging, minimal explanation

✅ **Do:**
- Show working code immediately
- Minimal explanation before code
- Clear "what to expect" statements
- Link to deeper explanations

❌ **Don't:**
- Explain concepts before showing code
- Assume prior Gleam knowledge
- Skip any setup steps
- Use snark or jokes

**Example:**

✅ **Good:** Show code immediately, explain briefly after:
```markdown
Create your project:

> gleam new hello_dream
> gleam add dream

Replace src/hello_dream.gleam with [complete working example]

Run: gleam run
Visit http://localhost:3000

Explanation: This creates a router, defines a controller, 
and starts a server. [Link to concepts]
```

❌ **Avoid:** Long explanations before showing any code:
```markdown
Before we begin, it's important to understand that Dream 
uses a composable architecture based on...

[10 minutes of explanation]

Now let's write some code.
```

---

### Tutorials

**Audience:** People learning by building  
**Goal:** Step-by-step understanding  
**Tone:** Patient teacher, zero snark

✅ **Do:**
- Show complete working code each step
- Explain what after showing the code
- Explain why after explaining what
- Use consistent formatting
- Recap what was learned
- Encourage and guide

❌ **Don't:**
- Make jokes about common mistakes
- Skip "obvious" steps
- Use sarcasm or snark
- Editorialize about other approaches
- Make learners feel inadequate

**Example:**

✅ **Good:**
````markdown
Step 3: Create the Model

In `src/models/user.gleam`, add a function that gets one user:

### Get a user by ID <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/models/user.gleam#L24-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn get(db: pog.Connection, id: Int) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

This function:
1. Takes a database connection explicitly (no globals)
2. Calls the generated SQL function
3. Converts the database row to our domain type
4. Returns a Result for error handling

**Why explicit parameters?** Without them, you'd need globals 
or process dictionary, neither of which are type-safe in Gleam.
````

❌ **Avoid:**
```markdown
Unlike Rails where you have no idea where your DB connection 
comes from, we pass it explicitly like adults:

`pub fn get(db: Connection, id: Int) -> Result(User, Error)`

See? Not that hard.
```

---

### Guides (How-To)

**Audience:** Developers solving specific problems  
**Goal:** Working solution quickly  
**Tone:** Direct, practical, copy-paste ready

✅ **Do:**
- Start with problem statement
- Complete working examples
- Note common pitfalls
- Link to related docs
- Be straightforward and helpful

❌ **Don't:**
- Philosophize before showing code
- Require reading other guides first
- Bury the solution
- Use snark or sarcasm

**Example:**

✅ **Good:**
```markdown
# Authentication with JWT

This guide shows you how to add JWT authentication to your Dream app.

You'll implement:
- Login endpoint that issues tokens
- Middleware that verifies tokens
- Custom context that holds the authenticated user

## Prerequisites
- [Custom context](../guides/routing.md) understanding
- `gleam add jwt` installed

## Step 1: Define your context

[Complete, working code]
```

---

### API Reference

**Audience:** Looking up specific function/type  
**Goal:** Quick lookup  
**Tone:** Technical, precise, zero personality

✅ **Do:**
- Type signature first
- One-sentence description
- Minimal working example
- Document parameters and return values
- Note any panics or errors

❌ **Don't:**
- Add jokes or commentary
- Explain concepts (link to guides instead)
- Be verbose
- Use any snark

**Example:**

✅ **Good:**

#### Document match_path <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/tone_guide_api_reference.gleam#L8-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Match a path against a pattern and extract parameters.
///
/// Returns the extracted parameters if the path matches the pattern,
/// or `None` if it doesn't.
///
/// ## Examples
///
/// ### Match a user path <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/tone_guide_api_reference_example.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import gleam/option.{type Option}
/// import snippets/tone_guide_api_reference.{match_path}
///
/// pub fn match_user_path() -> Option(List(#(String, String))) {
///   match_path("/users/:id", "/users/123")
///   // -> Some([#("id", "123")])
/// }
/// ```
pub fn match_path(
  pattern: String,
  path: String,
) -> Option(List(#(String, String))) {
  let pattern_segments = string.split(pattern, "/")
  let path_segments = string.split(path, "/")
  case list.strict_zip(pattern_segments, path_segments) {
    Ok(segment_pairs) -> collect_params(segment_pairs, [])
    Error(Nil) -> None
  }
}
```

❌ **Avoid:**

#### Document match_path with jokes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/tone_guide_api_reference_avoid.gleam#L8-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// This is how Dream's router works its magic! Well, not magic
/// really - just good old-fashioned pattern matching. You give
/// it a pattern like "/users/:id" and it'll extract that :id
/// for you. Pretty neat, huh?
```

---

### Comparison & Positioning

**Audience:** Evaluating Dream vs alternatives  
**Goal:** Help make informed decision  
**Tone:** Honest, specific, fair, strategic snark allowed

✅ **Do:**
- State what Dream is good at
- State what Dream is NOT good at
- Compare on specific dimensions
- Be fair to alternatives
- Use strategic snark to acknowledge shared frustrations
- Make positive cases, not just negative ones

❌ **Don't:**
- Trash talk other tools as inherently bad
- Make Dream sound perfect for everything
- Use vague claims
- Cherry-pick comparisons
- Attack users of other tools

**Examples:**

✅ **Good (specific comparison):**
```markdown
### Type Safety
- **Dream:** Compile-time verification via Gleam's type system
- **Phoenix:** Runtime verification with Dialyzer specs
- **Tradeoff:** Dream catches parameter mismatches at compile time, 
  Phoenix offers faster prototyping with macros
```

✅ **Good (honest about ecosystem):**
```markdown
### Ecosystem
- **Dream:** New, small ecosystem (2024)
- **Phoenix:** Mature, large ecosystem (2014+)
- **Reality:** Phoenix has more libraries and community resources. 
  Dream has simpler interop and fewer concepts to learn.
```

✅ **Good (strategic snark about tools, not users):**
```markdown
### Developer Experience
How many times have you learned authentication? Not the concept—
the framework's way of doing it. The Rails Way. The Django Way. 
The Spring Way. Knowledge that evaporates when you switch stacks.

Dream teaches patterns, not framework-specific solutions.
```

✅ **Good (acknowledging shared pain):**
```markdown
Webpack configs that could run Kubernetes. "undefined is not a 
function" in production. Framework magic that works until you need to 
debug it. If you've been there, you'll appreciate Dream's 
explicit approach.
```

❌ **Avoid (attacking users):**
```markdown
Phoenix developers don't understand type safety. Node.js 
programmers are lazy. If you're still using Rails, you're behind.
```

---

## Using Snark Effectively

### When Snark Works

**In positioning and comparison docs**, snark can build connection with experienced engineers by acknowledging shared frustrations:

✅ **Shared pain (specific):**
> You've spent more time configuring webpack than writing features. 
> You've debugged cryptic stack traces in production. You know 
> the pain.

✅ **Tool criticism (not user criticism):**
> Framework magic: powerful when it works, opaque when you need 
> to debug it.

✅ **Self-aware humor:**
> Yes, Gleam is young. No, we don't have a package for everything. 
> But we have types, and they actually work.

✅ **Acknowledging real tradeoffs:**
> Node.js will let you ship fast and crash often. The BEAM makes 
> you think about errors upfront and then run for months. Pick 
> your poison.

### When Snark Doesn't Work

❌ **In tutorials (makes learners feel inadequate):**
> ~~Unlike Rails where you have no idea where dependencies come from...~~

❌ **Attacking users (alienates potential contributors):**
> ~~If you're still using JavaScript, you're doing it wrong.~~

❌ **Vague negativity (unhelpful):**
> ~~Other frameworks are just bad.~~

❌ **In error messages or troubleshooting (frustrating when stuck):**
> ~~Well, that didn't work. Maybe try reading the docs?~~

### The Test

Before using snark, ask:

**"Would this make someone who uses [that tool] feel stupid or defensive?"**

- If yes → rewrite
- If no → probably fine

**Additional check:**

**"Is this punching up (at systems/tools) or punching down (at people)?"**

- Punching up → okay
- Punching down → not okay

---

## Writing Guidelines

### Code Examples

**All code must be:**
- ✅ Complete (runnable as-is or clearly marked as partial)
- ✅ Tested (actually runs without errors)
- ✅ Formatted (use `gleam format`)
- ✅ Minimal (no unnecessary complexity)

**Format:**

````markdown
Create `src/example.gleam`:

### Create an empty router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/tone_guide_code_example.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Complete, working code here
import dream/router.{type Router, router}

pub fn create_router() -> Router(context, services) {
  router()
}
```

This code does X by doing Y.
````

### Explanations

**Structure:**
1. Show the code
2. Explain what it does
3. Explain why it matters
4. Link to deeper concepts

**Example:**

````markdown
### Get a user by ID <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/models/user.gleam#L24-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn get(db: pog.Connection, id: Int) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

This function takes a database connection explicitly as a parameter.

**Why explicit parameters?** Without them, you'd need globals or 
process dictionary, neither of which are type-safe in Gleam.

See [Build a database-backed JSON API](../guides/database-api.md) for more on Services and [Route requests and add middleware](../guides/routing.md) for custom context.
````

### Headings

Use consistent heading levels:

- `#` - Page title (one per page)
- `##` - Major sections  
- `###` - Subsections
- `####` - Rarely needed

### Links

**Do:**
- ✅ Link to other docs when mentioning concepts
- ✅ Use descriptive link text
- ✅ Use relative paths within docs
- ✅ Test that links work

**Don't:**
- ❌ Use "click here" or "this link"
- ❌ Link to external sites that might break
- ❌ Leave broken links

**Good:**
```markdown
See [Route requests and add middleware](../guides/routing.md) for details.
```

**Bad:**
```markdown
Click [here](../guides/routing.md) for more info.
```

---

## Common Pitfalls

### ❌ The Defensive Rant

```markdown
Unlike literally every other web framework that forces you to 
learn their bizarre DSL and hides everything behind macros and 
dependency injection containers...
```

### ✅ Make Your Case Positively

```markdown
Dream uses explicit function parameters for dependencies. This 
means you can trace exactly where your database connection comes 
from by reading the code.
```

---

### ❌ The Inside Joke

```markdown
Remember the last time Rails' autoloader failed you? Yeah, we 
don't do that here. 😎
```

### ✅ State Benefits Clearly

```markdown
Dream has no autoloading. All imports are explicit at the top 
of each file. This makes code easier to navigate and prevents 
load-order issues.
```

---

### ❌ Vague Claims

```markdown
Dream is more scalable and provides better developer experience.
```

### ✅ Specific and Measurable

```markdown
Dream runs on the BEAM, which can handle millions of concurrent 
connections per server. The type system catches parameter 
mismatches at compile time rather than in production.
```

---

### ❌ Burying the Code

```markdown
## Understanding Models

In Dream, models follow the repository pattern, which is a 
well-established architectural pattern from Domain-Driven Design...

[5 paragraphs later]

Here's an example:
```

### ✅ Code First, Explain After

````markdown
## Models

Here's a typical model:

### Get a user by ID <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/models/user.gleam#L24-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn get(db: pog.Connection, id: Int) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

This is the repository pattern: functions that handle data access 
and return domain types.
````

---

## Review Checklist

Before submitting documentation, check:

### Tone
- [ ] Would this be helpful when I'm frustrated and stuck?
- [ ] Did I avoid snark in tutorials and how-tos?
- [ ] If I used snark, is it punching up (at tools) not down (at people)?
- [ ] Am I being fair to alternatives?
- [ ] Is this helpful first, clever never?

### Content
- [ ] Can someone skim this and get value?
- [ ] Most important information first?
- [ ] Code examples complete and runnable?
- [ ] Explained why, not just what?
- [ ] Links work and point to real files?

### Technical
- [ ] Code actually runs?
- [ ] Code is formatted (`gleam format`)?
- [ ] Spelling and grammar checked?
- [ ] Appropriate tone for document type?

---

## Questions to Ask When Reviewing

Use these to evaluate any documentation:

1. **Is this true?** No exaggerations or unverified claims
2. **Is this helpful?** Does it help accomplish something?
3. **Is this fair?** Honest about tradeoffs?
4. **Is this clear?** Understandable without prior Dream knowledge?
5. **Is this kind?** Makes people feel welcome?

---

## Goals

Dream's documentation should make readers feel:

✅ **Capable** - "I can build this"  
✅ **Informed** - "I understand how this works"  
✅ **Confident** - "This is the right tool for my needs"

Not:

❌ **Defensive** - "Why are you attacking my stack?"  
❌ **Inadequate** - "I'm not smart enough for this"  
❌ **Sold to** - "Stop marketing at me"

---

## When in Doubt

**Be helpful. Be honest. Be kind.**

A little strategic snark in the right place builds connection with battle-tested engineers. But the goal is always to help someone accomplish something, not to showcase how clever we are.

---

## See Also

- [Contributing Index](index.md) - Overview of documentation contributing
- [contributing.md](contributing.md) - Code contribution guidelines
- [Design Principles](../reference/design-principles.md) - Dream's philosophy

