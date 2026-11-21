# Stack card

Every pipeline stage and agent reads this file for the project's commands, pack and build mode. `/setup-project`
wrote it; edit it by hand whenever the project changes.

## Pack

- **Pack:** <spring | none>. With `none`, every stage and agent works the same; what's missing is stack knowledge. The
  standards review uses `CODING_STANDARDS.md` and the smell baseline, and `/deploy` writes its files from the shape
  in its "No pack" list. Delete the two pack lines below.
- **Plugins:** `pipeline@kits`, `<pack>@kits`
- **Review checklist:** `<pack>@kits: <path>`, e.g. `spring@kits: .claude/skills/spring-boot/review-checklist.md`. The
  `code-reviewer` standards axis reads it, together with `CODING_STANDARDS.md`.
- **Pack templates:** `<pack>@kits: <path>`, e.g. `spring@kits: .claude/skills/build-templates/` (Dockerfile, CI,
  Kustomize base and overlays, deploy workflow).
- A path written `<plugin>@kits: <path>` is inside that plugin's folder. `claude plugin list --json` gives the folder as
  `installPath`.

## Commands

`/setup-project` ran each command once. "not set up yet" means the project doesn't have it so far.

| Purpose | Command |
|---|---|
| Compile or typecheck (fast) | |
| One test file | |
| Full verify, including container tests | |
| Lint and format check | |
| Module-boundary check | |
| End-to-end tests | |
| Run locally | |

## Migrations

- **Tool:** <Flyway | Drizzle | Alembic | ... | none yet>
- **Rule:** never edit an applied migration. Change schemas expand → migrate → contract, so the previous version still
  runs against the new schema and a rollback stays safe.

## Build mode

- **Default:** <learn | build-with-me | deliver>
  - **learn:** the learner writes the code; Claude teaches and reviews.
  - **build-with-me:** the implementer writes one block of at most ~60 lines; the human checks it, answers 1–2
    questions and replies OK, CHANGE, MINE or WHY.
  - **deliver:** the implementer builds the whole ticket; the automated review loop runs before the PR.
- A ticket can override it: `/implement <ticket> deliver`.

## Review models

The model and effort each reviewer runs on in `/implement`'s automated review. `session` means whatever your session
is on, which is how every reviewer ran before this section existed.

| Reviewer | Model and effort |
|---|---|
| `code-reviewer` | <session | sonnet, high> |
| `blind-reviewer` | session |
| `security-reviewer` or `spring-security-reviewer` | session |
| `deploy-reviewer` | session |

- **What was measured** (2026-11-21, one fixture with 10 planted defects): `code-reviewer` on Sonnet at high effort
  scored the same as on Opus at high effort, for about a third less per review. It also wrote twice as many
  opinion-only findings. Every setting found all 10 defects, so the test can't show whether the bigger model finds
  harder ones. The other reviewers have not been measured.
- **`blind-reviewer`: move it off `session` only if you have to**, for example when reviews keep running into your
  plan's limit. It is the independent check on a risky change, it works without the project's checklists, and
  nothing has measured it on a smaller model.
- **To change a setting:** edit the table (`session`, or `<model>, <effort>` such as `sonnet, high` or
  `opus, medium`), or run `/pipeline:setup-project review-models` to be asked again with this note. For one review
  only, say it with the ticket: `/implement <ticket>, code-reviewer on session`.

## Pull requests

- **Base branch:** main
- **Budget:** about 400 changed lines, not counting lockfiles, generated code or snapshots. Over budget, `/implement`
  proposes a split; CI labels any larger PR `size/large`.
- **Checks not required:** none
  - Checks that PRs run but `main` leaves out on purpose, separated by commas. `/setup-project protect` makes every
    other check required, and `/next` names any that isn't yet.

## Deploy

- **Target:** <not chosen yet: run /deploy>
- **Registry:** <ghcr.io/owner/repo>
- **Cluster and namespaces:** <host> · `app-staging`, `app-prod`
- **Overlays:** `k8s/overlays/staging`, `k8s/overlays/prod`
- **Smoke e2e hosts:** <staging host only>
