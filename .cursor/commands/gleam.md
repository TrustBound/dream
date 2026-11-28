# Gleam on the BEAM

This is a Gleam application running on the BEAM (Erlang VM). Every solution must use the correct patterns for this platform. Solutions designed for other architectures (Node.js event loops, Go goroutines, Rust async, JVM threading, etc.) are not acceptable, even if they "work."

## The Standard

There is one correct way to solve most problems on the BEAM. Find it. Use it. Do not settle for a solution that merely functions — it must be idiomatically correct for Gleam/Erlang/OTP.

Before proposing any solution that involves concurrency, state management, fault tolerance, or inter-process communication, ask yourself: **"How would an experienced Erlang/OTP engineer solve this?"** Then find the Gleam equivalent.

## Platform Primitives (Use These)

### Processes and Actors

The BEAM's unit of concurrency is the lightweight process. State lives in processes, not in shared mutable memory.

- **Use `gleam_otp` actors** (`gleam/otp/actor`) for stateful services. Actors are the correct way to hold mutable state — not closures, not mutable references, not global variables.
- **Use `gleam_erlang` subjects and selectors** for message passing between processes.
- **Every long-lived stateful component should be an actor.** Caches, connection pools, rate limiters, session stores, background workers — these are all actors.
- **Never share state between processes via anything other than message passing.** No shared memory. No locks. No mutexes. This is not that kind of platform.

### Supervision Trees

Processes crash. That is expected and correct on the BEAM.

- **Use supervisors** (`gleam/otp/supervisor`) to manage process lifecycles. Every actor that matters should be supervised.
- **Design for failure.** "Let it crash" is not negligence — it is the architecture. Supervisors restart failed processes with known-good state.
- **Think about restart strategies.** One-for-one, one-for-all, rest-for-one — pick the right one for the failure domain.
- **Never try/catch your way out of a process crash.** Let the supervisor handle it. Recovery logic belongs in `init`, not in error handlers wrapped around every call.

### ETS (Erlang Term Storage)

ETS tables are the correct solution for shared read-heavy state that multiple processes need to access concurrently.

- **Use ETS for caches, lookup tables, and read-heavy shared state.** ETS provides concurrent reads without bottlenecking through a single actor's mailbox.
- **Do not use ETS as a general-purpose database.** It is in-memory and not persisted across restarts (unless you specifically set that up with DETS or manual persistence).
- **Owner process matters.** An ETS table is owned by the process that created it. If that process dies, the table is destroyed. Plan accordingly — typically the supervisor or a dedicated table-owner process should create tables.

### Process Links and Monitors

- **Use monitors** when you need to know if another process dies but don't want to die with it.
- **Use links** when processes should fail together.
- Understand the difference. Using the wrong one causes either silent failures or unnecessary cascading crashes.

## Erlang FFI

Gleam runs on the BEAM and can call Erlang directly. This is a strength, not a workaround.

- **Use Erlang FFI when Gleam lacks a wrapper** for BEAM functionality you need (e.g., `:ets`, `:timer`, `:crypto`, specific OTP behaviors).
- **Write thin FFI wrappers** — the Erlang code should be minimal, with the logic and types living in Gleam.
- **Always provide type-safe Gleam interfaces** over raw FFI calls. Never expose raw Erlang terms to calling code.
- **FFI is for platform access, not for bypassing Gleam's type system.** If you find yourself using FFI to work around Gleam's constraints, you are likely solving the wrong problem.

## Anti-Patterns (Never Do These)

- **Never use polling loops** where you should use process messaging or monitors.
- **Never use a single process as a bottleneck** for state that could live in ETS for concurrent reads.
- **Never spawn unsupervised processes** for anything that matters. If a process does real work, it belongs in a supervision tree.
- **Never store state in module-level variables or closures** pretending to be singletons. State belongs in actors.
- **Never implement your own process registry** when Erlang's built-in registry or `gproc`-style solutions exist.
- **Never use GenServer-style synchronous calls** when a cast (async message) would suffice and the caller doesn't need the result.
- **Never treat BEAM processes like OS threads.** They are cheap. Spawn thousands. Don't pool them like heavyweight threads.
- **Never reach for an external dependency** (Redis, a message queue, an in-memory cache library) when the BEAM already provides the primitive. ETS is your cache. Processes are your workers. Message passing is your queue.

## Decision Framework

When solving a problem, evaluate in this order:

1. **Can a pure function solve this?** No state, no processes needed. Just transform data. This is always preferred.
2. **Does this need state?** → Actor. Use `gleam/otp/actor`.
3. **Does this state need to survive crashes?** → Supervised actor with init-time recovery.
4. **Do multiple processes need to read this state concurrently?** → ETS table, owned by a supervised process.
5. **Does this need to react to process lifecycle events?** → Monitors or links.
6. **Does this need periodic work?** → Actor with `erlang.send_after` or `:timer` via FFI. Not a polling loop.
7. **Does this need to coordinate multiple actors?** → Supervisor tree with appropriate restart strategy.
8. **Does Gleam lack a wrapper for the BEAM feature I need?** → Erlang FFI with a type-safe Gleam wrapper.

## What "Correct" Means

A correct solution on this platform:

- Uses processes for isolation and concurrency, not threads or async/await
- Uses message passing for communication, not shared memory
- Uses supervisors for fault tolerance, not try/catch
- Uses ETS for shared read-heavy state, not a cache actor bottleneck
- Uses the existing BEAM ecosystem before reaching for external tools
- Compiles to idiomatic BEAM bytecode that an Erlang veteran would recognize as reasonable
