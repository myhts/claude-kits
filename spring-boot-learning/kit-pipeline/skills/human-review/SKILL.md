---
name: human-review
description: "Walk the human through a pull request before they merge it: a plain-words walkthrough of every changed file, then questions sized by the PR's merge danger, each answer checked against the code, then a review record tied to the head commit. Never merges."
disable-model-invocation: true
---

The human's understanding is the gate; agent reviews are evidence. This skill makes that understanding fast and leaves
a record CI can check. It asks and checks; it doesn't grade. Argument: the PR number.

**A fresh session.** If this conversation already holds other work, building this PR included, say so in one line and
suggest `/clear`, then the same command again. Everything the review needs is on the PR, and it goes better without
the builder's reasoning in view. Carry on if the human says so.

## 1. Load the pull request

- `gh pr view <n> --json title,body,headRefOid,baseRefName,files,additions,deletions,comments` and `gh pr diff <n>`.
- The ticket and spec it closes, the reviewer summary and judgement calls `/implement` posted, and
  `docs/agents/stack.md` (build mode, migration tool).
- `GLOSSARY.md` and the ADRs in the touched area, so every question uses the project's words.

Done when you can state, in one line, what the PR changes and why.

## 2. Choose the depth

Read **Merge Danger** in the PR body. If it's missing or looks wrong, judge it yourself:

- **One-way or two-way door:** can the merge be walked back cleanly? Data loss, a sent message, a published contract, a
  destructive migration or an exposed secret make it one-way.
- **Blast radius:** how much breaks if it's wrong, and for whom. It's small when a fault would show at once and reach
  no real users, data, money or access.

Then read how the change was built: the first line of the comment `/implement` posted (`Built in: <mode>`). A PR
opened without `/implement`, such as a tiny change, counts as `deliver`. If a PR from `/implement` doesn't say, ask
the human in one line whether this is code they want to go through closely.

| Situation | Depth |
|---|---|
| One-way door, or a large blast radius | **Full** |
| Changes the checks themselves: `.github/workflows/`, or the hooks and settings in `.claude/` (green checks can't vouch for a PR that changes them) | **Full** |
| Built in `learn` or `build-with-me`: code the human chose to write or to follow block by block | **Full** |
| Two-way door with a small blast radius, built in `deliver` | **Quick** |

State the depth and the reason in one line. The human can ask for the other depth; the record then says they chose
it.

## 3. Show what changed

**Start with a walkthrough, at every depth.** The human may not have watched this change being built. Tell it so they
can follow it without opening the diff:

1. **The goal**, in one or two sentences: what the PR is for.
2. **Every changed file, in the order the change works**, not the order of the diff: the code that does the job
   first, then its tests, then config, CI and docs. Put the files under two or three plain headings. For each file,
   give its path and one or two sentences: what it does, and why this change needs it. Files that changed for the
   same small reason share a line. Lockfiles, snapshots and generated code get one line together.
3. **What the tests prove**, as a short table: the situation, and the result the tests expect.
4. **The critical places:** the few lines where a mistake would cost the most, such as a rule, a limit, a security
   check, a query, a migration or a contract. At most three in a quick review and six in a full one. For each, give
   `path:line`, a snippet of at most ~8 lines copied from the diff, one sentence on what it does and one on what goes
   wrong if it's wrong. A PR with none says so.

Write it in plain words:

- Short sentences, one idea each. Say what the code does before how it does it.
- Explain a term the first time it appears, unless the glossary has it.
- Describe only what the diff shows. If a file's purpose isn't clear from the code, say so; don't guess.
- Leave out praise, the review's history and anything the human doesn't need in order to follow the change.

Then let the human ask about any part before the questions start. After the walkthrough, add what the depth calls
for:

- **Quick:** whether the PR body's evidence convinces (a test that failed before and passes after, or a screenshot).
- **Full:** an impact report, in this order:
  1. modules or contexts touched
  2. contracts changed (endpoints, events and topics, schema)
  3. migrations, and whether each is reversible (expand/contract)
  4. anything touching transactions, concurrency, security or configuration
  5. the door and the blast radius
  6. what the tests don't cover
  7. reviewer findings still open

## 4. Ask, then check

Ask **2 questions** for quick and **5–8** for full, mixing these kinds. Don't ask for something the walkthrough
already said word for word: ask what follows from it.

| Kind | Asks |
|---|---|
| Explain | why the code takes this approach |
| Predict | what happens in a given case, such as two requests at once or a duplicate message |
| Impact | who else reacts to this change, and what happens if they're down |
| Rollback | what breaks if this release is reverted after it ran |
| Incident | where to look first if this feature fails in production |

Check each answer against the code. Reply "matches", or name what was missed with `file:line`. The human may answer
again. For a **Predict** question, run the test or scenario after they answer, so they see whether the prediction held.

**Break it**, in a full review, and in a quick one when the human asks. Green tests show that a critical place
works; only a red one shows that a test would notice it failing. Take up to three of the walkthrough's critical
places, the costliest first, one at a time:

1. Ask the human which test goes red if that line is wrong.
2. In a clean checkout of the head commit (the ticket's worktree, or a new one), make the smallest edit that makes
   the line wrong: flip the comparison, drop the check, change the limit. Run the narrowest test command on the stack
   card that covers the place, and show the result.
3. Restore the file and show that `git status` is clean before the next place. The break lives only in the working
   tree.

A test that goes red guards the place: name it. If every test stays green, nothing guards it, and "no test fails
when `path:line` is wrong" joins the judgement calls.

Then go through the judgement calls one by one. The human decides each: fix in this PR, follow-up ticket, or accept as
is. A follow-up is a ticket of its own, written with `/to-tickets`. Never add it as a comment on another ticket: it
grows that ticket where no budget counts it.

Done when every question has a checked answer, every broken place is restored, and every judgement call has a
decision.

## 5. Record

Draft the record, show it, and post it as a PR comment only after the human confirms:

```markdown
<!-- human-review-record sha=<headRefOid> -->
## Human review record

**Depth:** quick | full: <reason> · **Head:** <short sha>

| Question | Answer, in short | Check |
|---|---|---|

**Gaps found and how they were resolved:** ...
**Break it:** <each place broken: the test that went red, or "no test went red">
**Judgement calls:** <decision for each>

- [ ] I read every changed file (full) / the summary and evidence (quick)
- [ ] I looked at the test or e2e evidence
- [ ] Migrations are reversible, or there's a plan
- [ ] I know how to roll this back

<what usage.sh printed, unchanged>
```

For the last part, run `bash "${CLAUDE_SKILL_DIR}/../implement/usage.sh" human-review` when you draft the record,
and paste what it prints. Never write those numbers yourself; if it says "not available", paste that one line.

The human ticks the boxes. The `human-review` CI check turns green only for a record that names the current head
commit; any new commit makes it stale, and this skill runs again.

## 6. Feed the system

Ask whether anything in this review is a pattern rather than a one-off ("I keep seeing this"). If so, the human leaves
it as a line comment on the PR worded as a rule. `/retro` reads PR comments and turns repeated ones into a check or a
coding standard, so no comment needs leaving twice.

## 7. Stop

Tell the human the PR is ready for them to merge, or what is still open. After the merge, the next ticket starts in a
fresh session: `/clear`, then `/pipeline:next`. The human merges; this skill never does.
