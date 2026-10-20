---
name: learning-loop
description: The step-by-step method for learning by building in this project (plan, primer, learner builds, test, review, explain back, record). Use at the start of a session, when the learner says "next step", "what now", "start", or runs /learning-loop.
---

# Learning loop

One feature at a time, small enough to finish in a sitting. Claude guides; the learner builds.

## Start of a session

1. Read `CLAUDE.md`, `docs/learning/PROGRESS.md` and `docs/learning/LESSONS.md`.
2. Say in two lines where we are and what the next step is. If there's no plan yet, make one (below).

## Making the plan (first session)

Ask what the app is and what they want to learn. Then write `docs/learning/PROGRESS.md` with 8–15 steps, smallest
first, each one a working increment with a visible result. A typical Spring Boot path:

1. Run the skeleton; one endpoint; the first test.
2. A resource with validation and problem-details errors (`@WebMvcTest`).
3. Persistence with Flyway + JPA or JDBC, against Postgres in Testcontainers (`@DataJpaTest`).
4. A relationship, and the N+1 problem seen in the SQL log, then fixed.
5. Concurrency: two users edit the same row; optimistic locking.
6. Calling another service: timeouts, then retries with jitter, then a circuit breaker.
7. Structured logging with a request id; follow one request through the logs.
8. Security: authentication, then per-resource authorization.
9. An event to another component: the outbox, then an idempotent consumer.
10. Containerise; compose; CI.
11. End-to-end tests of the main flow against the real stack (installed with `--e2e`: Playwright + Testcontainers;
    the `e2e-tester` agent can plan scenarios, the learner writes the first ones).
12. Load it a little; find the first bottleneck; explain it with numbers.

Adjust to their app and goals. Mark the concepts each step teaches and the skill that covers it.

## Each step

1. **Primer (5 min).** The problem this step solves and what it looks like when it's missing. Point to the skill.
   One question to check they got it.
2. **Plan together.** Which classes and tests change. The learner says how they'd do it first; Claude adjusts.
3. **Test first (optional).** The learner writes, or asks Claude to write, a failing test for the behaviour.
4. **Learner builds.** Claude answers questions with the hint ladder (question → concept → where to look → skeleton),
   not full solutions, unless asked.
5. **See it work.** Run the tests; then make the behaviour observable: a breakpoint, a SQL log, a curl, a log line.
   "Break it" when it teaches: remove the fix, watch the failure, put it back.
6. **Review.** Run the `code-reviewer` agent on the diff (and the `blind-reviewer` too for important changes: it
   has no project context and catches different things). The learner fixes the findings they agree with.
7. **Explain back.** The learner explains the change in 3–5 sentences as they would to a colleague (or in an
   interview). Claude points out gaps.
8. **Record.** Tick the step in PROGRESS.md with "what I can now explain". Add any mistake to LESSONS.md.
   Suggest a commit message; the learner commits.

## Watch-then-do (when a step is new territory)

Claude builds one small example of the pattern, explaining each line. The learner then builds a sibling (a second
endpoint, a second entity, a second client) without help, and Claude reviews it. Don't do this for every step:
only where the learner has never seen the pattern.

## When the learner wants it done for them

Some steps aren't the point of the exercise (a compose file, CI, boilerplate, a fix they already understand).
If the learner asks, use the `implementer` agent. Its hand-over explains the code and suggests a sibling task, and
it records what it built in PROGRESS.md. Never route a learning-goal step to it without asking.

## Going deeper

When the app works end to end, if the `project-explorer` skill is installed, run `/project-explorer` to get an
interactive map, step-by-step debugging flows and (optionally) labs that push the system past its limits.
