---
name: implement
description: "Build one ticket, or the ready tickets of a spec, into a reviewed pull request: test-first in the project's build mode (learn, build-with-me or deliver), then automated checks, two reviewers, fixes and a PR body. Never merges."
disable-model-invocation: true
---

Turn a ticket into a pull request a human can review in minutes. The implementer makes it work; fresh reviewers make it
good; the human decides. Run this in the main session: it starts the subagents, and a subagent can't start others.

Agents named here are the pipeline plugin's (`pipeline:implementer`, `pipeline:code-reviewer`, and so on). Arguments:
a ticket or spec reference, and optionally a mode (`learn`, `build-with-me`, `deliver`) that overrides the stack card.

**One ticket, one session.** If this conversation already holds other work (planning, another ticket, a review), say
so in one line before step 1 and suggest `/clear`, then the same command again. Nothing is lost: everything this
skill needs is on GitHub and in the repo. An old conversation is re-read on every turn and fills the context sooner.
Carry on if the human says so.

## 1. Load the work

1. Read `docs/agents/stack.md` (commands, mode, PR budget) and fetch the ticket with the commands in
   `docs/agents/issue-tracker.md`. State the ticket's title. An ambiguous reference: ask.
2. **A spec instead of a ticket:** list its tickets and their blocking links, and find the **frontier** (open tickets
   whose blockers are all closed). In deliver mode, run steps 2–8 for every frontier ticket in parallel, each with its
   own implementer, worktree and PR. In the other modes, ask which frontier ticket comes first and work one at a time.
   A blocked ticket waits until its blockers' PRs merge; run `/implement <spec>` again then.
3. **Read it cold:** for each ticket you'll build, start a `general-purpose` subagent, which has none of this
   conversation, and give it only the ticket and spec references and `docs/agents/issue-tracker.md`. It reads those and
   the code, then reports:
   - in its own words, what the ticket asks for, and how the code works today according to the spec (2–5 sentences
     each);
   - each decision the ticket leaves to the implementer: a name, a data shape, an edge case, a library;
   - each claim about today's code that the code contradicts, with `file:line`.

   Show the human the paraphrase, to compare with what they meant, and settle each open decision with them. Post the
   answers as one comment on the ticket, where an implementer will read them. Skip this step when the human calls the
   ticket tiny.
4. **Seams:** take the testing seams from the ticket or its spec. If none are written, propose them (the public
   interface, and what each seam catches and misses) and get them confirmed. The `tdd` skill tests only at agreed seams.

Done when the title, the mode, the seams and the base branch are stated and agreed, and the ticket's open decisions
are settled.

## 2. Build, in the chosen mode

- **learn:** call the Skill tool with `learning-loop` for this ticket. The learner writes the code. Claude teaches,
  hints and answers through `mentor`, and writes no production code unless the learner asks for one example.
- **build-with-me:** work in blocks of one idea and at most ~60 changed lines. First list the blocks and suggest
  which ones the human writes: the ideas new to them and the parts they'd have to explain to someone else, such as a
  prompt, a tool description, an eval case or a core rule. The plumbing goes to the implementer, and the human changes
  the split as they like. A block the human takes goes straight to **MINE** below. For each other block:
  1. The `implementer` writes the block.
  2. Show the diff and ask one or two questions about it (explain, predict, failure case, spot the risk, or how it
     compares with a stack the human knows). Check the answer against the code.
  3. Wait for the human's word:
     - **OK** → next block.
     - **CHANGE** → revise the block.
     - **MINE** → the human writes the block, and `code-reviewer` reviews it in teaching mode.
     - **WHY** → `mentor` explains.

  Record a wrong answer in `docs/learning/LESSONS.md` when the project has one. Never start the next block without OK.
- **deliver:** start a fresh `implementer` in its own worktree, on a branch `ticket/<number>-<slug>` from the base
  branch. Give it pointers, not copies: the ticket, the spec, the stack card, the agreed seams. It builds test-first
  with `tdd`, runs the narrow checks often and the full verify once at the end, and commits to its branch.

Done when the ticket's acceptance criteria pass at the agreed seams and the full verify (container tests included) is
green.

## 3. Automated checks

Run the stack card's lint and full verify on the branch. Fix red before any review: reviewers read finished work.

## 4. Automated review

Start these in parallel, each in a fresh context, and give each only what its brief says:

| Reviewer | Give it | Runs when |
|---|---|---|
| `code-reviewer`, axis **standards** | the diff command (`git diff <base>...HEAD`), the mode | always |
| `code-reviewer`, axis **spec** | the diff command, the ticket and spec references, the event model if the project has `docs/eventstorming/` | always |
| `blind-reviewer` | the scope only (the diff range); never a description of the feature | always |
| `spring-security-reviewer` when the stack card's pack is `spring`, otherwise `security-reviewer` | the diff command | the diff touches input handling, authentication, secrets or model calls |
| `deploy-reviewer` | the changed build and deploy files | the diff touches a Dockerfile, compose, CI or Kubernetes files |

Keep the reports separate; never merge them into one ranking. A reviewer that fails or returns no report hasn't
reviewed: start it once more, and if it fails again, report it as **not run**, never as clean.

## 5. Fix

Sort the findings first. You hold the ticket, the spec and the seams; the fixer won't.

- **Confirm** each must-fix against the code, with a test that fails or the path traced from an input to the wrong
  result. Only confirmed findings get fixed.
- **Contest** a finding the code shows is wrong, and cite the `file:line` that shows it. "It's intended" isn't
  evidence, and neither is having written the code: if the code alone doesn't show why it's fine, it's a judgement
  call.
- **Pre-existing:** a finding on lines this diff didn't change becomes a proposed follow-up ticket, not part of this
  PR, unless the change makes it reachable or worse.

Then fix:

- **deliver and build-with-me:** a fresh `implementer` fixes the confirmed must-fix findings, plus the should-fix ones
  it can fix within the ticket, then reruns the full verify. Each fix covers every place the same mistake appears, not
  only the line cited. In build-with-me, each fix is a block like any other.
- **learn:** the findings go to the learner, who fixes them.

Then review once more, and only once: each reviewer whose findings were fixed reads only the commits made since its
first review. Whatever is still open after that goes to the human, with no third round.

Collect the **judgement calls** into one list for the human: smells, trade-offs, anything a reviewer marked as a matter
of taste, contested findings with their evidence, and the proposed follow-up tickets. Done when the confirmed must-fix
findings are fixed, the second review is done, whatever it left open is on the list, and the verify is green.

## 6. Keep the PR small

Count the changed lines against the stack card's budget, leaving out lockfiles, generated code and snapshots. Over
budget: propose a split before opening anything. A prefactor goes in its own PR, and the rest goes into new tickets
through `/to-tickets`.

## 7. Open the pull request

1. Call the Skill tool with `pr` to write the body: summary as a picture, evidence before and after, merge danger.
2. For evidence, show the test that failed before the change and passes after it. For a visible change, have
   `e2e-tester` take a screenshot of the running app with the Playwright MCP.
3. Push the branch (`git push -u origin <branch>`) and open the PR with `gh pr create`, its body ending in
   `Closes #<ticket>`.
4. Post the judgement calls and a one-line summary per reviewer as a PR comment.

## 8. Stop

Report the PR link, the reviewer summaries, the judgement calls, and the next step: `/human-review <PR>`, in a fresh
session (`/clear` first). The human merges; this skill never does, and the merge guard blocks it anyway.
