# Interview rounds with AI

**Some interviews now let you use AI tools.** You build something from a vague brief, or you're dropped into a codebase
you've never seen and asked to find and fix a bug. You're marked on how you think, the questions you ask, and the
quality of what you ship. The `interview` plugin runs such a round with you in six phases. You lead; Claude drafts,
reads and types small pieces.

Use it only where the round allows AI, and say so at the start: *"I work with Claude Code and a practised routine; I'll
lead, and it'll do the reading and the typing."* Ask the recruiter in writing whether your own setup is allowed, because
it's decided round by round.

**Jump to:** [Install](#install) · [The picture](#the-picture-in-one-minute) · [Two modes](#two-modes) ·
[Two kinds of round](#two-kinds-of-round) · [Each phase](#each-phase) · [The bar](#the-bar-for-diagnose-and-fix) ·
[Without the plugin](#without-the-plugin) · [Before the day](#before-the-day) ·
[When something goes wrong](#when-something-goes-wrong) · [A worked example](#a-worked-example)

## Install

```bash
claude plugin marketplace add myhts/claude-kits      # once; skip it if you already use claude-kits
claude plugin install interview@kits --scope user    # also installs the pipeline plugin it builds on
```

Then start a new session. **Why user scope:** in an interview the repo is theirs. User scope keeps the plugin in your
home folder, so it works in any repo you open and writes nothing into theirs.

The `pipeline` plugin comes with it, and its merge guard comes too. The guard stops Claude from merging, pushing to
`main` or running destructive git commands (`reset --hard`, `clean`, `branch -D`) in any repo. Your own terminal isn't
affected.

| To | Run |
|---|---|
| update | `claude plugin marketplace update kits`, then `claude plugin update interview@kits --scope user`, then a new session |
| remove | `claude plugin uninstall interview@kits --scope user` |

## The picture in one minute

**Orient · Reproduce · Diagnose · Fix · Review · Wrap.** Every round goes through these six phases, so you always know
where you are and what comes next. At each phase Claude shows a card:

```text
Step 3 of 6 · Diagnose · until 14:35
Doing: three likely causes, each with the one check that rules it out.
Why: a fix without a proven cause often fixes only the symptom.
Say: "I have three suspects; I'll check the cheapest first."
You: run the checks with me and say which one held.
```

- **Doing** is what Claude is doing now.
- **Why** is the best practice behind it.
- **Say** is a line you can say to the interviewer.
- **You** is what Claude needs from you.

You answer with four words:

| Word | Meaning |
|---|---|
| `OK` | accept and go on. Nothing moves on without it |
| `CHANGE …` | revise what was just shown |
| `MINE` | you write this piece; Claude reviews it |
| `WHY` | explain the last step in plain words |

**What Claude never does:** speak for you, write code before a failing test you've read, edit a test to get green,
choose the fix, or move on without your `OK`.

## Two modes

```text
/interview:start fix 60            run mode: Claude does the steps and shows you each one
/interview:start build 90 guide    guide mode: Claude coaches, and you do the steps
```

- **Run mode** is for rounds that allow your setup. Claude keeps the clock, runs readers in the background, writes
  `DECISIONS.md` and types small pieces, all behind your `OK`.
- **Guide mode** is the rehearsal for rounds that don't. Each card tells you what to do and which prompt to type. Claude
  answers your prompts like a plain assistant, with no cards and no background agents, so you feel what a round without
  the plugin is like.

## Two kinds of round

| Phase | **Fix round:** a bug or a review in code you haven't seen, 60 min from 14:00 | **Build round:** a vague brief, 90 min from 14:00 |
|---|---|---|
| Orient | until 14:10 | until 14:12 |
| Reproduce | until 14:20 | in each slice |
| Diagnose | until 14:35 | in each slice |
| Fix | until 14:45 | in each slice; slices end at 15:10 |
| Review | until 14:55 | until 15:20 |
| Wrap | until 15:00 | until 15:30 |

In a Build round, Reproduce → Diagnose → Fix repeats once per example of what the feature must do. A missing feature is
treated like a bug, and its example is "reproduced" as a failing test. Other lengths scale: `/interview:start fix 45`.

## Each phase

| Phase | Why | You | Claude | Done when |
|---|---|---|---|---|
| **Orient** | You can't judge a change in code you haven't seen run | **Fix:** run the tests and follow one request through. **Build:** ask at most five questions, each with your guess, and write 3–5 examples | Maps the code in the background with `file:line`, and drafts your questions | You can say the path aloud and have checked two of Claude's citations |
| **Reproduce** | A bug you haven't seen fail can't be shown fixed | Say the expected behaviour; ask if it's unclear; read the test | Writes only that test, and runs it | It fails on its check, not on an error |
| **Diagnose** | A fix without a proven cause fixes only the symptom | Run the checks; approve the edge map; say what you skip | Suspects with checks, then at most eight edge cases with expected results and risk. After your `OK`, writes the tests; database tests run in the background | The cause is shown, and the approved cases exist |
| **Fix** | The shape of the change is marked, not just that it works | Choose an option and say the trade-off; write the core rule (`MINE`); read the diff | Two or three options, wires your piece in, reports the checks as facts | Tests and suite green, diff read, committed with a reason, the same mistake swept for |
| **Review** | Fresh eyes find what the author can't | Talk through your change; confirm or throw out each finding aloud | Two readers in the background; every finding has a `file:line` and an input that breaks it | Every finding is confirmed or thrown out |
| **Wrap** | The last minutes are what's remembered | Say it in your own words | Drafts eight lines from `DECISIONS.md` | Found, how you know, fixed, next, not checked (Build: demo, trade-offs, scale) |

Running over? The card says so and suggests what to cut, lowest risk first. Reproduce is never cut, and the round never
ends red: red work is put aside with `git stash`, back to the last green commit.

**`DECISIONS.md`** is one file in their repo where your thinking shows: the brief or report in your words, questions
and answers, assumptions, edge maps, decisions with the option you turned down, what's not done now, and what's next.

## The bar for Diagnose and Fix

**Diagnose:**

- Prove the cause before changing anything.
- Map the edges from a fixed list: boundaries; the same call twice and two at once; each dependency failing; time and
  money; permissions. Expected results come from the brief or the interviewer, never from the code.
- Rank by risk, and say what you skip. A short round can't test everything, and interviewers mark the choice.
- Lay the tests out properly:
  - the name says the behaviour;
  - one behaviour per test;
  - edge cases in one table;
  - fakes only at the edges;
  - no sleeps;
  - fast tests and database tests in separate files.
- Database cases run with Testcontainers in the background after your `OK`, each container capped at 256 MB.

**Fix:**

- Options before code, the smallest first, and "no pattern" is a real option.
- Fix at the cause, in the right layer, following the repo's own conventions.
- Small: about 40 changed lines outside tests. One job per function.
- A design pattern only when you can name the problem it solves and what it costs.

Claude reports tests, lint, types, diff size and "no test edited" as facts. Whether it's in the right layer and reads
well is your call, and a fresh reader checks it again in Review.

The full version is in
[bar.md](spring-boot-learning/kit-interview/skills/start/bar.md), and the review checklist (Correct, Safe, Reliable,
Fast, Clear) is in [checklists.md](spring-boot-learning/kit-interview/skills/start/checklists.md).

## Without the plugin

The phases stay the same; only who types changes.

| The round allows | You use |
|---|---|
| your own Claude Code with plugins | run mode |
| an AI tool, but no plugins or rules files | the phases from memory (rehearsed in guide mode) and the prompts below |
| only their chat assistant, which can't edit files | the same, one function or test at a time; you make every edit |
| no AI | the same phases; the prompts become questions you ask yourself |

| # | Phase | Type |
|---|---|---|
| 1 | Orient (Build) | "Here's the brief: … List the five questions whose answers would change the design most, each with your guess and why it matters. No code." |
| 2 | Orient | "Which files handle …? Trace one request from entry to storage, citing file and line. Mark what you're unsure of." |
| 3 | Reproduce | "Write one failing test for: … → expected …. Only the test." |
| 4 | Fix | "Make this test pass with the smallest change. Don't edit any test." |
| 5 | Diagnose: the cause | "This fails with: …. Give three likely causes, each with the one check that would rule it out." |
| 6 | Diagnose: the edges | "For …, list at most eight edge cases: boundaries, twice and at once, each dependency failing, time and money, permissions. Each with input → expected (from the brief, not the code), risk, and unit or database." |
| 7 | Fix: options | "Give two or three ways to fix this, the smallest first. For each: where it lives, the pattern if any and the problem it solves, its cost, its size." |
| 8 | Fix: the sweep | "Where else in the code does this same mistake appear?" |
| 9 | Review | "Review … for bugs only: Correct, Safe, Reliable, in that order. Quote file:line and an input that breaks it. Flag any test made easier." |
| 10 | Wrap (Build) | "Given …, what breaks first at 10× and 100×? Say 'unknown' where there's no number." |
| 11 | Any time | "Explain … in five lines, and what breaks if line … is removed." Use it before you explain the code aloud |

## Before the day

- [ ] Claude Code is logged in, and you have usage to spare. A practice round shows how much a round takes.
- [ ] The plugin is installed at user scope, and a new session lists `/interview:start`.
- [ ] Docker is running (OrbStack on a Mac), and the database image is already pulled, for example
      `docker pull postgres:16-alpine`. A first pull mid-round can take longer than the test's start timeout.
- [ ] If the round needs a model API key: they provide one, or yours has a spending cap and lives in `.env`.
- [ ] Your opening sentence: which tool you use, and what you will and won't hand to it.
- [ ] One practice round in guide mode, so a round without the plugin isn't a surprise.

## When something goes wrong

| What happens | What to do |
|---|---|
| The plugin isn't allowed | Use the phases and the prompt sheet above; it's the same round |
| No Docker on their machine | Write the database test, mark it as not run, and say what it would prove |
| A phase runs over | Take the cut the card suggests, lowest risk first. Never cut Reproduce |
| Red tests near the end | `git stash` the red work, go back to the last green commit, and say what was left |
| Claude's answer looks wrong | Say so aloud and check it. Catching the AI's mistakes is marked in your favour |
| `/interview:start` isn't found | Start a new session after installing; check with `claude plugin list` |

## A worked example

**A Fix round, 60 minutes, in run mode.** You're handed an orders service: *"Customers say they're sometimes charged
twice. Find it and fix it."*

1. **Orient, 14:00–14:10.** You type `/interview:start fix 60`. A reader maps the path: `pay()` reads the order,
   charges, then marks it paid. You run the tests (all green), open two of its citations, and say the path aloud.
   `OK`.
2. **Reproduce, to 14:20.** The card drafts one question: do clients retry? You ask it. The interviewer says the app
   retries after 5 seconds. You describe the test: *two payments at once charge once*. Claude writes it, and you read
   it. It fails: two charges. `OK`.
3. **Diagnose, to 14:35.**
   - Three suspects, each with a check. You read the code: the status is checked, then there's a wait before it's set,
     so both calls pass. It's a check-then-act race.
   - The edge map has five cases: paying twice, paying a paid order, the gateway failing, an unknown order, and the
     race in a real Postgres. You approve it.
   - Four run now. The Postgres one runs in the background.
4. **Fix, to 14:45.**
   - Three options: an atomic claim in the database, a lock in memory (which breaks with two servers), or an
     idempotency key. You choose the atomic claim and write it yourself (`MINE`, 6 lines). Claude wires it in (4
     lines).
   - Every test passes, including the background database test. You read the diff and commit.
   - The sweep finds the same race in `refund()`. You note it.
5. **Review, to 14:55.** Two readers report:
   - the refund race;
   - the amount taken from the request body;
   - a gateway call with no timeout;
   - "SQL injection", which you check: it's a parameterised query. You say it's a false alarm.
6. **Wrap, to 15:00.** From eight drafted lines, in your own words:
   - what you found and how you know;
   - what you fixed;
   - what else you'd flag;
   - what you'd do next;
   - what you didn't check.

The interviewer saw you lead every step. Claude read, drafted and typed small pieces.

---

The plugin's own files are plain text you can read:
[phases.md](spring-boot-learning/kit-interview/skills/start/phases.md),
[bar.md](spring-boot-learning/kit-interview/skills/start/bar.md),
[checklists.md](spring-boot-learning/kit-interview/skills/start/checklists.md),
[prompts.md](spring-boot-learning/kit-interview/skills/start/prompts.md) and the runner,
[SKILL.md](spring-boot-learning/kit-interview/skills/start/SKILL.md).
