# The six phases

**Orient · Reproduce · Diagnose · Fix · Review · Wrap.** The same words for both kinds of round, so you always know
where you are and what comes next.

- **A Fix round** (an unfamiliar codebase, a bug or a review): each phase runs once. With several bugs, Reproduce,
  Diagnose and Fix repeat for each.
- **A Build round** (a vague brief): Orient once, then Reproduce → Diagnose → Fix once per slice, then Review and Wrap.
  A missing feature is treated like a bug: its example is "reproduced" as a failing test.

## The clock

| Phase | Fix, 60 min from 14:00 | Share | Build, 90 min from 14:00 | Share |
|---|---|---|---|---|
| Orient | until 14:10 | 1/6 | until 14:12 | about 1/7 |
| Reproduce | until 14:20 | 1/6 | in the loops | |
| Diagnose | until 14:35 | 1/4 | in the loops | |
| Fix | until 14:45 | 1/6 | loops end 15:10 | to T−20 |
| Review | until 14:55 | 1/6 | until 15:20 | to T−10 |
| Wrap | until 15:00 | 1/12 | until 15:30 | the last 10 |

Other lengths scale by the shares. The first Build loop is the skeleton: the thinnest path end to end.

## Orient

**Why:** you can't judge a change in code you haven't seen run, and in a Build round the questions decide what gets
built.

**You:**

- **Fix:** change nothing. Run the app and its tests and note what passes. Open the entry point for the area in question
  and follow one request through. Say the map aloud.
- **Build:** read the brief and the code. Ask at most five questions, each with your guess. Name the user and the one
  job. Write 3–5 examples (input → expected) and a "not now" list. Restate the brief and get a yes.

**Claude:** one reader maps the code in the background: run and test commands, entry points, and the path for the
area in question, with `file:line`. In a Build round it also drafts the questions, each with a guess and why it
matters. You ask them; Claude never does.

**Done when:** you can say the path aloud, you've checked two of the reader's citations, and (Build) the examples are
agreed.

## Reproduce

**Why:** a bug you haven't seen fail can't be shown fixed, and a feature with no failing example has no finish line.

**You:** say the expected behaviour in one sentence. Ask when it's unclear: the answer decides what the test checks.
Read the test before it runs.

**Claude:** writes only that test, at the agreed seam, and runs it.

**Done when:** the test fails on its check, not on a compile error or a missing import.

## Diagnose

**Why:** a fix without a proven cause often fixes only the symptom, and a cause without its edges gets fixed once and
breaks next door.

**You:** run the checks that rule suspects out, approve the edge map, and say aloud what you're skipping.

**Claude:**

1. lists up to three suspects, each with the one check that rules it out (Fix), or the design options for where the
   slice goes (Build);
2. proposes the edge map: at most eight cases with expected results and risk;
3. on your `OK`, writes the unit cases and runs them, and starts any database case in the background.

See [bar.md](bar.md).

**Done when:** the cause is shown by code you've read or a narrower test, and the approved cases exist. A red case is
a bug; a green one documents today's behaviour.

## Fix

**Why:** the interviewer judges the shape of the change as much as whether it works.

**You:** choose from the options and say the trade-off. Write the core rule yourself (`MINE`). Read the diff.

**Claude:** offers two or three options, wires your piece in, runs the checks and reports them as facts. It asks you
the judgement questions rather than answering them. See [bar.md](bar.md).

**Done when:** the Diagnose tests and the whole suite pass, the checks are clean, you've read the diff, and it's
committed with a message that says why. Then sweep for the same mistake elsewhere: fix it, or note it.

## Review

**Why:** fresh eyes find what the person who wrote the code can't see.

**You:** talk the interviewer through what you changed while the readers work. Open each finding before you repeat
it. Throw out the false ones aloud.

**Claude:** two readers in the background. One is told nothing about the change; the other uses the checklist in
[checklists.md](checklists.md). Each finding comes with `file:line` and an input that breaks it.

**Done when:** each finding is confirmed or thrown out. Fix what you agree with the interviewer, and list the rest.

## Wrap

**Why:** the last five minutes are what the interviewer remembers.

**You:** say it in your own words:

- **Fix round:** what you found and how you know, what you fixed, what else you'd flag, what you'd do next, and what
  you didn't check.
- **Build round:** demo it, then the trade-offs, how it scales, and what's next.

**Claude:** drafts at most eight lines from `DECISIONS.md` for you to read from.

## When a phase runs over

Cut from the bottom of its list:

| Phase | Cut first |
|---|---|
| Orient | the second citation check (never the test run) |
| Diagnose | low-risk edge cases; the database case can be described, not run |
| Fix | the tidy pass (the sweep can be a note) |
| Review | the second reader |
| Build loops | the next slice: finish the current one green, then go to Review |

Never cut Reproduce, and never end red. Near the end with red tests, put the red work aside (`git stash`) and go back
to the last green commit.

## `DECISIONS.md`

One file at the root of their repo, kept up as you go, and committed with the work unless you say otherwise:

```markdown
# Decisions

## The brief (or the report) in my words
## Questions and answers
## Assumptions (said aloud)
## Edge maps
## Decisions (and the option turned down)
## Not now
## How it scales (Build)
## What's next
## Not checked
```
