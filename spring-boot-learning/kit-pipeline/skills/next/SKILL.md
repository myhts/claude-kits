---
name: next
description: "Say where this repository is in the delivery flow and the one thing to do next, from its real state: open PRs and their review records, ready tickets, specs, wayfinder maps, and CI and deploys on main. Changes nothing."
disable-model-invocation: true
---

Answer "what now?" in a few lines, from the repo's state rather than from memory. A script reads everything in one go;
this skill presents what it found. It changes nothing: no comments, labels, branches or merges.

## 1. Read

Run `bash "${CLAUDE_SKILL_DIR}/where.sh"` from the repository. It prints tab-separated lines:

| Line | Fields |
|---|---|
| `REPO` | owner/repo, current branch, build mode |
| `WARN` | something it couldn't read |
| `NEXT` | step, what to type or do, why |
| `ALSO` | the same, for up to three more open items |

The script checks from production back to planning, so work in flight finishes before new work starts:

1. `main` not protected yet, once the setup is on it (a minute's work, so it goes first)
2. a deploy waiting for approval
3. a red `main`
4. a PR ready to merge
5. a PR waiting for review
6. a PR to fix
7. work on a branch with no PR
8. a ready ticket
9. a delivered spec
10. a spec with no tickets
11. an open wayfinder map
12. otherwise, a new idea

The first match is NEXT. Two things are only ever an ALSO: merged code that nothing deploys, because not every project
ships, and a check that PRs run but `main` doesn't require yet, which `/pipeline:setup-project protect` adds.

## 2. Show it

Reply in this shape, and no longer:

```markdown
**Step 6 of 9 · Your review** · owner/repo on `branch` · deliver mode

Plan → Storm → Build → PR → Agents → **Your review** → Merge → Actions → K8s

**Next:** `/pipeline:human-review #57`
"Reserve a title" has no review record for its head commit 1a2b3c4 yet.

**Also open**
- Step 3 · `/pipeline:implement #43`: "Notify the member" is ready: nothing blocks it, and it has no PR or branch yet.
```

- **Step names:** 0 Set up · 1 Plan the language · 2 Event Storming, spec and tickets · 3 Test-first build · 4 A small
  PR · 5 Two reviewers · 6 Your review · 7 You merge · 8 GitHub Actions · 9 Kubernetes.
- **The strip** uses the short names, with the current step in bold. Leave it out for step 0.
- Put a command in backticks. A URL or a plain instruction (press Merge, approve production) stays plain text.
- Leave out "deliver mode" when the mode is `-`. Leave out "Also open" when there are no ALSO lines.
- Show each WARN line last, as "Couldn't check: …".
- When this conversation already holds other work and **Next** is a command, end with: "Type it in a fresh session
  (`/clear` first)."

## 3. Stop

Don't run the next command. Pipeline commands are the human's to start, and some need what only they know: an idea, a
mode, an approval. Answer follow-up questions about the state, reading more with `gh` only if asked.
