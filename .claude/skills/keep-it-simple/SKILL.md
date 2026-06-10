---
name: keep-it-simple
description: Guardrail against over-engineering. Use at the START of any task that involves writing or refactoring code, designing a fix, or proposing an implementation — before generating the solution.
---

# Keep It Simple

This is a single-maintainer hobby OS, not a platform team's monorepo. Every
line added is a line the maintainer must understand at 2am when a build
breaks. Optimise for *deletability*, not extensibility.

## Before writing any code, answer these

1. What is the smallest diff that solves the stated problem?
2. Can an existing function/pattern/manifest absorb this instead of a new one?
3. Is any part of my plan solving a problem that wasn't asked about?
   If yes — cut it, or mention it in one sentence at the end instead.

## Hard limits

- **No new abstractions** (wrapper functions, config layers, plugin systems,
  generic frameworks) unless the user explicitly asked for one.
- **No speculative flexibility** — no "in case you later want to..."
  parameters, no handling of inputs that cannot occur.
- **No drive-by refactors.** Fix the thing asked. Note other issues in one
  line; do not touch them.
- **>30 lines or >2 files → stop.** Present a ≤5-line plan and wait.
- **Error handling proportionate to consequence**: a cosmetic step gets
  `|| log_warning`, not a retry framework.

## Smells that mean you are overcomplicating

- A helper function with exactly one call site.
- An if/else ladder for cases the build can never produce.
- Introducing a new file when 10 lines in an existing one would do.
- Rewriting working code to be "cleaner" while fixing an unrelated bug.
- Explaining the solution takes longer than reading the diff.

When in doubt, ship the boring version. The clever version can always be
requested; the boring version rarely needs to be reverted.
