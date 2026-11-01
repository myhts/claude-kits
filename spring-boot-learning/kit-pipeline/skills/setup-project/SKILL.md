---
name: setup-project
description: "Set up a repository for the delivery pipeline: stack card, tracker and domain docs, coding standards, CLAUDE.md pointers, the pack plugin, labels and PR checks. Run once per repo, before the other pipeline skills."
disable-model-invocation: true
---

Prepare this repository so every pipeline stage knows its stack, its commands, its tracker and its build mode. The
result is a handful of small files the other skills read; nothing here writes application code.

Files this skill fills in live beside it: [templates/stack.md](templates/stack.md),
[templates/CODING_STANDARDS.md](templates/CODING_STANDARDS.md), [templates/claude-md-blocks.md](templates/claude-md-blocks.md)
and [templates/github/](templates/github/). The tracker and domain doc templates come from the upstream skills:
`${CLAUDE_PLUGIN_ROOT}/upstream/setup-matt-pocock-skills/issue-tracker-github.md` and `domain.md` in the same folder.

## 1. Explore

Look before asking. Record what you find:

- **Stack:** `pom.xml` or `build.gradle*` with Spring Boot → `spring`. Any other stack → `none` (a TypeScript pack is
  planned; until it exists, TypeScript repos use `none` too). More than one stack in the repo → ask which one the
  pipeline should follow.
- **Commands the repo already has:** `mvnw`, `package.json` scripts, a Makefile, the CI workflow. These become the stack
  card's commands; prefer what exists over inventing.
- **Existing files:** `CLAUDE.md` or `AGENTS.md`, `docs/agents/`, `GLOSSARY.md` or `GLOSSARY-MAP.md`, `docs/adr/`,
  `CODING_STANDARDS.md`, `.github/workflows/`, `.claude/settings.json`.
- **GitHub:** `gh repo view --json nameWithOwner,visibility,defaultBranchRef`. Confirm it's the user's own repo.
- **Tools:** `gh --version` (2.94 or later gives native sub-issue and blocking flags; older versions use the `gh api`
  fallbacks in the tracker doc, and work), `claude plugin marketplace list` (is `kits` registered, and from a GitHub
  repo or a local directory?).

Done when every bullet has an answer or a "not present".

## 2. Ask, in one round

Present the findings, then ask the open questions together, each with your recommended answer. A "yes" accepts the
recommendation.

1. **Pack**: the detected one. If it's `none`, say what that means: every stage, agent and the merge guard work the
   same; what's missing is stack knowledge. There's no review checklist (offer to put the stack's main rules into
   `CODING_STANDARDS.md` now) and no verified templates (`/deploy` writes from a described shape instead).
2. **Default build mode**: learn (the learner writes the code), build-with-me (small blocks the human checks), or
   deliver (the implementer builds whole tickets). Recommend learn for a learning project, build-with-me when the human
   wants to learn while shipping, deliver otherwise.
3. **Domain layout**: one context (one `GLOSSARY.md`) unless the product clearly has separate languages; Event Storming
   can split it later.
4. **PR budget**: 400 changed lines.
5. **Write the CI checks** (`pr-size`, `human-review`, and the pack's CI if the repo has none): yes.

Done when the user has answered or accepted all five.

## 3. Show the plan, then write

List every file you will create or edit, one line each, and wait for an OK. Edit existing files in place and leave
everything you weren't asked to change as it was.

- **`docs/agents/stack.md`** from the template. Fill each command from step 1, run the fast ones once (compile or
  typecheck, one test file) to confirm they work, and mark missing ones "not set up yet". Name the pack's files as
  `<plugin>@kits: <path inside the plugin>`. For `spring`, the review checklist is
  `spring@kits: .claude/skills/spring-boot/review-checklist.md` and the templates are
  `spring@kits: .claude/skills/build-templates/`. Anyone reading the card finds the plugin's folder with
  `claude plugin list --json` (its `installPath`).
- **`docs/agents/issue-tracker.md`** from the upstream GitHub tracker template, and **`docs/agents/domain.md`** from the
  upstream domain template, set to the chosen layout.
- **`CODING_STANDARDS.md`** from the template, only if the repo has none.
- **`CLAUDE.md`** (or the existing `AGENTS.md`): append the two blocks from `claude-md-blocks.md`, filled in. Replace an
  existing `## Agent skills` or `## Pipeline` block rather than adding a second one.
- **Plugins for this project:**
  - Run `claude plugin marketplace add <toolkit source> --scope project`. Use `owner/repo` when `kits` is registered
    from GitHub, or the local directory path otherwise.
  - Then run `claude plugin install pipeline@kits --scope project`, and `claude plugin install <pack>@kits --scope
    project` unless the pack is `none`. These write `.claude/settings.json`, so collaborators get the same plugins.
- **`.github/workflows/`:** copy `templates/github/pr-size.yml` and `templates/github/human-review.yml`. If there is no
  CI yet, copy the pack's `ci-github-actions.yml` as `ci.yml` and fill its placeholders from the stack card. With no
  pack, write a short `ci.yml` instead: on pull requests and pushes to `main`, check out, set up the toolchain at the
  version the repo pins, then run the stack card's lint and full verify.
- **Labels:** create `ready-for-agent`, `size/large`, `wayfinder:map`, `wayfinder:grilling`, `wayfinder:research`,
  `wayfinder:prototype` and `wayfinder:task` with `gh label create <name> --force`.

Done when every listed file exists with no `<...>` placeholders left, and each command in the stack card has been run
once or is marked "not set up yet".

## 4. Hand over

Tell the user, in a few lines:

- What was written.
- **Branch protection:** once the repo is public (free there), protect `main`: require the `human-review` status and the
  CI job, and allow no direct pushes. On a private repo this needs a paid GitHub plan; the merge guard still stops Claude.
- **`gh` older than 2.94:** suggest `brew upgrade gh`.
- **What to run next:** `/grill-with-docs` for the first feature, or `/wayfinder` when the work is too big for one
  session. `/deploy` sets up Kubernetes when there is something to ship. From then on, `/next` reads the repo and
  names the next command whenever they're unsure.
