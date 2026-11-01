# claude-kits

A [Claude Code](https://claude.com/claude-code) plugin marketplace with two parts. The first is a **delivery pipeline
for any stack**, which takes a change from the first conversation to production. The second is a set of **stack
packs** whose advice is proved by tests. The pipeline goes:

```
plan the language → Event Storming (event-driven work) → test-first build with container tests
  → a small PR → two reviewer agents → your review → you merge → GitHub Actions → Kubernetes
```

What sets it apart:

- **Claude never merges.** A hook blocks merges and pushes to `main`. Your review leaves a record tied to the PR's head
  commit, and a CI check reads that record.
- **Small PRs.** One ticket is one PR of about 400 lines, with tests at seams you agreed on before the code was written.
- **Two reviewers that see different things.** One knows the project; the other reads only the code. A measured
  comparison is the reason both stay ([below](#proofs)).
- **You choose how much you write.** `learn` means you write the code and Claude teaches. `build-with-me` means Claude
  writes about 60 lines at a time and asks you about each block. `deliver` means Claude builds the whole ticket.
- **Proof before claims.** Code in a skill is run by a test, templates are deployed to a throwaway cluster, and a
  changed agent is compared with its previous version before it ships.

## Install

You need Claude Code, `git`, `gh` (2.94 or later is best) and Docker. Run these from your project's folder, in any
language:

```bash
claude plugin marketplace add myhts/claude-kits --scope project
claude plugin install pipeline@kits --scope project
claude
> /pipeline:setup-project
```

`/setup-project` looks at the repo, then asks five questions in one round: the pack, the build mode, the domain layout,
the PR budget and the CI checks. Then it shows what it will write. For a Spring Boot repo it also installs the `spring`
pack. Every other stack runs with no pack: the stages, agents and merge guard work the same, minus the stack-specific
checklist and templates.

Then `/pipeline:grill-with-docs` starts your first feature. **[PIPELINE.md](PIPELINE.md)** walks through one feature
from start to production, with every command.

## What's inside

| Plugin | For | Adds |
|---|---|---|
| `pipeline` | every project | **Stages:** `/setup-project`, `/grill-with-docs`, `/wayfinder`, `/to-spec`, `/to-tickets`, `/implement`, `/human-review`, `/deploy`, `/retro`. **Skills:** `event-storming` (command cards and Given/When/Then specs), `tdd`, `codebase-design`, `diagnosing-bugs`, `system-design`, `distributed-systems`, `design-patterns`, `resilience-patterns`, `learning-loop`, `interview-drill`. **Agents:** `implementer`, `code-reviewer` (standards and spec axes), `blind-reviewer`, `security-reviewer`, `deploy-reviewer`, `mentor`. **Hook:** the merge guard |
| `spring` | Spring Boot 4 | `spring-boot`, `testing-patterns` (Testcontainers 2), `transactions`, `jpa-patterns`, `java-modern`, `java-concurrency`, `logging-patterns`, the Spring review checklist, and build templates: Dockerfile, CI, a Kustomize base with staging and prod overlays, and the deploy workflow |
| `e2e` | apps with a UI or flows | Playwright end-to-end tests against the app and its databases in Testcontainers, the `e2e-tester` agent, and the Playwright MCP limited to localhost |
| `spring-ai` | Spring services that call Claude | `llm-engineering`: structured outputs, prompt injection, stop reasons, citations checked against the source, caching and cost, PII-safe logs, evals as tests, plus a review checklist the reviewers use |
| `spring-web` | a front end for a Spring API | a React + Vite + TanStack Query template behind nginx, and the `react-frontend` skill |

A TypeScript pack is planned. Until it exists, TypeScript repos run with no pack.

**Outside the marketplace:**
- **`/project-explorer`** turns any codebase into an interactive architecture explorer, with debug walkthroughs and
  optional scaling labs. `./setup.sh` makes it available in every project.
- **The learning kit** is `new-project.sh` plus `install.sh`. They copy the same agents and skills into a Spring Boot
  project, with a working agreement in which you write the code. **[GUIDE.md](GUIDE.md)** covers it.

```bash
git clone https://github.com/myhts/claude-kits.git && cd claude-kits
./setup.sh                                  # checks your tools; links /project-explorer for every project
./new-project.sh my-shop --e2e --pipeline   # Spring Boot 4.1.1 + Postgres + e2e tests, with the plugins enabled
```

## Proofs

| What | How it's proved | Where |
|---|---|---|
| Code in the Spring and AI skills | 44 tests on Spring Boot 4.1.1 with real Postgres, plus 23 for the LLM code shapes against a local fake of the API | `spring-boot-learning/kit-check/` (`./mvnw verify`) |
| Docker, CI and Kubernetes templates | built and run; overlays validated against the Kubernetes 1.33 schemas; workflows linted. With `--kind`: a rollout, a broken release that leaves the old pods serving, and `rollout undo` | `kit-check/verify-templates.sh` |
| The plugins | the 15 adopted skills match upstream byte for byte; the merge guard blocks 16 dangerous commands and allows 9 safe ones; the marketplace validates; all five plugins install and load in a throwaway home | `kit-check/verify-pipeline.sh` |
| The reviewers | blind-graded comparisons on code with known defects: `code-reviewer` and `blind-reviewer` tied, each finding things the other missed, so both stay. The rewritten `code-reviewer` found all 10 planted defects in every run and scored 31.8 against 27.2 for its previous version | `kit-check/reviewer-eval/` |
| e2e, AI and web add-ons | installed into a copy and run end to end | `verify-e2e.sh`, `verify-ai.sh`, `verify-web.sh` |

**Not proved yet:**
- The deploy workflow and the PR checks pass lint and a fake `gh`, but haven't run on GitHub itself. The image push,
  environment approvals and label permissions are untested.
- The stage skills (`/implement`, `/human-review`, `/deploy`) haven't been used on a real project yet.
- The AI pack's canned responses haven't been checked against the live API. Neither have the LLM checks in
  `security-reviewer` and `blind-reviewer`.

## Documentation

- **[PIPELINE.md](PIPELINE.md)**: how to apply the pipeline. Setup, choosing a path, one feature end to end, every
  stage, review, small PRs, Kubernetes, troubleshooting.
- **[GUIDE.md](GUIDE.md)**: the handbook. Every piece, the learning workflows, other stacks, how Claude Code loads all
  this, and how to improve the toolkit safely.
- **[spring-boot-learning/README.md](spring-boot-learning/README.md)**: the kits and their proofs, in detail.
- **[skills/project-explorer/README.md](skills/project-explorer/README.md)**: the explorer.

## Layout

```
.claude-plugin/marketplace.json   the marketplace: pipeline, spring, e2e, spring-ai, spring-web
spring-boot-learning/
  kit-pipeline/                   the pipeline plugin: stage skills, core skills, agents, merge guard, upstream/ (adopted skills)
  kit/                            the spring pack, plus the learning kit's CLAUDE.md
  kit-e2e/, kit-ai/, kit-web/     the e2e, spring-ai and spring-web plugins
  kit-check/                      the proofs
  install.sh                      copies the kits into a project (the learning kit's way)
skills/project-explorer/          a personal skill, linked into ~/.claude/skills/ by setup.sh
setup.sh, new-project.sh          one-time setup; a new Spring Boot project
```

## Licence and credits

[Apache License 2.0](LICENSE). The Spring learning kit started from
[piomin/claude-ai-spring-boot](https://github.com/piomin/claude-ai-spring-boot) (Apache-2.0). Fifteen skills come
unchanged from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) at a pinned commit:
`grilling`, `grill-with-docs`, `domain-modeling`, `wayfinder`, `research`, `prototype`, `wizard`, `to-spec`,
`to-tickets`, `tdd`, `codebase-design`, `diagnosing-bugs`, `pr`, `retro` and `writing-for-agents`. The merge guard is
adapted from the same author's `git-guardrails-claude-code` (MIT). [spring-boot-learning/NOTICE.md](spring-boot-learning/NOTICE.md)
lists every change.
