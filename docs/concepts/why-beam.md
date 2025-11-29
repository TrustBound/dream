# Why the BEAM?

**Understanding the runtime that powers Dream.**

## What is the BEAM?

BEAM (Bogdan/Björn's Erlang Abstract Machine) is the virtual machine that runs Erlang, Elixir, and Gleam code. Like the JVM for Java or V8 for JavaScript, but designed for completely different goals.

The JVM was built for portability. V8 was built for speed.

**The BEAM was built for reliability and concurrency.**

## History

Ericsson created Erlang and the BEAM in the 1980s for telecom switches. The requirements:
- Handle millions of concurrent phone calls
- Never go down (99.9999999% uptime—"nine nines")
- Recover from failures without restarting
- Hot-swap code without dropping connections

Turns out, those are the exact problems web applications have.

## What You Get on the BEAM

### Concurrency

Millions of lightweight processes per server. Each HTTP request gets its own isolated process. No thread pools, no async/await gymnastics, no event loop bottlenecks. Just spawn a process. The BEAM's preemptive scheduler handles the rest.

### Fault Tolerance

Processes crash in isolation. One request throws an error, the rest keep running. No cascading failures. No servers going down because one database query hung.

### Scalability

Start with one server. Add more when traffic grows. The BEAM distributes processes across machines transparently. No architectural rewrite from monolith to microservices required to scale.

## Real-World Results

- **WhatsApp**: 2.8 million concurrent connections per server on Erlang [1]
- **Discord**: 12M+ concurrent users, 26M WebSocket events/sec on Elixir with ~5 engineers maintaining 20+ services [2]
- **Bleacher Report**: Reduced from ~150 servers to ~8, 10× faster updates, 200M push notifications/day [3]
- **Pinterest**: 14,000 notifications/sec, reduced from 30 to 15 servers for their notification service [4]
- **BBC**: Elixir serving almost all BBC web and app traffic [5]
- **Remote**: Grew from zero to unicorn (~$3B valuation) in ~2 years with Elixir as the primary backend [6]

## And Gleam?

Gleam gives you the BEAM's superpowers with modern developer experience:

- **Type safety** - Catch bugs at compile time, not in production
- **Modern syntax** - No learning Erlang's Prolog-style syntax
- **Functional programming** - Immutable by default, easier to reason about
- **Erlang/Elixir interop** - Use 30+ years of battle-tested BEAM libraries

The BEAM handles concurrency, fault tolerance, and scaling. Gleam gives you type safety and readability. You write functions.

It's a pretty good division of labor.

## "But You Can't Hire for Gleam"

True. The Gleam job market is tiny. So is Elixir's compared to Python or JavaScript.

But here's what you can hire for:
- **Strong engineers** who can learn (Gleam's syntax takes a day)
- **Functional programming experience** (Gleam is simpler than Scala, Haskell, or even Elixir)
- **BEAM experience** (Elixir and Erlang developers are productive in Gleam immediately)
- **Type system familiarity** (TypeScript, Rust, Go developers get it)

**And here's the thing about good engineers:** They don't want to work on boring problems with mundane tools. They definitely don't want to work with something shoehorned into being a solution it's not great at (looking at you, Node.js for CPU-intensive work).

Good engineers want to learn new things. They want to work on interesting tech. They just don't want to spend a year learning the borrow checker before they can be productive (sorry, Rust).

Gleam hits the sweet spot:
- Interesting (functional, type-safe, runs on the BEAM)
- New (fresh approach, modern syntax)
- Not overwhelming (learn the basics in a weekend, productive in a week)

Discord runs 20+ Elixir services with 5 engineers serving 12M+ concurrent users [2]. Remote reached unicorn status in ~2 years with Elixir [6]. Strand ships production Gleam with zero Gleam-related crashes and a small team [7].

Your choice: hire 20 engineers to manage microservices hell in the "safe" language, or hire 5 who actually want to use the BEAM and solve problems instead of fighting infrastructure.

## References

[1]: https://www.erlang-factory.com/upload/presentations/558/efsf2012-whatsapp-scaling.pdf "WhatsApp Scaling - Erlang Factory"  
[2]: https://elixir-lang.org/blog/2020/10/08/real-time-communication-at-scale-with-elixir-at-discord/ "Real time communication at scale with Elixir at Discord"  
[3]: https://www.erlang-solutions.com/case-studies/bleacher-report-case-study/ "Bleacher Report Case Study - Erlang Solutions"  
[4]: https://venturebeat.com/dev/pinterest-elixir/ "Pinterest's Elixir adoption - VentureBeat"  
[5]: https://www.elixirconf.eu/talks/how-elixir-powers-the-bbc-from-poc-to-production-at-scale/ "How Elixir powers the BBC - ElixirConf EU"  
[6]: https://elixir-lang.org/blog/2025/01/21/remote-elixir-case/ "Remote: growing from zero to unicorn with Elixir"  
[7]: https://gleam.run/case-studies/strand "Optimising for maintainability - Gleam in production at Strand"

