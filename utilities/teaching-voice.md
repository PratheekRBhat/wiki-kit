# Teaching Voice

Reference guide for the voice and style used on topic pages. Every agent writing to `wiki/<topic>.md` should re-read this before writing.

**This is load-bearing.** The wiki exists so you can *learn*, not so you can read a textbook cold. Dense does not mean dry. The voice should feel like a senior practitioner at a whiteboard with you — direct, curious, a little wry — not like a bootcamp tutorial, a Stack Overflow top answer, or a paper abstract wearing a fake mustache.

The worked examples below use software engineering concepts as stand-ins; the *shape* of each pattern transfers to whatever the actual source is about.

## Open with a hook, not a definition

The first sentence of a topic page decides whether the reader continues.

**Bad — starts with the definition:**

> Dependency injection is a design technique in which an object receives other objects that it depends on, rather than constructing them internally.

Correct. Forgettable. The reader has already stopped reading.

**Good — starts with the problem, earns the definition:**

> Try writing a test for a class that news up a database connection in its constructor. You can't — every test now talks to Postgres. The fix is to pass the connection in from outside, so tests can pass a fake and production passes the real one. That's the whole idea of dependency injection; everything else (containers, constructor vs setter injection, scopes) is machinery around this one move.

Same definition, but the reader now cares. The motivation *is* the opening.

## Motivate every claim — show the stakes

A claim without stakes is trivia. A claim with stakes teaches a tradeoff.

**Bad:**

> Rust prevents data races at compile time.

True. So what?

**Good:**

> In Go, sharing a map between two goroutines without a mutex compiles, runs, and mostly works — until one day it panics in production with "fatal error: concurrent map writes". In Rust, the equivalent program fails to compile; the borrow checker sees two `&mut` references to the same `HashMap` alive at the same time and refuses. The stakes: Go trades a class of runtime bugs for development speed and GC pauses; Rust trades compile-time friction and a learning curve for the guarantee that those specific bugs can't happen.

Now the reader understands *what the choice buys* and *what it costs*.

## Trace the mechanism, don't just name it

Naming a mechanism is the first move, not the last one. Walk through a small, concrete trace that lets the reader *feel* what happens.

**Bad:**

> Go's garbage collector uses a concurrent tri-colour mark-sweep algorithm with write barriers.

**Good:**

> When the GC starts, every reachable object is conceptually one of three colours:
>
> - **White** — not yet seen; collector will free at end of cycle.
> - **Grey** — seen, but its children haven't been scanned yet.
> - **Black** — fully scanned; children are grey or black.
>
> Roots start grey. The collector picks a grey object, blackens it, and greys its children. When no grey remains, every white is garbage.
>
> The trick: mutator goroutines keep running during this. If one writes `a.next = b` while the GC is running, and `a` is black but `b` is white, the GC would miss `b`. The *write barrier* intercepts that store and greys `b` — cheap and surgical, costing a few instructions on every pointer write but keeping pause times sub-millisecond.

The reader now has the right mental model. You could wake them up at 3am and they could redraw it.

## Show the code when it earns its place

A 5-line snippet with before/after beats three paragraphs of prose.

**Bad:**

> Structural pattern matching in Python 3.10 allows matching against the shape of data rather than its value, enabling concise destructuring.

**Good:**

```python
match response:
    case {"status": 200, "body": body}:
        return body
    case {"status": status} if status >= 500:
        raise ServerError(status)
    case {"status": status}:
        raise ClientError(status)
    case _:
        raise MalformedResponse()
```

> One statement does the shape check, the value guard, *and* the destructuring. The `if` guard is the detail most tutorials miss — it turns pattern matching from "glorified switch" into "concise dispatcher with real predicates."

## Ground in a real thing

Abstract concepts without a real-world anchor don't compound. Every concept page lands in at least one real, named language, framework, system, tool, or workload.

**Bad:**

> Immutable data structures make concurrent code easier to reason about.

**Good:**

> Clojure's persistent vectors are the canonical example: every "modification" returns a new vector, but shares most of its internal tree with the old one via hash-array-mapped tries. An `assoc` on a 1M-element vector allocates ~32 new nodes, not 1M. This is what makes Clojure's STM practical — transactions can capture a reference to a vector, mutate the "new" version repeatedly, and atomically compare-and-swap the root pointer on commit, all without copying.

## Earn the tradeoff

Every tradeoff page must answer "under what conditions does each option win?". Vague tradeoffs are worse than no tradeoffs.

**Bad:**

> Monorepos trade complexity for coordination.

**Good:**

> Monorepos win when the cost of coordinated changes across services is high and you're willing to invest in build-graph tooling (Bazel, Nx, Turborepo) that only rebuilds what changed. Polyrepos win when teams need autonomous release cycles, dependencies across services are loose enough that coordinated changes are rare, and the overhead of per-repo CI/CD outweighs the cost of the occasional cross-repo migration. The forcing functions: team count, build-graph size, release cadence. Google, Meta, and Shopify went monorepo; Netflix and Amazon went polyrepo. Both patterns support orgs of 10K+ engineers; the difference is in what you automate.

## Tribal-debate topics: even-handed, not neutral

Many domains have "religious war" topics. Topic pages must stay even-handed *without* going mush-mouthed:

- Present both sides' best-faith reasoning.
- Separate factual claims from preference claims. Call out which is which.
- Name real teams / codebases / practitioners that went each way, and what bit them.
- It's fine for a page to stay unresolved — "This is genuinely a taste call" is a legitimate conclusion.

Never let a single opinionated source dictate a topic page's voice. If a source has a hot take, it lives on the *source card*. The topic page extends from it in a more even register.

## Voice

- **Practitioner, not professor.** "Here's the trick" beats "The underlying mechanism exploits...". Contractions are fine. A dry aside is fine. Don't write like you're being graded.
- **Short sentences when the idea is heavy.** Let the reader breathe between beats.
- **Use analogies, sparingly.** A good analogy is a shortcut to the right mental model. A stretched analogy is a liability — bail out before it breaks.
- **Show the "aha".** If a source has a moment where the whole topic clicks, capture *that specific moment* on the topic page. Readers come back for the aha.

## Voice anti-patterns (don't)

- Marketing / hype words: "blazing fast", "cutting edge", "best-in-class", "game-changing". Banned.
- Throat-clearing: "It is important to note that...", "In this section, we will discuss...". Just say the thing.
- Definition-first openings: "Git is a distributed version control system that...". Start with why it matters.
- Sourceless superlatives: "the most popular", "the de facto standard". Either cite it or drop the claim.
- Hedge words. "Generally", "in most cases", "often" — use sparingly; they hide unexamined claims.
- Bullet walls. If a section is 10+ consecutive bullets, it's a list, not an explanation.
- Empty section scaffolds ("## Further Reading" with two items, "## Conclusion" restating the above). Cut.
- "We" / "you" overuse. A well-placed "you" lands. Every-paragraph "you" reads like a tutorial video.
- Paper-abstract voice. Don't mimic the source's framing; rewrite it in the voice a teammate would use at a whiteboard.
- Tribal hot takes. Opinionated single-source takes don't belong on topic pages even when a source makes them. Capture the source's take on the source card; write the topic page even-handedly.
- Bootcamp voice. Avoid "Don't worry, this is easy!" and "Now let's dive in!". The reader is not a beginner; treat them like the practitioner they are.

## What "good" looks like

A good topic page should feel like one of these:
- **A 3am message** from a smart teammate who's just figured something out and wants to show you the trace.
- **A cold-open whiteboard walk** — first sentence is the problem, last sentence is the thing the reader wants to remember.
- **The best design-doc intro you've read** — short on ceremony, generous with intuition, honest about what's still open.

If the page feels like a tutorial or a Wikipedia stub, rewrite the opening.
