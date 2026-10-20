# Notice

This kit is derived from **claude-ai-spring-boot** by Piotr Mińkowski
(https://github.com/piomin/claude-ai-spring-boot, commit `a5d33af`, 2026-10-16), licensed under the
Apache License 2.0. A copy of the license is in `LICENSE`.

## What changed

Rewritten for **learning by building** rather than generating an app, and checked against Spring Boot 4.1.1.

Removed:
- `spring-boot-engineer` agent (it writes the whole app for you) and `devops-engineer` agent (CircleCI-specific).
- `CLAUDE.md` project rules that are personal preferences (always latest dependency versions, CircleCI,
  `pl.piomin.services`, a README update and version bump on every change).
- `.claude/settings.local.json` (it pre-approved `git commit`, `docker exec` and `docker-compose down`).

Changed:
- `code-reviewer`: read-only; teaches through findings (scenario, how to see it, principle, hint); respects the
  project's chosen architecture; checks data integrity and concurrency; knows the Boot 4 test packages.
- `security-engineer` → `security-reviewer`: read-only, attack-scenario based, access control first.
- `docker-expert` + `kubernetes-specialist` → `deploy-reviewer`: read-only, explains runtime behaviour, never
  builds or applies.
- `spring-boot`, `testing-patterns`: fixed for Boot 4 (`@MockitoBean` instead of the removed `@MockBean`, new test
  slice packages, `RestTestClient`, Testcontainers 2, Jackson 3, `resilience4j-spring-boot4`); problem-details
  handling that doesn't race Boot's own handler.
- `jpa-patterns`: each pitfall shown with a query-counting test.
- `design-patterns`: the outbox example fixed (wait for broker acks before marking, `FOR UPDATE SKIP LOCKED`,
  `LIMIT`, `MANDATORY` propagation, at-least-once noted) and verified by tests; idempotent consumer added; sagas
  with compensation; CQRS with read-your-writes.
- `logging-patterns`: request id with input sanitising, propagation across threads, virtual threads and messages.
- `java-modern`: virtual threads' limits (downstream bottlenecks, pinning on 21–23 vs 24+, consumers).

Added:
- `implementer` agent: the original's code-generating role (spring-boot-engineer, docker-expert, devops-engineer,
  kubernetes-specialist), used only on explicit request, following the project's own conventions, with tests,
  verification, a teaching hand-over, a record in PROGRESS.md, and hard limits (no commits, deploys or secrets).
- `--e2e` (kit-e2e/): end-to-end testing with Playwright Test + Testcontainers (stack config, image freshness guard,
  localhost-only host guard, `stack:up` for repeated runs), the `e2e-testing` skill, the `e2e-tester` agent and a
  Playwright MCP config limited to localhost. Patterns first proven in a real project's suite.
- `transactions` skill with 18 proving tests in `kit-check` (`TransactionTrapsTest`); `distributed-systems` and
  `system-design` skills, generalised from the tested code and interview material of EventStorm, the author's private example project.
- `blind-reviewer` agent: reviews with no project context (`omitClaudeMd`, no skills, no docs), from a fingerprint of
  the stack it reads off the build files, against published best practices with cited sources. Compared with
  `code-reviewer` in `kit-check/reviewer-eval/` (3 runs each, blind grading): a draw, so both are kept.
- `build-templates` skill: Dockerfile, compose, GitHub Actions CI and Kubernetes manifests, built/run/validated.
- `mentor` agent, `learning-loop`, `resilience-patterns` and `interview-drill` skills.
- `docs/learning/LESSONS.md` and `PROGRESS.md` templates, `install.sh`.
- `kit-check/`: a Spring Boot 4.1.1 project whose tests prove the code shown in the skills.
