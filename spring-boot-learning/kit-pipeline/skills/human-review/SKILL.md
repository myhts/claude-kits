---
name: human-review
description: "Walk the human through a pull request before they merge it: an impact report and questions sized by the PR's merge danger, each answer checked against the code, then a review record tied to the head commit. Never merges."
disable-model-invocation: true
---

The human's understanding is the gate; agent reviews are evidence. This skill makes that understanding fast and leaves
a record CI can check. It asks and checks; it doesn't grade. Argument: the PR number.

## 1. Load the pull request

- `gh pr view <n> --json title,body,headRefOid,baseRefName,files,additions,deletions,comments` and `gh pr diff <n>`.
- The ticket and spec it closes, the reviewer summary and judgement calls `/implement` posted, and
  `docs/agents/stack.md` (build mode, migration tool).
- `GLOSSARY.md` and the ADRs in the touched area, so every question uses the project's words.

Done when you can state, in one line, what the PR changes and why.

## 2. Choose the depth

Read **Merge Danger** in the PR body. If it's missing or looks wrong, judge it yourself:

- **One-way or two-way door:** can the merge be walked back cleanly? Data loss, a sent message, a published contract or
  a destructive migration make it one-way.
- **Blast radius:** how much breaks if it's wrong.

| Situation | Depth |
|---|---|
| Learning project (stack card mode `learn` or `build-with-me`) | **Full**, always |
| One-way door, or a large blast radius | **Full** |
| Two-way door with a small blast radius | **Quick** |

State the depth and the reason in one line. The human can always ask for full.

## 3. Show what changed

- **Quick:** the PR body's summary and evidence, and whether the evidence convinces (a test that failed before and
  passes after, or a screenshot).
- **Full:** an impact report, in this order:
  1. modules or contexts touched
  2. contracts changed (endpoints, events and topics, schema)
  3. migrations, and whether each is reversible (expand/contract)
  4. anything touching transactions, concurrency, security or configuration
  5. the door and the blast radius
  6. what the tests don't cover
  7. reviewer findings still open

## 4. Ask, then check

Ask **2 questions** for quick and **5–8** for full, mixing these kinds:

| Kind | Asks |
|---|---|
| Explain | why the code takes this approach |
| Predict | what happens in a given case, such as two requests at once or a duplicate message |
| Impact | who else reacts to this change, and what happens if they're down |
| Rollback | what breaks if this release is reverted after it ran |
| Incident | where to look first if this feature fails in production |

Check each answer against the code. Reply "matches", or name what was missed with `file:line`. The human may answer
again. For a **Predict** question, run the test or scenario after they answer, so they see whether the prediction held.

Then go through the judgement calls one by one. The human decides each: fix in this PR, follow-up ticket, or accept as
is.

Done when every question has a checked answer and every judgement call has a decision.

## 5. Record

Draft the record, show it, and post it as a PR comment only after the human confirms:

```markdown
<!-- human-review-record sha=<headRefOid> -->
## Human review record

**Depth:** quick | full: <reason> · **Head:** <short sha>

| Question | Answer, in short | Check |
|---|---|---|

**Gaps found and how they were resolved:** ...
**Judgement calls:** <decision for each>

- [ ] I read every changed file (full) / the summary and evidence (quick)
- [ ] I looked at the test or e2e evidence
- [ ] Migrations are reversible, or there's a plan
- [ ] I know how to roll this back
```

The human ticks the boxes. The `human-review` CI check turns green only for a record that names the current head
commit; any new commit makes it stale, and this skill runs again.

## 6. Feed the system

Ask whether anything in this review is a pattern rather than a one-off ("I keep seeing this"). If so, the human leaves
it as a line comment on the PR worded as a rule. `/retro` reads PR comments and turns repeated ones into a check or a
coding standard, so no comment needs leaving twice.

## 7. Stop

Tell the human the PR is ready for them to merge, or what is still open. The human merges; this skill never does.
