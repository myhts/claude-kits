# claude-kits handbook: everything beyond the flow

**The flow** (plan the language → Event Storming → test-first build → a small PR → two reviewer agents → your review →
you merge → GitHub Actions → Kubernetes) has its own visual guide: **[PIPELINE.md](PIPELINE.md)**. Start there.

This handbook covers everything else:
- the stack packs and add-ons
- the learning kit for practice projects
- each agent and skill, one by one
- the proofs
- how Claude Code loads all this
- how to improve the toolkit safely

Last updated 2026-11-01.

**Contents:** [1. What exists](#1-what-exists) · [2. Quick starts](#2-quick-starts) ·
[3. The pieces, one by one](#3-the-pieces-one-by-one) · [4. Workflows](#4-workflows-step-by-step) ·
[5. Applying it elsewhere](#5-applying-it-to-other-situations) · [6. Improving the toolkit](#6-improving-the-toolkit) ·
[7. How Claude Code loads all this](#7-how-claude-code-loads-all-this-facts-worth-knowing) ·
[8. Troubleshooting](#8-troubleshooting) · [9. Ground rules](#9-ground-rules) · [10. Proofs](#10-proofs) ·
[11. What's ours and what's adopted](#11-whats-ours-and-whats-adopted)

---

## 1. What exists

### The plugins

| Plugin | For | Adds |
|---|---|---|
| `pipeline` | every project | The flow's commands (`/setup-project`, `/grill-with-docs`, `/wayfinder`, `/to-spec`, `/to-tickets`, `/implement`, `/human-review`, `/deploy`, `/retro`, `/next`), the skills they load (`event-storming`, `tdd`, `codebase-design`, `diagnosing-bugs` and more), the core skills (`system-design`, `distributed-systems`, `design-patterns`, `resilience-patterns`, `learning-loop`, `interview-drill`, `project-explorer`), seven agents, and the merge guard |
| `spring` | Spring Boot 4 | `spring-boot`, `testing-patterns`, `transactions`, `jpa-patterns`, `java-modern`, `java-concurrency`, `logging-patterns`, the Spring review checklist, and the build templates: Dockerfile, CI, a Kustomize base with staging and prod overlays, and the deploy workflow |
| `e2e` | apps with a UI or flows | Playwright tests against the app and its databases in Testcontainers, the `e2e-tester` agent, and the Playwright MCP (localhost only) |
| `spring-ai` | Spring services that call Claude | `llm-engineering` and the review checklist the reviewers use for model calls |
| `spring-web` | a front end for a Spring API | a React + Vite + TanStack Query template and the `react-frontend` skill |

Add one to a repo with `claude plugin install <name>@kits --scope project`. For a Spring Boot repo,
`/pipeline:setup-project` does it for you.

### Everything in the repository

| Piece | Where | What it's for |
|---|---|---|
| **`setup.sh`** | repo root | One-time: checks your tools, and removes the `/project-explorer` link older versions put in `~/.claude/skills/` |
| **`new-project.sh`** | repo root | Creates a Spring Boot 4 project from start.spring.io and installs the kit into it (`--pipeline`: enables the plugins instead of copying) |
| **The plugin marketplace** `kits` | `.claude-plugin/marketplace.json` | `pipeline` (stages, agents, core skills, merge guard), `spring`, `e2e`, `spring-ai`, `spring-web`: the same files as the kits, loaded as plugins. See [PIPELINE.md](PIPELINE.md) |
| **The pipeline kit** | `spring-boot-learning/kit-pipeline/` | `/setup-project`, `/implement`, `/human-review`, `/deploy`, `/next`, `event-storming`; 15 skills copied unchanged from mattpocock/skills (`upstream/`); the 6 stack-neutral agents, `spring-security-reviewer` and 7 core skills, `project-explorer` among them; the merge guard hook |
| **The learning kit** | `spring-boot-learning/` | 7 agents and 7 core skills (kept in `kit-pipeline/`), 8 Spring skills (`kit/`), a working agreement, progress/lesson files; `install.sh` copies them into any project |
| **The e2e add-on** (`--e2e`) | `spring-boot-learning/kit-e2e/` | Playwright + Testcontainers end-to-end tests, the `e2e-tester` agent, the `e2e-testing` skill, the Playwright MCP |
| **The AI add-on** (`--ai`) | `spring-boot-learning/kit-ai/` | The `llm-engineering` skill (Claude through the Java SDK: structured outputs, prompt injection, stop reasons, citations, caching, cost, evals, synthetic data, a review checklist, a CI eval job), `CLAUDE.ai.md` rules, and with `--e2e` a WireMock fake of the model for e2e runs |
| **The web add-on** (`--web`) | `spring-boot-learning/kit-web/` | A React + Vite + TanStack Query template in `web/` (nginx image proxying `/api`) and the `react-frontend` skill |
| **kit-check** | `spring-boot-learning/kit-check/` | A Spring Boot 4.1.1 app whose tests prove the code in the skills (35 + 23 for the LLM shapes, against a local fake API); scripts that verify the templates and the e2e, AI and web add-ons |
| **The reviewer evaluation** | `spring-boot-learning/kit-check/reviewer-eval/` | A repeatable method for comparing two agent versions (blind grading), and its first result |
| **The explorer evaluation** | `spring-boot-learning/kit-check/explorer-eval/` | Which model should read the code for `/project-explorer`: an answer key taken from the code, a scoring script, usage per model, and its first result |
| **`/project-explorer`** | `spring-boot-learning/kit-pipeline/skills/project-explorer/` (in the `pipeline` plugin as `/pipeline:project-explorer`; copy installs get it too) | Turns any codebase into an interactive architecture explorer with debug walkthroughs, guides and optional scaling labs |
| **EventStorm** | the author's private example project | Where these were built and proven: explorer + Study path tab, e2e suite, `CLAUDE.md`, the agents in use. Referenced below; not needed to use anything here, and not public |

### The agents (6 in the kit, plus 1 with `--e2e`)

| Agent | Writes code? | Tools | Use it when |
|---|---|---|---|
| `mentor` | No | Read, Grep, Glob, Bash | You're stuck or curious; you want an explanation with your own code, a hint, an exercise |
| `code-reviewer` | No | Read, Grep, Glob, Bash | A feature is done: a review on two axes, the project's standards (coding standards, the pack's checklist, the glossary, code smells) and the ticket's spec. Uses the project's context; teaches in learn mode (scenario, how to see it, principle, hint) |
| `blind-reviewer` | No | Read, Grep, Glob, Bash, WebFetch, WebSearch | You want an **independent** review: no project docs or CLAUDE.md, only code; checks against the stack's published best practices with sources |
| `security-reviewer` | No | Read, Grep, Glob, Bash | Before a release or after adding auth, in any language: attack scenarios, access control first |
| `spring-security-reviewer` | No | Read, Grep, Glob, Bash | The same for a Spring Boot app: knows its annotations, configuration and actuator |
| `deploy-reviewer` | No | Read, Grep, Glob, Bash | You wrote a Dockerfile, compose, CI or Kubernetes files, in any language: memory, shutdown and probes per runtime |
| `implementer` | **Yes**, only when named | Read, Write, Edit, Bash, Glob, Grep | You want something **done for you**: a feature, a fix, a review finding, build files |
| `e2e-tester` (`--e2e`) | Tests only, when asked | all (inherits the MCP browser) | Plan, write, repair or de-flake end-to-end tests; explore the running app in a browser |

### The skills (15 in the kit, plus 1 with `--e2e`)

| Skill | Covers | Proof |
|---|---|---|
| `/learning-loop` | The method: plan → primer → you build → see it work → review → explain back → record | |
| `/interview-drill` | Interview questions about your own code, senior/staff feedback, scored | |
| `/project-explorer` | Any codebase as an interactive map: request flows step by step with real data and verified breakpoints, debugger configs, guides, optional scaling labs ([3.8](#38-project-explorer)) | its README says what was tested |
| `spring-boot` | Boot 4 essentials and what changed from Boot 3 | kit-check |
| `testing-patterns` | Which test for what; slices; Testcontainers 2; RestTestClient | kit-check |
| `jpa-patterns` | N+1, fetching, optimistic locking, self-invocation, with query counting | kit-check (5 tests) |
| `transactions` | `@Transactional` as it really behaves: rollback rules, proxies, rollback-only, dirty checking, `@Async`, events, isolation, the check-then-act race and 3 fixes | kit-check (18 tests) |
| `resilience-patterns` | Timeouts → retries with jitter → breaker → bulkhead → rate limit → fallback | kit-check |
| `logging-patterns` | JSON logs, request id across threads and messages | kit-check |
| `design-patterns` | A correct outbox, idempotent consumers, sagas, CQRS | kit-check (outbox) |
| `distributed-systems` | Kafka keys/partitions, at-least-once + idempotency, poison, rebalancing, exactly-once trade-offs, Redis with a version guard, read-your-writes, Lua rate limiting, locks, sharding, consistency | tests in the private example project, named in the skill |
| `system-design` | The 45-minute shape, sizing, Little's law, 1×/10×/100× capacity, building blocks, 14 designs, rubric, your project as the answer | method |
| `java-modern` | Records, sealed types, virtual threads and their limits | |
| `java-concurrency` | Thread states, the memory model (visibility, happens-before, safe publication), testing concurrent code; grows section by section | kit-check (9 tests) |
| `build-templates` | Dockerfile, .dockerignore, compose, GitHub Actions CI, Kubernetes manifests | `verify-templates.sh` |
| `e2e-testing` (`--e2e`) | The e2e stack config, waiting without sleeps, oracles, pinned known bugs, the MCP | `verify-e2e.sh` |

### The MCP server

| Server | Configured in | What it does | Limits |
|---|---|---|---|
| Playwright MCP (`@playwright/mcp@0.0.83`) | the project's `.mcp.json` (with `--e2e`) | Gives Claude a real browser: open pages, click, read the accessibility tree, take screenshots | `--isolated`, `--allowed-origins "http://localhost:*;http://127.0.0.1:*"`. That stops accidents; it is **not** a security boundary |

---

## 2. Quick starts

### A new Spring Boot project (5 minutes)

```bash
git clone https://github.com/myhts/claude-kits.git && cd claude-kits
./setup.sh                            # once: checks your tools
./new-project.sh my-shop --e2e        # Boot 4.1.1, Java 21, Postgres, JPA, Flyway, Testcontainers + e2e
cd my-shop
# 1. open CLAUDE.md, fill in "This project" at the end (what it is, architecture, what you want to learn)
# 2. git init && git add -A && git commit -m "Start"   (so every change after this is visible)
claude
> /learning-loop
```

Options: `--java 25`, `--boot 4.0.8`, `--group com.yourname`, `--deps "web,validation,data-jpa,postgresql,flyway,actuator,testcontainers,kafka"`.
Needs the internet (start.spring.io).

### The learning kit in an existing project

For the delivery flow in an existing project, in any language, see
[PIPELINE.md, An existing project](PIPELINE.md#an-existing-project). To add the learning kit instead:

```bash
./spring-boot-learning/install.sh ~/code/their-project --dry-run   # from this repo: see what would be added
./spring-boot-learning/install.sh ~/code/their-project [--e2e]
```

It never overwrites. If the project already has a `CLAUDE.md`, the kit's goes to `CLAUDE.learning.md` (merge the parts
you want). An existing `.mcp.json` gets `.mcp.e2e.json` next to it. With `--e2e` and no Dockerfile, the tested one is
added.

### The delivery pipeline on any project (any language)

```bash
cd ~/code/any-repo
claude plugin marketplace add myhts/claude-kits --scope project
claude plugin install pipeline@kits --scope project
claude
> /pipeline:project-explorer          # in a codebase that already exists: see how it works first
> /pipeline:setup-project
```

Then follow [PIPELINE.md](PIPELINE.md).

### Only understand a codebase (any language)

```bash
cd ~/code/any-repo && claude
> /pipeline:project-explorer          # with the pipeline plugin; in a copy install, /project-explorer
```

Without either, copy `spring-boot-learning/kit-pipeline/skills/project-explorer/` into the repo's `.claude/skills/`.
Where it fits in the flow: [PIPELINE.md, An existing project](PIPELINE.md#an-existing-project).

### Only an independent review (any project)

Copy `spring-boot-learning/kit-pipeline/agents/blind-reviewer.md` into the project's `.claude/agents/`,
restart `claude`, then: "use the blind-reviewer on my changes". It works for any language: it detects the stack itself.

---

## 3. The pieces, one by one

### 3.1 `new-project.sh`

**Offers:** a ready project in one command: start.spring.io download (name, package, Java, Boot, dependencies), the
kit installed, the next steps printed.

1. `./new-project.sh <name>`: lowercase letters, digits and dashes. It refuses an existing folder.
2. It runs `install.sh` on the new folder (with `--e2e` if given).
3. Read the printed "Next" steps: fill `CLAUDE.md`, start `claude`, `/learning-loop`.

### 3.2 `install.sh`

**Offers:** copies `kit/` (and `kit-e2e/` with `--e2e`) into a project, substituting the app's name (its Maven
`artifactId`, else the folder name) into the e2e files and Dockerfile.

| Flag | Effect |
|---|---|
| `--dry-run` | Lists what would be added, writes nothing |
| `--e2e` | Adds `e2e/`, the e2e skill and agent, `.mcp.json`, and a Dockerfile/.dockerignore if missing |
| `--ai` | Adds the `llm-engineering` skill and `CLAUDE.ai.md` (merge it into `CLAUDE.md`); with `--e2e` also `e2e/llm-fake/`. It doesn't add the SDK dependency: add `com.anthropic:anthropic-java` at the version the skill names when the project first calls the model |
| `--web` | Adds `web/` (React + Vite template, Dockerfile) and the `react-frontend` skill |
| `--force` | Overwrites existing files (check `git diff` afterwards) |

It refuses your home directory. Restart `claude` after installing: agents and skills load at session start.

### 3.3 `CLAUDE.md` and the learning files

**Offers:** the working agreement Claude reads at the start of **every** session in the project:
- you write `src/main` unless you name the implementer;
- explain before code, small steps, tests first where they help;
- review after every feature;
- ask before dependencies, deletions, commits or anything shared;
- no real personal or client data.

| File | Purpose |
|---|---|
| `CLAUDE.md` → "This project" | Fill in: what it is, the architecture you chose, versions, what you want to learn. Agents respect the chosen architecture |
| `docs/learning/PROGRESS.md` | The plan, what you can explain, what the implementer built for you |
| `docs/learning/LESSONS.md` | Mistakes → rules. Read at the start of each session |

### 3.4 The agents

Call one by name, in plain words: "use the code-reviewer agent on my changes". Each runs in its own context, with only
its own tools, and hands back a report.

| Say | You get |
|---|---|
| "ask the mentor why my query runs 4 times" | an explanation using your code; hints smallest first |
| "ask the mentor for an exercise on optimistic locking" | an exercise sized to one session |
| "use the code-reviewer agent on my changes" | ≤ 8 findings per axis (standards, then spec if there's a ticket), each with a scenario, the rule it breaks, and a hint (learn mode) or the change to make; tests run |
| "use the blind-reviewer on my changes" (or "…on src/main/…/orders") | a fingerprint of the stack, then findings with a cited standard. **Give only the scope**; it ignores descriptions |
| "use the security-reviewer agent" (in a Spring app, the spring-security-reviewer) | attack scenarios, access control first |
| "use the deploy-reviewer agent on my Dockerfile" | what the file does at runtime, and what will bite |
| "use the implementer to add docker compose with Postgres" | the change, tests, `./mvnw verify`, an explanation, a sibling task for you; logged in PROGRESS.md |
| "use the e2e-tester agent to plan scenarios for the order API" | a scenario list from exploring the running app; code only when asked |

**Which reviewer?** They tied in a measured comparison (§3.10): each found things the other missed. Use
`code-reviewer` after every feature, and add `blind-reviewer` for important changes.

### 3.5 The skills

Skills load **by topic**: ask about transactions and Claude reads `transactions`. Two are commands you type:
`/learning-loop` (start or continue) and `/interview-drill` (practice). To use one directly: "use the
distributed-systems skill to review my consumer". Each skill ends with **Learn by doing** exercises.

The three newest, in one line each:
- **`transactions`**: predict each of 18 situations, then run `./mvnw test -Dtest=TransactionTrapsTest` in kit-check
  and compare.
- **`distributed-systems`**: start from its four questions (twice? out of order? never? dies between two steps?)
  for every arrow in your design.
- **`system-design`**: the 45-minute shape and the rubric, then one of the 14 designs per session.

### 3.6 End-to-end tests (`--e2e`)

**Offers:** your app's image plus Postgres (and Kafka, Redis or a web front end if you turn them on) in
Testcontainers on a private network with a random port; Playwright tests through the API and the browser; fresh
databases every run; everything removed afterwards, even after a crash.

```bash
cd e2e
npm install && npx playwright install chromium      # once; then commit package-lock.json
npm run stack:build                                  # builds <app>:e2e from the project's Dockerfile
npx playwright test                                  # stack up → tests → stack removed
npm run report                                       # HTML report; failed tests keep a trace
npm run stack:up                                     # keep a stack running; URL in e2e/.stack-url; Ctrl+C removes it
E2E_BASE_URL=$(cat .stack-url) npx playwright test   # fast loop against the running stack
```

| Setting | File | Use |
|---|---|---|
| What runs | `e2e/stack/stack.config.ts` | app image, port, ready path, memory; `postgres` on by default; `kafka`, `redis`, `web` off |
| One-off app settings | `E2E_APP_ENV='KEY=value'` | e.g. a dev-only failure switch for a lab |
| Stale image check | `E2E_STRICT_IMAGES=1` | fail (instead of warn) when the code is newer than the image; set it in CI |
| Other hosts | `E2E_ALLOWED_HOSTS` | only for an environment you own; tests write data |

Rules the skill enforces: never sleep (wait on conditions); expected values from an independent **oracle**, never the
system's own output; pin known bugs exactly (not `test.fail()`); user-facing selectors; prove a new test with
`--repeat-each=20` before trusting it. Proven first on the private example project's suite (17 tests, 340/340 on a repeat run).

### 3.7 The Playwright MCP

**Offers:** Claude can drive a browser to explore a screen, find accessible names for selectors, or replay a failing
step.

1. Start a stack: `cd e2e && npm run stack:up`.
2. Start `claude` in the project; approve the `playwright` server when asked (the first time, and again on a new machine or account).
3. Say: "open the app from e2e/.stack-url and show me the checkout", or "use the e2e-tester agent to explore the
   order page and plan tests".
4. Write the result as code: the suite, not the MCP, is what runs in CI.

Only ever point it at a local stack. The origin allowlist prevents accidents, but the MCP's own docs say it isn't a
security boundary.

### 3.8 `/project-explorer`

It comes with the `pipeline` plugin (`/pipeline:project-explorer`) and with copy installs. In an existing project it's
the first step, before `/setup-project` ([PIPELINE.md](PIPELINE.md#an-existing-project)).

**Offers:** for any repository:
- an interactive page with an architecture map (8–30 boxes), request flows step by step with real captured data and a
  **verified breakpoint** per step, and debugger configs for every process;
- `TOUR.md` (a first-hour debugging tour) and generated `FLOWS.md`;
- if you say yes, concept ladders (L0 → Ln, each level a measured problem → change → result) and labs that push the
  system past its limits (`LABS.md`).

It works in phases and **stops at three gates**:

| Phase | What happens | Gate |
|---|---|---|
| 0 Safety | checks for confidential data, secrets, shared infrastructure | asks at once if anything sensitive turns up |
| 1 Survey | stack, entry points, dependencies (on a big repository, one Sonnet reader per service, checked by the Opus session); runs the app; drafts the map and flow list | **Gate 1**: which flows; standalone HTML or inside your React/Next/Vue/Svelte app; output folder |
| 2 Debuggers | detects or adds run/debug configs; proves a breakpoint hits per role | **Gate 2**: before adding dependencies or plugins |
| 3 Flows | runs each flow, captures and scrubs data, verifies breakpoints, builds and checks the page | |
| 4 Pathways | writes TOUR.md, generates FLOWS.md | |
| 5 Concepts | finds the mechanisms worth teaching | **Gate 3**: which ladders; **labs or not**; may it add dev-only failure switches; scale target |
| 6 Ladders | builds ladders; with labs, real measurements in MEASURED.md | |
| 7 Hand-over | validates, checks every view, stops what it started, reports | |

It keeps `PROGRESS.md` in the output folder and **resumes** from it in a new session. Its tools (run from the output
folder): `validate-data.mjs`, `bundle-html.mjs`, `check-explorer.mjs` (geometry and screenshots), `gen-guides.mjs`,
`lab-kit.mjs`.

**A study plan on the page:** after the explorer exists, ask for a "Study path" tab: weeks of steps that open flows,
ladder levels and boxes, with ticks saved in the browser, and a script that writes the same plan as a markdown
checklist. (The private example project has one; its data sits between `PATH-DATA-START` and `PATH-DATA-END`.)

### 3.9 kit-check: the proofs

**Offers:** confidence that the code in the skills runs on the current versions.

```bash
cd spring-boot-learning/kit-check
./mvnw verify               # 35 tests: catalog/JPA, transactions (18), outbox, resilience, API (Docker needed)
./verify-templates.sh       # builds, runs and validates the Docker, compose, CI and Kubernetes templates, then cleans up
./verify-e2e.sh             # installs --e2e into a copy, runs Playwright against Testcontainers, checks the stale-image guard
./verify-ai.sh              # LLM unit tests; installs --e2e --ai into a copy; the app against the WireMock model fake; lints the eval workflow
./verify-web.sh             # installs --e2e --web into a copy; builds the web and app images; a Playwright UI test through nginx
```

None of these calls the real model or needs a key. The one live check, `LiveExtractionEvalIT`, runs only with
`RUN_LIVE_EVALS=true` and `ANTHROPIC_API_KEY` set, and costs well under a cent on Haiku 5.5.

### 3.10 The reviewer evaluation

**Offers:** a fair way to decide whether a changed agent is better. Used twice:
- `code-reviewer` (with context) vs `blind-reviewer` (code only) on the private example project: **a draw**, 14.83 vs
  14.67 points, so both are kept.
- The rewritten, two-axis `code-reviewer` vs its previous version on an invented fixture with 10 planted defects:
  31.83 vs 27.17. All 10 were found in every run, against 8 or 9, so the new version replaced the old. The reports
  and grades are in `reviewer-eval/results/`.

The method, step by step (details and scripts in its `README.md`):
1. A code-only copy of a project with known defects, the docs that describe them removed (`prepare.sh`).
2. An answer key and scoring rules written **before** reading any result (`answer-key.md`).
3. 3 runs per variant, same request, headless (`run.sh <agent> <n>`).
4. Audit what each read (`extract.py`).
5. Reports stripped of anything that identifies the agent (`blind.py`), graded by a separate agent per pair.
6. Unblind and total (`score.py`); a winner needs a lead of ≥ 2 points and ≥ 15%, otherwise it's a draw.

---

## 4. Workflows, step by step

### 4.1 A normal learning session
1. `claude` in the project → `/learning-loop`. It reads PROGRESS and LESSONS and proposes the next step.
2. Read the primer; answer its check question.
3. Build it yourself. Stuck: "give me a hint" → "another hint" → "show me".
4. Run the tests; make the behaviour visible (breakpoint, SQL log, curl, log line).
5. "use the code-reviewer agent on my changes"; fix what you agree with.
6. Explain the change back in 3–5 sentences; Claude points out gaps.
7. Tick PROGRESS, add any mistake to LESSONS, commit.

### 4.2 Something done for you
1. "use the implementer to <task>". Name the files or behaviour.
2. Read its hand-over: the explanation and the sibling task.
3. Do the sibling task yourself; review it with the code-reviewer.

### 4.3 Adding end-to-end tests to a running project
1. `install.sh <project> --e2e` (or `new-project.sh --e2e` from the start).
2. Edit `e2e/stack/stack.config.ts` (ready path, Kafka/Redis/web), or ask "use the e2e-tester agent to set up the
   stack for this app".
3. `npm run stack:build`, `npx playwright test`.
4. "use the e2e-tester agent to plan scenarios for <feature>", then "…write them". Insist on `--repeat-each=10`.

### 4.4 Understanding a new codebase fast
1. `/project-explorer`; answer the gates (start with 4–6 flows; labs later if at all).
2. Follow `TOUR.md` in the debugger.
3. Ask the mentor about anything that surprised you.

### 4.5 Turning a project into interview material
1. `/project-explorer` with concept ladders (and labs, to get measured numbers).
2. The `system-design` skill: write requirements, numbers, capacity model, the "why not X?" sheet.
3. `/interview-drill` at senior or staff level, 30–45 minutes; score with the rubric.
4. Repeat the weakest area until two sessions in a row score 3/4+.

### 4.6 Reviewing before a release
1. "use the blind-reviewer on <range>" and "use the code-reviewer agent on <range>".
2. "use the security-reviewer agent" (in a Spring app, the spring-security-reviewer).
3. "use the deploy-reviewer agent on the Dockerfile and CI".
4. Fix or record each finding; rerun the tests and the e2e suite.

---

## 5. Applying it to other situations

| Situation | What to do |
|---|---|
| **Another Spring Boot project** | `install.sh <project> [--e2e]`. Everything applies |
| **A project with its own CLAUDE.md** | Merge `CLAUDE.learning.md` into it: keep their rules, add "How we work" and the learning files if you want them |
| **A Java project without Spring** | Keep: `mentor`, both reviewers, `security-reviewer`, `deploy-reviewer`, `implementer`, `learning-loop`, `interview-drill`, `java-modern`, `distributed-systems`, `system-design`, `design-patterns`, `resilience-patterns` (concepts). Delete or ignore the Spring-specific skills |
| **Another language (Go, Python, TypeScript…)** | Use the `pipeline` plugin with no pack ([PIPELINE.md, step 0](PIPELINE.md#0-set-up-once)): every stage and agent works, and so does `/project-explorer`; put the stack's rules in `CODING_STANDARDS.md`. Also portable as is: the e2e approach (point `stack.config.ts` at any image with an HTTP health URL). What a pack would add: a review checklist, testing and framework skills proved by tests, verified build and deploy templates |
| **A project you don't own** (work, client) | Don't install anything without the owner's agreement. The least invasive option is the `blind-reviewer`, which only reads; `/project-explorer` writes an output folder and debugger configs, so ask first. Never send confidential data to an LLM: check before you start |
| **A new machine or account** | `git clone` this repo, run `./setup.sh`. Approve project MCP servers again. A project's `CLAUDE.md` carries its rules; memory files are optional |

---

## 6. Improving the toolkit

### 6.1 Version control

Everything is in **this one repository**, so every improvement is a commit you can inspect or undo: the kit
(`spring-boot-learning/`), the scripts and this guide. Ignored: build output (`target/`, `node_modules/`),
`reviewer-eval/work/`, and **every project folder** you create here with `new-project.sh` (each new project is its own
repository).

Projects with the plugins get a new version with `claude plugin update`; copy installs get **copies** of the kit
(§6.2). Before changing anything: `git status` (clean?), then make the change, run the proofs (§6.3–6.7),
and commit with a message that says why. `git log --since=2026-11-01 --stat` shows what changed since a date.

### 6.2 The rule: edit the kit, not the copies

Projects get **copies** (install.sh) or **plugins** (`pipeline@kits` and a pack). Change an agent or skill in its kit:
agents and stack-neutral skills in `spring-boot-learning/kit-pipeline/`, Spring skills in `kit/`, add-ons in `kit-e2e/`,
`kit-ai/`, `kit-web/`. Plugin projects pick the change up at their next session. Copy projects need a re-install:
`install.sh <project> --force`, then check `git diff` in the project (`--force` overwrites). Never edit
`kit-pipeline/upstream/`: those skills come unchanged from mattpocock/skills at the commit pinned in
`kit-pipeline/upstream.lock`, and `kit-check/verify-pipeline.sh` checks they still match. To take upstream changes:
edit the commit in `upstream.lock`, run `verify-pipeline.sh --update-upstream`, read the diff, and commit it as its own
PR.

### 6.3 Improve a skill
1. Edit the skill's `SKILL.md`: `kit-pipeline/skills/<name>/` for stack-neutral skills, `kit/.claude/skills/<name>/` for
   Spring ones. Keep the frontmatter `description` specific: it's how Claude decides to load the skill ("Use when …").
2. If you add or change **code**, prove it in kit-check: a test under `kit-check/src/test/...`, then `./mvnw verify`.
   No claim in a skill without a test or a cited source.
3. Concurrency or timing claims: run the test 5+ times (`for i in 1 2 3 4 5; do ./mvnw -q test -Dtest=…; done`).
4. Update the README's skill table if the scope changed.

### 6.4 Add a skill
1. `mkdir kit/.claude/skills/<name>` (Spring) or `kit-pipeline/skills/<name>` (any stack; add it to install.sh's
   `CORE_SKILLS` if learning projects should get it), and a `SKILL.md` with `name:` and `description:` frontmatter; follow the shape of
   `transactions`: the core idea, tables of situations → answers → proof, fixes, **Learn by doing**.
2. Prove its code in kit-check (a new package, a migration if it needs tables).
3. Add a row to the kit README and to this guide's skill table; mention it in NOTICE.md (the license asks to record
   changes).
4. `install.sh <scratch dir> --dry-run` shows it ships.

### 6.5 Add or change an agent
1. A file in `kit-pipeline/agents/<name>.md` with frontmatter: `name`, `description` (when to use it: Claude reads this
   to choose), `tools` (**least privilege**: a reviewer gets no Write/Edit), `model: inherit`, and if useful
   `omitClaudeMd: true` (no project context), `skills:` (preload), `isolation: worktree` (its own copy of the repo).
2. Body: what it does, the process, what it must never do, the report format.
3. Test it on a real project; restart `claude` to load it.
4. If it **replaces** an agent, measure first with the reviewer evaluation (§3.10): keep the winner, keep both on a draw.

### 6.6 After a Spring Boot (or Java) upgrade
1. Bump the parent version in `kit-check/pom.xml`.
2. `./mvnw verify`, `./verify-templates.sh`, `./verify-e2e.sh`.
3. Fix what fails, then fix the **skill text** to match (version numbers, moved packages, changed defaults).
4. Bump the default in `new-project.sh` (`BOOT=`).

### 6.7 Improve the e2e add-on
Edit `kit-e2e/` (template code: keep `__APP__` placeholders), then `./verify-e2e.sh`. Pin tool versions (Playwright,
`@playwright/mcp`, testcontainers) and bump them deliberately.

### 6.8 Improve the AI and web add-ons
Edit `kit-ai/` or `kit-web/`, then `./verify-ai.sh` or `./verify-web.sh`. A code shape in `llm-engineering` goes into
`kit-check/src/main/java/com/example/kitcheck/llm/` with a test against `FakeClaude` first; keep the canned responses
in the real shape (copy from a recorded live response when you have one). Pin the SDK, images and npm packages to
releases at least two weeks old.

### 6.9 Improve `/project-explorer`
Edit `spring-boot-learning/kit-pipeline/skills/project-explorer/` (`SKILL.md`, `reference/*.md`, `template/`,
`tools/`). Test on a small repo end to end: survey → one flow → bundle → `check-explorer.mjs` clean. Its README lists
what was and wasn't tested (the Next, Vue and Svelte shells were never run). Then run `kit-check/verify-pipeline.sh`.

### 6.10 Ideas for next improvements
- A **Kafka/Redis kit-check module** so `distributed-systems` is proven inside the kit, not only in the private example project.
- **Blind** versions of `security-reviewer` and `deploy-reviewer`, measured with the reviewer evaluation.
- A **CI workflow for the kit itself** running kit-check on every change.
- A **TypeScript pack** (testing, framework and build templates proved the way kit-check proves the Spring ones). When
  it lands, move the stack-neutral parts of the deploy templates (the workflow, the Kustomize shape) into `pipeline`.
- Run the **LLM checks** of `spring-security-reviewer` and `blind-reviewer` through the reviewer evaluation
  (prepared in its README).
- A `jpa-patterns` exercise for `IDENTITY` vs `SEQUENCE` batching, with a statement-count test.

---

## 7. How Claude Code loads all this (facts worth knowing)

- **Project-level** agents and skills live in `<project>/.claude/`; **personal** ones in `~/.claude/` (every project).
  They load when a session starts: restart `claude` after adding one.
- **`CLAUDE.md`** is read into every session in that folder, and into subagents too, unless the agent has
  `omitClaudeMd: true` (that's how the blind-reviewer stays blind; proved with a marker line).
- **Subagents** start with a fresh context: not your conversation, not the auto-memory. They do get the git status
  snapshot.
- **Project MCP servers** (`.mcp.json`) need your approval before first use (stored in your local Claude settings).
- **Headless runs** for scripts: `claude -p "<task>" --allowedTools "Read" "Grep" … --output-format stream-json
  --verbose`; `--no-session-persistence` keeps no session; `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` stops memory writes.
  `--bare` skips CLAUDE.md, skills and plugins but needs an API key.
- **Memory** (`~/.claude/projects/<folder>/memory/`) is local files per project folder, separate from the repo.

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| An agent or skill isn't found | Start `claude` from the project folder; restart it after installing |
| `new-project.sh` fails | No internet, or start.spring.io doesn't know that `--boot` version or a `--deps` id |
| Integration tests don't start | Docker isn't running |
| e2e: "image doesn't exist" / "older than the code" | `npm run stack:build` in `e2e/` |
| e2e: the stack doesn't start | Docker memory: the stack needs ~1–1.6 GB free (`docker stats`); stop your own idle containers, never other projects' |
| The playwright MCP isn't available | Approve it when asked; restart `claude` in the project |
| Claude writes code you wanted to write | Say so; `CLAUDE.md` says you write `src/main`. Add it to LESSONS.md if it repeats |
| A skill gives advice that fails | The version moved on: run kit-check (§6.6) and fix the skill |
| `mvn` not found | Use the project's `./mvnw` |

## 9. Ground rules

- You write the production code unless you name the implementer.
- Claude asks before: new dependencies, build changes, deleting files, commits or pushes, anything outside the project,
  anything on shared machines or other projects' containers.
- No real personal or client data anywhere; invent test data. Secrets live in `.env` (gitignored), never in files.
- Pin versions; prove claims with a test or a source; measure before saying "faster".

## 10. Proofs

| What | How it's proved | Where |
|---|---|---|
| Code in the Spring and AI skills | 44 tests on Spring Boot 4.1.1 with real Postgres, plus 23 for the LLM code shapes against a local fake of the API | `kit-check/` (`./mvnw verify`), §3.9 |
| Docker, CI and Kubernetes templates | built and run; overlays validated against the Kubernetes 1.33 schemas; workflows linted. With `--kind`: a rollout, a broken release that leaves the old pods serving, and `rollout undo` | `kit-check/verify-templates.sh` |
| The plugins | the 15 adopted skills match upstream byte for byte; the merge guard blocks 22 dangerous commands and allows 15 safe ones; the marketplace validates; all five plugins install and load in a throwaway home; `/next` names the expected step for 26 repo states, and `protect-main.sh` sends the right ruleset in 6 cases, both with `gh` stubbed. On a real repository (myhts/lombard), `protect-main.sh` created the ruleset, then ran again and kept it unchanged | `kit-check/verify-pipeline.sh` |
| The reviewers | blind-graded comparisons on code with known defects. `code-reviewer` and `blind-reviewer` tied, each finding things the other missed. The rewritten `code-reviewer` found all 10 planted defects in every run (31.8 against 27.2 for its previous version) | `kit-check/reviewer-eval/`, §3.10 |
| The explorer's readers | on a copy of Google's Online Boutique (11 services, 5 languages), readers on Opus, Sonnet and Haiku each found all 23 entry points, 14 calls and the store in an answer key taken from the code, with no broken references and no invented calls. Sonnet readers halved the cost of a run; Haiku's readers made 3 to 4 times the tool calls and cost no less. So the readers use Sonnet, and the map, the flows and the explanations stay on Opus | `kit-check/explorer-eval/` |
| e2e, AI and web add-ons | installed into a copy and run end to end | `verify-e2e.sh`, `verify-ai.sh`, `verify-web.sh` |

**Not proved yet:**
- The deploy workflow passes lint and a fake `gh`, but hasn't run on GitHub itself. The PR checks (`pr-size`,
  `human-review`) have run on a real PR.
- The stage commands (`/implement`, `/human-review`, `/deploy`) haven't been used on a real project yet.
- The AI pack's canned responses haven't been checked against the live API, and the LLM checks in
  `spring-security-reviewer` and `blind-reviewer` haven't been measured. The stack-neutral `security-reviewer` has had
  one trial run, on a small TypeScript sample (2026-11-05): it found all 6 planted problems, flagged nothing on the
  safe query, and never opened `.env`. One run isn't a measured comparison. The agent checks in both security
  reviewers (who keeps the conversation, approvals, memory, MCP tools) came after that run and haven't been tried.
- `deploy-reviewer` became stack-neutral on 2026-11-08. One trial run, on a small Node sample: it found all 11 planted
  problems (image, signals, compose, CI, probes, grace period, memory) and didn't flag the safe one, a readiness probe
  that checks the database. It ran with Read alone, as builds without Grep and Glob tools would give it, which is why
  it now has Bash for finding files.

## 11. What's ours and what's adopted

**Ours:**
- Event Storming as a step for event-driven domains, with command cards and Given/When/Then specs.
- The three build modes, including learn and build-with-me.
- The human gate: a review sized by risk, and a record tied to the head commit.
- The merge guard.
- `/next`: the repo's real state read in one pass, and one command named, nearest to production first.
- Two reviewers, one that knows the project and one blind, compared in `kit-check/reviewer-eval`.
- Stack packs proved by tests (kit-check).
- One PR per ticket instead of an integration branch.
- Kubernetes deploys through GitHub Actions.

**Adopted:** 15 skills copied unchanged from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT; see
`spring-boot-learning/NOTICE.md`): `grilling`, `grill-with-docs`, `domain-modeling`, `wayfinder`, `research`,
`prototype`, `wizard`, `to-spec`, `to-tickets`, `tdd`, `codebase-design`, `diagnosing-bugs`, `pr`, `retro`,
`writing-for-agents`. The merge guard is adapted from the same repository's `git-guardrails-claude-code`.

**Ideas restated in our own words**, from widely used practice:
- ubiquitous language
- small decision records
- planning at the right fidelity
- review on separate axes
- risk-based review
- turning repeated review comments into checks
