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
