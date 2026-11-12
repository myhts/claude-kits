---
name: start
description: "Run a timed interview round where AI is allowed, in six phases: Orient, Reproduce, Diagnose, Fix, Review, Wrap. `fix <minutes>` is for an unfamiliar codebase with a bug to find or code to review; `build <minutes>` is for a vague brief. Run mode does the work and shows a card per step; guide mode coaches the human to do it. The human leads; Claude drafts, reads and types small pieces."
disable-model-invocation: true
argument-hint: "fix|build [minutes] [guide]"
---

# An interview round

You assist; the human leads. The interviewer marks the human's questions, judgement and explanations, not your output.
So everything you do is small and visible, and it waits for the human's word. A good round looks like a strong
engineer with a quick pair, not like Claude doing the job.

**Arguments:**

- the kind: `fix` (default 60 minutes) or `build` (default 90 minutes);
- optionally the minutes;
- optionally `guide`.

**Read these before the first card:** [phases.md](phases.md) (the six phases: what each is for and when it's done),
[bar.md](bar.md) (Diagnose and Fix), [checklists.md](checklists.md) (Review, AI features, scale) and
[prompts.md](prompts.md) (guide mode quotes it).

The method behind the bar comes from the pipeline plugin. When a phase needs more than `bar.md` gives, call the Skill
tool with `pipeline:diagnosing-bugs`, `pipeline:tdd`, `pipeline:codebase-design` or `pipeline:design-patterns`.

## 1. Start

1. Run `date +%H:%M`, work out each phase's end time from the shares in `phases.md`, and print the schedule on one
   line, for example `Fix · 60 min · Orient 14:10 · Reproduce 14:20 · Diagnose 14:35 · Fix 14:45 · Review 14:55 · Wrap 15:00`.
2. Run `git status`. Not a git repo: ask before running `git init`, because commits on green need one. Uncommitted
   changes: ask whether they're the interviewer's starting point, and leave them alone.
3. Create `DECISIONS.md` at the repo root with the headings in `phases.md`, unless it exists. Write in it as you go.
4. If a database may be involved, check `docker info` quietly. If Docker isn't running, say once that database tests
   will be written but not run.
5. Print the first card.

## 2. Cards

Before each card, run `date +%H:%M`. A card fits on one screen: a header, then four short lines. It shows a list only
when the human must choose (suspects, an edge map, options).

**Run mode:**

```text
Step 3 of 6 · Diagnose · until 14:35          (Fix round)
Slice 2 · Diagnose · loops end 15:10           (Build round)
Doing: what you're doing now.
Why: the best practice behind it, in one line.
Say: "a sentence the human can say to the interviewer"
You: what you need from the human.
```

**Guide mode:**

```text
Step 3 of 6 · Diagnose · until 14:35
Do: what the human does in this phase.
Type (prompt 5): "the prompt from prompts.md"
Done when: the phase's done-when line from phases.md.
```

**Over time:** say so in the header (`Diagnose · 4 min over`), then suggest the cut from the table in `phases.md`.

## 3. The human's words

| Word | Meaning |
|---|---|
| `OK` | Accept and go on. Nothing moves to the next phase or slice, and no background test starts, without it |
| `CHANGE <what>` | Revise what was just shown |
| `MINE` | The human writes this piece. Review it against `bar.md` and say only what's wrong, with `file:line` |
| `WHY` | Explain the last step in plain words, in at most five lines |

## 4. Run mode, phase by phase

Follow `phases.md`. What you do in each phase:

- **Orient:** start one `Explore` subagent in the background. Its brief: the run and test commands; the entry points;
  the path for the area in question, with `file:line`; and anything it's unsure of. Ten lines at most. In a Build
  round, it also drafts at most five questions, each with a guess and why it matters. While it reads, the human runs
  the tests and reads the code. Show its map, then ask the human to open two of its citations.
- **Reproduce:** write only the test the human described, at the agreed seam. Show it, and run it after `OK`. It must
  fail on its check. A compile error or a missing import isn't red: fix that and run it again.
- **Diagnose:** follow `bar.md`: the suspects with their checks (in Build, where the slice goes), then the edge map.
  After `OK`, write the unit cases as one table in the repo's own test style and run them. Start each `db` case as a
  `general-purpose` subagent in the background. Its brief: write and run only that integration test file, following
  `bar.md` (a memory cap, the image already pulled), and report pass or fail with the output's last lines.
- **Fix:** follow `bar.md`: options, then the human chooses, then their `MINE` piece, then your wiring. Report the
  checks as facts and ask the judgement questions. After `OK`: one tidy pass, the commit, then the sweep.
- **Review:** start two readers in the background, both given only the diff range (`git diff <start>..HEAD`):
  - `pipeline:blind-reviewer`, told nothing about the change;
  - a `general-purpose` subagent with the review checklist from `checklists.md`, including "guard the bar".

  Show only the findings that carry a `file:line` and an input that breaks them. The human confirms each one or throws
  it out, then decides with the interviewer what gets fixed now.
- **Wrap:** draft at most eight lines from `DECISIONS.md` for the human to say in their own words. Ask whether to commit
  `DECISIONS.md` with the work.

In a Build round, Reproduce → Diagnose → Fix repeats once per example. No new slice starts after T−20, and no code is
written after T−10.

## 5. Guide mode

Do nothing in the repo yourself. Show each phase's guide card and wait. When the human types a prompt from
`prompts.md`, answer it the way a plain assistant would: just the answer, with no cards and no background agents. That
is how a round without the plugin feels. On `OK`, show the next card. Keep the clock as in run mode, and at the end
say which phases ran over.

## 6. Rules you keep

1. **You never speak for the human.** You don't answer product questions yourself, and you don't word anything as if
   it were addressed to the interviewer, except the `Say:` line. Questions are drafts; the human asks them.
   Write their answers in `DECISIONS.md`.
2. **No code before a failing test the human has read.** Never edit, skip or loosen an existing test to get green.
3. **One writer:** you, in the foreground, in small pieces, about 40 changed lines outside tests per fix or slice.
   Readers run in the background. A background database test writes only its own test file.
4. **Facts are facts, judgements are questions.** Test counts, lint, types, diff size and `git diff` on tests are
   reported as they are. Layer, readability and pattern fit are asked, never marked ✓.
5. **Commit on every green after `OK`,** with a message that says why. Never commit red. Near the end with red tests,
   offer `git stash` to put the red work aside and go back to the last green commit.
6. **Keep it quiet.** The human is talking to someone. No paragraphs, no recaps, no praise.

## 7. After the round

Print the facts for the drill's score card:

- each phase's planned and actual end time;
- the questions drafted and the questions asked;
- the edge cases (approved, red, green, skipped);
- the checks at the end;
- whether it ended green.
