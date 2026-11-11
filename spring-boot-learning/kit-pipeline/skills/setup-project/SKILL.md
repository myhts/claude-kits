---
name: setup-project
description: "Set up a repository for the delivery pipeline: stack card, tracker and domain docs, coding standards, CLAUDE.md pointers, the pack plugin, labels, PR checks, and a GitHub ruleset that protects main. Run once per repo, before the other pipeline skills; with the argument protect, it only adds or updates the protection."
disable-model-invocation: true
---

Prepare this repository so every pipeline stage knows its stack, its commands, its tracker and its build mode. The
result is a handful of small files the other skills read; nothing here writes application code.

With the argument `protect`, do only step 1's GitHub bullet and step 5.

**A fresh session.** If this conversation already holds other work (the explorer, say), mention it in one line and
suggest `/clear`, then the same command again: the setup reads the repository, not the conversation. Carry on if the
human says so.

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
- **Protecting `main`:** if the setup files are already on the default branch, go on to step 5 now. Otherwise the human
  commits them and merges them, then runs `/pipeline:setup-project protect`; `/pipeline:next` reminds them.
- **`gh` older than 2.94:** suggest `brew upgrade gh`.
- **What to run next,** in a fresh session (`/clear` first): `/grill-with-docs` for the first feature, or
  `/wayfinder` when the work is too big for one session. `/deploy` sets up Kubernetes when there is something to
  ship. From then on, `/next` reads the repo and names the next command whenever they're unsure.

## 5. Protect `main`

A GitHub ruleset makes the flow binding on GitHub's side too: no direct or force pushes to the default branch, every
change through a PR, and the required checks green before the merge button works. It's free on public repositories; a
private one needs GitHub Pro, Team or Enterprise (if so, say that the merge guard still stops Claude, and stop). In the
repo, at most one line of the stack card changes.

1. **Ready?** `git fetch`, then `.github/workflows/human-review.yml` must be on the default branch
   (`git ls-tree --name-only origin/<base> .github/workflows/`). A required check whose workflow isn't there yet would
   block every PR, so if it's missing, stop: the setup gets merged first.
2. **Choose the required checks** from the workflows on the default branch:
   - always `human-review`, the status its workflow sets;
   - each job that runs on `pull_request` and must pass (lint, build, tests). Its check is named by the job's `name:`,
     or by its key when there is none; a matrix job reports one check per combination, `name (value)`;
   - not the `pr-size` or `human-review` workflows' own jobs: they never block a merge;
   - not a job whose workflow filters `pull_request` by `paths`, `paths-ignore` or `branches`: a PR the filter skips
     never reports the check, and waits for it forever. Say so, and suggest removing the filter;
   - not a check under **Checks not required** in the stack card.

   When a recent PR exists, compare with its real check names (`gh pr checks <n>`): one typo blocks every PR.
3. **Show and wait for an OK:** the checks, and what the ruleset `claude-kits: main` does:
   - a PR for every change, with no approvals required: a solo owner can't approve their own PR, and `human-review` is
     the gate;
   - each check must pass, set by GitHub Actions; a status posted any other way doesn't count;
   - no force pushes, no deleting the branch, and no bypass, admins included;
   - branches needn't be up to date with `main`, unless the human wants that (`--strict`). The cost: each merge makes
     the other open PRs update, and every update needs a new review record.

   A check the human leaves out on purpose goes under **Checks not required** in the stack card, so `/next` stops
   suggesting it.
4. **Apply:** `bash "${CLAUDE_SKILL_DIR}/protect-main.sh" [--strict] <check>...`. Running it again only adds checks
   and never loosens anything. Removing a check, or switching the ruleset off, is the human's, in Settings → Rules →
   Rulesets; the merge guard stops Claude doing it with `gh api`.
5. **Report** what the script printed: the ruleset's link, its checks, and any note about a classic branch protection
   rule, which the human can delete in Settings → Branches once the ruleset looks right.

Done when the script has printed the ruleset, or the human has chosen to wait. When CI gains a job later, `/next` names
it and this step runs again.
