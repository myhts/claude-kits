---
name: interview-drill
description: Turns the learner's own project into interview practice - asks design and "why" questions about their code, follow-ups like an interviewer, and scores answers against senior/staff expectations. Use when the learner says "quiz me", "interview me", "drill", or runs /interview-drill.
---

# Interview drill (on your own code)

Interviewers ask about what you built. This drill uses this repository as the material.

## Setup

1. Read `CLAUDE.md`, `docs/learning/PROGRESS.md`, and skim the code for the decisions made (transactions,
   consistency, failure handling, scaling, testing).
2. Ask the learner: which level (mid / senior / staff), which kind (deep dive on this project, system design
   extension, a classic design, or debugging scenario), and how long (10, 30 or 45 minutes).
3. For design rounds use the `system-design` skill (the 45-minute shape, the rubric, the 14 designs); for
   transactions, messaging and caching follow-ups, the `transactions` and `distributed-systems` skills.

## Running it

- **One question at a time.** Wait for the answer. Don't hint unless asked.
- Start concrete ("walk me through what happens when a client POSTs an order"), then push on decisions ("why a
  transaction there?", "what if the broker is down?", "what if this runs on 3 instances?"), then scale ("10× the
  traffic: what breaks first, and how do you know?").
- **Follow-ups like a real interviewer:** ask for numbers, trade-offs, the alternative they rejected, how they'd
  verify it, what they'd monitor.
- Debugging scenarios: describe a symptom (p99 jumped, duplicates appeared, a consumer lags) and let them
  investigate by asking questions; answer as the system would.

## Feedback after each answer (short)

- **Strong:** what was good, specifically.
- **Missing:** the point a strong answer includes (a number, a failure mode, a trade-off, a verification).
- **Level check:** what a senior answer adds (correct mechanism, failure modes, measured numbers) and what a staff
  answer adds (the decision's cost across teams, how it changes at scale, what would make them change it).
- **Point to the code:** `file:line` where the answer lives, so they can rehearse with it.

## End of drill

A summary table (question · verdict · what to study) and the two weakest areas, each with the skill to read and
an exercise. Add recurring gaps to `docs/learning/LESSONS.md`.
