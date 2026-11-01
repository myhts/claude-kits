# The delivery pipeline: how to apply it

One way of shipping for every project, whatever the stack. A change goes:

1. language and plan
2. Event Storming when the domain is event-driven
3. a test-first build with container tests
4. a small pull request
5. two reviewer agents
6. your review
7. **you** merge
8. CI deploys to Kubernetes

This guide is the how-to. [Section 13](#13-whats-ours-and-whats-adopted) says which ideas are ours and which are
adopted, and where from.

**Contents:** [At a glance](#at-a-glance) · [1. Install once](#1-install-once) · [2. Set up a project](#2-set-up-a-project) ·
[3. Choose the path](#3-choose-the-path) · [4. One feature, end to end](#4-one-feature-end-to-end) ·
[5. Stage reference](#5-stage-reference) · [6. Build modes](#6-build-modes) · [7. Review](#7-review) ·
[8. Small PRs](#8-small-prs) · [9. Deploy to Kubernetes](#9-deploy-to-kubernetes) ·
[10. Keep it healthy](#10-keep-it-healthy) · [11. Files in a project](#11-files-the-pipeline-creates-in-a-project) ·
[12. Troubleshooting](#12-troubleshooting) · [13. What's ours, what's adopted](#13-whats-ours-and-whats-adopted)

---

## At a glance

```
new work
  ├─ tiny change? ─────────────────────────────► make it, open a PR ────────────┐
  └─ otherwise: /grill-with-docs   (one word per concept; ADRs only when earned)│
        ├─ event-driven domain? → event-storming loads in the same session      │
        └─ too big or foggy?    → /wayfinder map on GitHub                      │
              decision tickets: grilling · research · prototype · task          │
              → /to-spec → /to-tickets  (prefactor, tracer bullet, frontier)    │
                                                                                │
for each ticket:  /implement <ticket>   learn | build-with-me | deliver   ◄─────┘
                    tdd at agreed seams → container tests → lint + verify
                    → code-reviewer (standards) + code-reviewer (spec) + blind-reviewer
                    → fresh implementer fixes must-fix → pr body → PR opened
for each PR:      /human-review <PR>   quick or full, by door × blast radius → record
                  you merge  (Claude can't: merge guard)
on merge:         CI → image → staging (Kustomize) → smoke e2e → your approval → production
now and then:     /retro   (a comment you keep repeating becomes a check or a standard)
```

| You type | When | You get |
|---|---|---|
| `/pipeline:setup-project` | once per repo | stack card, tracker and domain docs, coding standards, CI checks, labels |
| `/pipeline:grill-with-docs` | start of any non-trivial work | shared understanding, `GLOSSARY.md`, ADRs |
| `/pipeline:wayfinder` | work bigger than one session | a map issue and decision tickets, worked one per session |
| `/pipeline:to-spec`, `/pipeline:to-tickets` | after alignment | a spec issue, then small tickets with blocking links |
| `/pipeline:implement <ticket>` | per ticket | a reviewed PR |
| `/pipeline:human-review <PR>` | per PR | your questions answered, a record on the PR |
| `/pipeline:deploy` | once, when there's something to ship | Kustomize, the deploy workflow, environments |
| `/pipeline:retro` | after a milestone, or a repeated comment | proposals to improve the setup |

Plugin skills carry the plugin's name; the slash menu finds them as you type the short name (`implement`). The rest of
this guide uses the short names.

## 1. Install once

1. You need `git`, `claude`, `docker` and `gh` (from a clone of the repo, `./setup.sh --check` checks them). **Use `gh`
   2.94 or later** (`brew upgrade gh`): the planning skills use its sub-issue and blocking flags. Older versions work,
   through slower `gh api` fallbacks.
2. The toolkit is a plugin marketplace called `kits` (`myhts/claude-kits` on GitHub):

   | Plugin | What it adds | For |
   |---|---|---|
   | `pipeline` | the stages, the event-storming discipline, the core skills, the six agents, the merge guard | every project |
   | `spring` | Spring Boot 4, Testcontainers, transactions, JPA, Java, logging, build and deploy templates | Spring projects |
   | `e2e` | Playwright end-to-end tests, the `e2e-tester` agent, the Playwright MCP (localhost only) | projects with a UI or flows |
   | `spring-ai` | calling a model from a Spring service | Spring + LLM |
   | `spring-web` | a React + Vite front end for a Spring API | Spring + web |
   | `typescript` | planned: until it exists, TypeScript repos run with no pack | |

   You don't install them by hand: step 2 below does it per project, so each repo records its own plugins in
   `.claude/settings.json`.

## 2. Set up a project

**A new Spring project:** `./new-project.sh my-app --pipeline` creates it and enables the plugins for it. Then:

```bash
cd my-app && git init && claude
/pipeline:setup-project
```

**An existing project, any stack:** from the project's folder:

```bash
claude plugin marketplace add myhts/claude-kits --scope project   # or the path of a local clone
claude plugin install pipeline@kits --scope project
claude          # then:  /pipeline:setup-project
```

**A stack with no pack** (anything but Spring Boot today) works the same way, minus the stack knowledge:
- The stack card lists the repo's own commands for compiling, testing, linting and running.
- The standards review uses `CODING_STANDARDS.md` and the smell baseline. `/setup-project` offers to write the stack's
  main rules into `CODING_STANDARDS.md` straight away, so that review has more to check against.
- `/setup-project` writes a short CI workflow from the stack card's commands.
- `/deploy` writes the Dockerfile, Kustomize files and deploy workflow from a described shape rather than from verified
  templates. The `spring` pack's templates serve as the worked example, and `deploy-reviewer` checks the result.

`/setup-project` asks five questions in one round (pack, build mode, domain layout, PR budget, CI checks), shows what it
will write, then writes it. Section [11](#11-files-the-pipeline-creates-in-a-project) lists the files. It finishes by
telling you what only you can do: **branch protection** on `main`, requiring the `human-review` status and the CI job.
That's free once the repo is public.

**A project that has the kit copied in** (by `install.sh` or `new-project.sh` without `--pipeline`): keep working as
it is. Switch it to plugins at a natural break: delete its `.claude/agents` and `.claude/skills` copies, then run the
commands above.

## 3. Choose the path

Ask one question first: **is the change tiny?** One idea, quick to review, cheap to redo.

| Situation | Path | Example |
|---|---|---|
| Tiny | Make the change, open a PR | rename a label, fix a failing test, adjust a margin |
| Anything bigger | `/grill-with-docs` first | "members can renew a loan once" |
| The domain is event-driven: several actors, things happening over time, background reactions | the same session also loads `event-storming` | "reservations, copies set aside, and reminders" |
| More fog than one session can clear, or you'd need to research or prototype before deciding | turn it into `/wayfinder` ("let's turn this into a map") | "a notifications system across the product" |

Start with grilling, not with a map. A grilling session can graduate into a map when it grows. A map started for small
work is ceremony you can't undo.

## 4. One feature, end to end

An invented example in a library app: **members can reserve a title that has no copy on the shelf, and are told when a
copy is held for them.**

**4.1 Align the language.** `/grill-with-docs Members want to reserve a title when every copy is out...`
- The agent reads the code and asks questions in rounds, each with a recommended answer; "yes" accepts.
- It settles the words: is it a *reservation*, a *hold* or a *booking*? It lands on **Reservation** for the member's
  request (_Avoid_: hold, booking), and **set aside** for a copy waiting on the shelf for that member.
- It scenario-tests them ("a member reserves, a copy is set aside, they don't collect it in 7 days: what happens?") and
  writes `GLOSSARY.md` as terms settle.
- It offers an ADR only for a decision that is hard to reverse, surprising without context, and a real trade-off. Here:
  **a set-aside copy waits 7 days, then passes to the next reservation in the queue**.
- If the code used other words ("booking", "request"), the rename lands as its own small PR **before** the spec.

**4.2 Event-driven, so Event Storming.** Reservations involve a member, the circulation desk, time, and a background
policy. So the session also loads `event-storming`:
- **Big picture:** the timeline, then the hotspots.
- **Process:** Reserve title → ReservationPlaced; Copy returned → policy "set it aside for the next reservation" →
  CopySetAside → policy "notify member"; after 7 days uncollected → the next reservation in the queue.
- **Design:** one card per command, each with Given/When/Then specs.

Output goes to `docs/eventstorming/`. A fresh subagent runs the consistency checklist before you move on. If this had
been too big for one session, the same work would be tickets on a `/wayfinder` map. A research ticket (for example, "how
do we send notifications?") runs in the background; a prototype ticket ("what does the set-aside shelf screen look like?")
builds throwaway variants on a branch for you to react to. The skill's own worked example (Borrow, Return, Reserve, the
overdue reminder) is in its `CARDS.md`.

**4.3 Spec and tickets.**
- `/to-spec` writes the spec issue from the conversation: user stories, decisions, the testing seams (agreed with you),
  out of scope.
- `/to-tickets` cuts it into small vertical slices, with blocking links. The first slice is a prefactor (pull the queue
  logic out of the loan service), then a tracer bullet: Reserve title → ReservationPlaced → "My reservations" shows it.
  Then three tickets that can run in parallel.

**4.4 Build a ticket.** `/implement #42` in build-with-me mode:
- The implementer writes one block (the `Reservation` decider and its first Given/When/Then test, red then green).
- You see the diff and get a question ("two members reserve the last title at once: what does the second see?"). You
  answer; your answer is checked against the code; you reply **OK**.
- Block by block until the acceptance criteria pass, then the full verify, with Postgres in Testcontainers.
- Then the reviews run in parallel: `code-reviewer` on standards, `code-reviewer` on the spec, `blind-reviewer`. A
  fresh implementer fixes the must-fix findings. The judgement calls are listed for you.
- The `pr` skill writes the body:

  ```markdown
  ## Summary
  reserveTitle(member, title)
    if a copy is on the shelf → refuse "Borrow it instead"
    if member already reserved this title → refuse
    append ReservationPlaced, position = queue length + 1
  ## Evidence
  - **Before:** `ReservationTest > places a reservation when no copy is free` failed: no such command
    **After:** passes; 14 tests, Testcontainers Postgres
  ## Merge Danger
  **Door:** two-way: a new table, no data changed
  **Blast Radius:** small
  ```

**4.5 Your review.** `/human-review #57`:
- The PR is a two-way door with a small blast radius, but this is a learning project, so the review is full depth: a
  short impact report, then 5–8 questions.
- For a **Predict** question, it runs the concurrency test after you answer.
- You decide each judgement call: fix now, a follow-up ticket, or accept.
- It posts the record with the head commit's SHA, and the `human-review` check turns green.
- **You merge.**

**4.6 Ship.**
- The merge triggers CI: it builds the image, pushes it to GHCR, applies the staging overlay, waits for the rollout,
  then runs the smoke e2e against staging.
- You approve the production environment, and the same steps run for prod.

**4.7 Improve.**
- In review you noticed a test that set up its data by inserting rows directly, the second time this week.
- You leave that as a line comment worded as a rule. `/retro` later turns it into a coding standard, and fixes the old
  tests the agent was copying from.

## 5. Stage reference

| Stage | Reads | Writes | Done when | Watch out for |
|---|---|---|---|---|
| `/setup-project` | the repo, `gh`, plugins | stack card, `docs/agents/`, `CODING_STANDARDS.md`, CLAUDE.md blocks, workflows, labels | every command in the stack card ran once or says "not set up yet" | editing an existing CLAUDE.md: it replaces its own blocks, nothing else |
| `/grill-with-docs` | code, glossary, ADRs | `GLOSSARY.md`, `docs/adr/`, rename PRs | shared understanding, language landed | letting the agent own the glossary: you approve every term |
| `event-storming` (inside grilling) | the same | `docs/eventstorming/01–04`, per-context glossaries | the checklist comes back clean | using it for CRUD screens: it pays only for event-driven domains |
| `/wayfinder` | map issue, tickets | map, decision tickets, research and prototype branches | every ticket closed, no fog left | resolving more than one ticket per session |
| `/to-spec`, `/to-tickets` | conversation or map | spec issue, ticket issues | you approved seams and granularity | specs with file paths (they go stale) |
| `/implement` | ticket, spec, stack card | branch, tests, PR | acceptance criteria green at the agreed seams, review clean | skipping the seams agreement |
| `/human-review` | PR, reports, glossary | record comment | every question checked, every judgement call decided | answering for the human: the skill asks, you answer |
| `/deploy` | stack card, pack templates | Kustomize, deploy workflow, a wizard | overlays render, PR open, environments set | pasting secrets into the chat: the wizard runs in your terminal |
| `/retro` | session logs, PR comments | proposals | you chose which to apply | letting it apply its own fixes |

## 6. Build modes

Set per project in the stack card; override per ticket (`/implement #42 deliver`).

| Mode | Who writes | What you do | Use it when |
|---|---|---|---|
| **learn** | you | build, with hints and teaching reviews | the point is to learn the code: a practice project |
| **build-with-me** | the implementer, ~60 lines at a time | check each block, answer 1–2 questions, reply OK / CHANGE / MINE / WHY | you want to ship and still understand every line: a product in a stack you're learning |
| **deliver** | the implementer, a whole ticket | review the PR | small, well-specified tickets |

**MINE** means you write the block yourself, and `code-reviewer` reviews it in teaching mode. **WHY** brings in the
`mentor`. A wrong answer goes into `docs/learning/LESSONS.md`.

## 7. Review

**Three brakes, cheapest first:**

1. **Automated checks** (cost only CPU):
   - the pack's verify (unit and Testcontainers tests), lint and format
   - module boundaries (Spring Modulith or ArchUnit, or dependency-cruiser)
   - the PR size label and the human-review record check
   - actionlint on workflows, kubeconform on the rendered manifests
2. **Automated review**, by agents:
   - `code-reviewer` knows the project and runs twice. On **standards** it uses `CODING_STANDARDS.md`, the pack's review
     checklist, the glossary's _Avoid_ words and a code-smell baseline. On **spec** it checks the ticket, the spec and
     the event model for what's missing, what's extra and what's wrong.
   - `blind-reviewer` knows nothing about the project and checks against published practice for the stack it detects.
   - `security-reviewer` and `deploy-reviewer` join when the diff touches their area.
   - The reports stay separate; must-fix items are fixed before you see the PR.
3. **Human review** with `/human-review`:

   | PR | Depth |
   |---|---|
   | learning project | full, always |
   | one-way door (data loss, a sent message, a published contract, a destructive migration) or a large blast radius | full: impact report + 5–8 questions |
   | two-way door, small blast radius | quick: check the evidence + 2 questions |

**The merge guard** is a hook in the `pipeline` plugin:
- It refuses `gh pr merge`, pushes to `main` or `master`, force pushes, `reset --hard`, `clean -f`, `branch -D`, and
  `checkout .` or `restore .`.
- Pushing a feature branch and opening a PR still work.
- If it blocks something you actually want, run it yourself in your terminal.

## 8. Small PRs

- **One ticket, one PR, one idea.** A prefactor is its own PR, ahead of the behaviour change.
- **About 400 changed lines** (lockfiles, generated code and snapshots excluded). Over that, `/implement` proposes a
  split; if a PR still goes over, CI labels it `size/large` and asks for a reason. It never fails the build.
- **PRs go to `main`.** A blocked ticket waits for its blockers to merge.
- **Wide refactors** go expand → migrate in batches → contract, one PR each.

## 9. Deploy to Kubernetes

**First time:** `/deploy`.
- If no cluster is chosen, it suggests a research ticket ("Pick the Kubernetes host": cost, ingress and TLS, CI
  authentication, Postgres).
- Then it writes `k8s/base`, `k8s/overlays/{staging,prod}` and `.github/workflows/deploy.yml` from the pack's verified
  templates, renders the overlays, has `deploy-reviewer` check them, and opens a PR.
- A `wizard` script walks you, in your own terminal, through:
  - the namespaces
  - the cluster credentials (the `KUBE_CONFIG` secret)
  - image pulls from GHCR
  - the production approval
  - the app secrets (`APP_ENV`)
  - DNS and TLS

**Every release:**
- Merge a PR, and staging updates by itself.
- Approve the `production` environment in GitHub for production. Production runs only the smoke tests not tagged
  `@writes`, so nothing creates data there.
- Database changes are expand/contract, so a rollback is always safe.

**Rollback:**
- Automatic when a rollout or the production smoke test fails (`kubectl rollout undo`).
- By hand: `kubectl rollout undo`, or open the deploy run of the last good commit in GitHub Actions and choose
  "Re-run all jobs" (`gh run rerun <run-id>`). The re-run redeploys exactly that commit.

**How the templates are proved:** `kit-check/verify-templates.sh` renders both overlays and validates them against the
Kubernetes 1.33 schemas, and lints every workflow. With `--kind` it goes further:
- it deploys to a throwaway kind cluster and waits for the rollout;
- it ships a deliberately broken release and checks that the old pods kept serving;
- it checks that `rollout undo` restores the release.

**What Claude never does:** `kubectl apply`, push images, change environments or read secrets. CI and you do.

## 10. Keep it healthy

- **`/retro`** after a milestone, or the moment you notice you've made the same review comment twice:
  - It reads the session logs and the PR comments.
  - It proposes changes: a mechanical rule becomes a check, a judgement call goes into `CODING_STANDARDS.md`, and the
    existing code the agent copied a bad habit from gets fixed.
  - You pick which to apply.
- **Upstream skills:** 15 skills come unchanged from mattpocock/skills at a pinned commit.
  `spring-boot-learning/kit-check/verify-pipeline.sh` checks they still match. To take upstream changes, edit the commit
  in `kit-pipeline/upstream.lock`, run `verify-pipeline.sh --update-upstream`, read the diff, and commit it as its own
  PR.
- **Edit the toolkit, not a project's copy.** A plugin change reaches every project at its next session.

## 11. Files the pipeline creates in a project

| File | Written by | Read by |
|---|---|---|
| `docs/agents/stack.md` (the stack card) | `/setup-project` | every stage and agent |
| `docs/agents/issue-tracker.md`, `docs/agents/domain.md` | `/setup-project` | planning skills |
| `CODING_STANDARDS.md` | `/setup-project`, `/retro` | `code-reviewer` (standards) |
| `CLAUDE.md` blocks "Agent skills" and "Pipeline" | `/setup-project` | every session (pointers only) |
| `GLOSSARY.md` or `GLOSSARY-MAP.md`, `docs/adr/` | `/grill-with-docs` | everything that names things |
| `docs/eventstorming/01–04` | `event-storming` | `/to-spec`, `/to-tickets`, the spec review |
| map, tickets, spec | GitHub Issues | the planning skills and `/implement` |
| `.github/workflows/pr-size.yml`, `human-review.yml`, `ci.yml`, `deploy.yml` | `/setup-project`, `/deploy` | GitHub Actions |
| `k8s/base`, `k8s/overlays/*` | `/deploy` | CI |
| `docs/learning/LESSONS.md`, `PROGRESS.md` | learning projects | `/implement`, the implementer |

## 12. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `/pipeline:...` isn't in the menu | The plugin isn't enabled here. Run `claude plugin list` in the project. If it's missing, run the two commands in [section 2](#2-set-up-a-project), then `/reload-plugins` |
| "Blocked by the merge guard" | Working as intended. Run that command yourself if you really want it |
| A planning skill can't create sub-issues or blocking links | `gh` is older than 2.94. Upgrade it, or let it use the `gh api` fallback in `docs/agents/issue-tracker.md` |
| `human-review` check stays red | No record names the current head commit. Every new commit needs a fresh `/human-review` |
| The PR got `size/large` | Split it, or reply with the reason in the PR. The label never blocks |
| A reviewer flags something you disagree with | Smells are judgement calls: accept, defer or reject in `/human-review`. If it's a standing preference, `/retro` writes it down |
| Wayfinder keeps adding tickets | That's fog clearing, which is expected. If the map grows past what you want, move tickets to "Out of scope" |
| Skills didn't trigger when expected | Name them ("use the tdd skill"). If it keeps happening, `/retro` sharpens the skill's description |

## 13. What's ours and what's adopted

**Ours:**
- Event Storming as the breadboard rung for event-driven domains, with command cards and Given/When/Then specs.
- Three build modes, including learn and build-with-me.
- The human gate: a review sized by risk, and a record tied to the head commit.
- The merge guard.
- Two reviewers: one that knows the project, one blind. Their comparison is in `kit-check/reviewer-eval`.
- Stack packs proven by tests (kit-check).
- One PR per ticket instead of an integration branch.
- Kubernetes deploys through GitHub Actions.

**Adopted:** 15 skills copied unchanged from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT; see
`spring-boot-learning/NOTICE.md`): `grilling`, `grill-with-docs`, `domain-modeling`, `wayfinder`, `research`,
`prototype`, `wizard`, `to-spec`, `to-tickets`, `tdd`, `codebase-design`, `diagnosing-bugs`, `pr`, `retro`,
`writing-for-agents`.

**Ideas restated in our own words**, from widely used practice:
- ubiquitous language
- small decision records
- planning at the right fidelity
- review on separate axes
- risk-based review
- turning repeated review comments into checks
