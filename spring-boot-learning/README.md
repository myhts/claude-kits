# Spring Boot learning kit for Claude Code

Agents, skills and working rules that make Claude Code a **mentor and reviewer** while you build a Spring Boot 4
project yourself. An improved, learning-focused edition of
[piomin/claude-ai-spring-boot](https://github.com/piomin/claude-ai-spring-boot) (see `NOTICE.md` for every change).

## What's in it

| | Name | What it does |
|---|---|---|
| Agent | `mentor` | Explains with your own code, hint ladder when you're stuck, exercises, checks understanding. Doesn't edit. |
| Agent | `code-reviewer` | Reviews your diff after each feature: scenario, how to see it, principle, hint. Runs tests. Read-only. |
| Agent | `blind-reviewer` | Independent review with **no project knowledge**: reads only code, build files and config, works out the language, versions, architecture and domain, and checks against that stack's published best practices (cites the source). Read-only. Tied with `code-reviewer` in a measured comparison (`kit-check/reviewer-eval/`); they miss different things. |
| Agent | `security-reviewer` | Attack-scenario audit (access control first). Read-only. |
| Agent | `deploy-reviewer` | Explains and reviews Dockerfile, compose, CI, Kubernetes manifests. Never builds or applies. |
| Agent | `implementer` | **Does the work when you ask**: features, fixes, review findings, Dockerfile/compose/CI/K8s files. Tests and verifies, then hands over with an explanation and a sibling task. Only on explicit request. |
| Skill | `learning-loop` | The method: plan → primer → you build → see it work → review → explain back → record. `/learning-loop` |
| Skill | `spring-boot` | Boot 4 essentials and what changed from Boot 3 |
| Skill | `testing-patterns` | Which test for what; slices; Testcontainers 2; RestTestClient; concurrency tests |
| Skill | `jpa-patterns` | N+1, fetching, optimistic locking, self-invocation, each with a query-counting test |
| Skill | `transactions` | `@Transactional` as it really behaves: rollback rules, proxies (self-call, private, final), rollback-only, dirty checking, `@Async`, events, isolation, the wallet race and its 3 fixes. 18 proving tests |
| Skill | `distributed-systems` | Kafka keys/partitions, at-least-once + idempotent consumers, publish-after-commit vs outbox, poison, rebalancing, exactly-once trade-offs, Redis cache with a version guard, read-your-writes, Lua rate limiting, locks, sharding, consistency. Proven in EventStorm |
| Skill | `system-design` | The 45-minute shape, sizing, Little's law, a 1×/10×/100× capacity model, building blocks, 14 designs, the rubric, your project as the answer |
| Skill | `resilience-patterns` | Timeouts → retries with jitter → circuit breaker → bulkhead → rate limit → fallbacks |
| Skill | `logging-patterns` | Structured JSON logs, request id, propagation across threads and messages |
| Skill | `design-patterns` | A correct outbox, idempotent consumers, sagas, CQRS, and when GoF patterns help |
| Skill | `java-modern` | Records, sealed types + switch, virtual threads and their limits |
| Skill | `build-templates` | Verified Dockerfile, .dockerignore, compose, GitHub Actions CI, Kubernetes manifests (used by the implementer) |
| Skill | `interview-drill` | Interview questions about *your* code, with senior/staff feedback. `/interview-drill` |
| `--e2e` agent | `e2e-tester` | Plans, writes and repairs end-to-end tests; explores the running app with the Playwright MCP browser |
| `--e2e` skill | `e2e-testing` | Playwright + Testcontainers conventions: stack config, no sleeps, oracle tables, pinned known bugs, safety |
| Rules | `CLAUDE.md` | Learning mode: you write the code, Claude explains/reviews; ask before risky actions |
| Notes | `docs/learning/` | `LESSONS.md` (mistakes → rules) and `PROGRESS.md` (plan and what you can now explain) |

## Where it lives

```
ClaudeProjects/spring-boot-learning/   ← this folder: the source, kept outside any project
  kit/                                 ← exactly what gets copied into a project
  kit-e2e/                             ← added with --e2e: e2e/ template, e2e-testing skill, e2e-tester agent, .mcp.json
  install.sh                           ← copies kit/ into a project, never overwrites
  kit-check/                           ← proof: a Boot 4.1.1 project whose tests run the skills' code
```

Inside a project it lands at project level, not in `~/.claude`: these skills are Spring-specific and would
otherwise load in every project you open.

```
your-project/
  CLAUDE.md                     working agreement (fill in the last section)
  .claude/agents/*.md           6 agents
  .claude/skills/*/SKILL.md     13 skills (build-templates also has its template files)
  docs/learning/LESSONS.md, PROGRESS.md
```

## Apply it to a new project

```bash
# 1. Create the project (start.spring.io, or your own skeleton): Java 21, Maven, Spring Boot 4.x
# 2. Preview, then install (from the ClaudeProjects folder)
./spring-boot-learning/install.sh ~/code/my-new-app --dry-run
./spring-boot-learning/install.sh ~/code/my-new-app          # add --e2e for end-to-end tests
# 3. Fill in the "This project" section at the end of CLAUDE.md
# 4. Start learning
cd ~/code/my-new-app && claude
> /learning-loop
```

If the project already has a `CLAUDE.md`, the kit's rules are written to `CLAUDE.learning.md` for you to merge.
Re-running the installer adds only what's missing (`--force` overwrites, after you've checked the diff).

## Daily use

- **Start a session:** `/learning-loop` (reads your progress and lessons, proposes the next step).
- **Stuck or curious:** "ask the mentor why my query runs 4 times" (or just ask; Claude picks the skill).
- **Feature done:** "use the code-reviewer agent on my changes". For an independent view: "use the blind-reviewer
  on my changes" (give it only the scope; it ignores any description). For important changes, run both.
- **Before a release / after adding auth:** "use the security-reviewer agent".
- **Wrote a Dockerfile or manifests:** "use the deploy-reviewer agent".
- **Want it done for you:** "use the implementer to add the compose file", "use the implementer to apply review
  finding 2". It only runs when you name it, and lists what it built in `docs/learning/PROGRESS.md`.
- **Practice:** `/interview-drill`.
- **Go deeper once it runs:** `/project-explorer` (your personal skill) for the map, debugging flows and labs.

## Verified, and how to re-check

The code shapes in `spring-boot`, `testing-patterns`, `jpa-patterns`, `transactions`, `resilience-patterns`,
`logging-patterns` and the outbox in `design-patterns` run as tests in `kit-check/` on Spring Boot 4.1.1, Java 21,
Hibernate 7, Testcontainers 2, Resilience4j 2.4.0 (35 tests, green on 2026-10-20; the 18 transaction tests were
stable over 5 repeated runs). `distributed-systems` names the tests in EventStorm (the author's private example project) that prove each pattern. After a Spring Boot upgrade:

```bash
cd spring-boot-learning/kit-check
# bump the parent version in pom.xml, then:
./mvnw verify          # Docker must be running
```

Fix whatever fails, then update the skill text to match.

The `build-templates` files are checked by `kit-check/verify-templates.sh`: it builds the image from the template
Dockerfile, runs it with the template compose file on 127.0.0.1 ports, calls the API, checks the user, JVM flags
and shutdown, removes everything it created, and validates the Kubernetes manifests (kubeconform) and the CI
workflow (actionlint) offline. The manifests are never applied to a cluster, and the CI workflow hasn't run on GitHub.

The `--e2e` part is checked by `kit-check/verify-e2e.sh`: it installs the kit with `--e2e` into a copy of kit-check,
builds the image from the installed Dockerfile, runs Playwright against the Testcontainers stack (an API flow test),
checks that a stale image is refused under `E2E_STRICT_IMAGES=1`, and removes everything. The browser side was
proven on EventStorm, the private example project (UI + API + oracle, 340/340 on a 20× repeat run).

Not covered by tests: the agents' behaviour, and the prose advice in `java-modern` and `interview-drill`.

## Sharing

Commit `.claude/`, `CLAUDE.md` and `docs/learning/` in the project and everyone who opens it with Claude Code gets
the same setup. To share the kit itself, put this folder in a git repository; keep `LICENSE` and `NOTICE.md`
(Apache 2.0 requires both).
