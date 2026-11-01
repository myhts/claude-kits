# Evals: quality as a number

An eval is a test whose result is a score. It answers "how good is this prompt + model on cases we care about",
so a change is judged by the score moving, not by a few outputs that look fine. The harness shape is in kit-check
(`ExtractionEval`, `ExtractionEvalTest`, `LiveExtractionEvalIT`).

## Where things live in a project

```
src/test/resources/eval/
  extraction.dev.jsonl      cases you look at and tune against
  extraction.test.jsonl     held out: scored, never tuned against, changed only on purpose
  baseline.json             the last accepted scores, committed (prompt version, model, date, scores, cost)
src/test/java/.../eval/
  ExtractionEvalTest        canned answers: proves the scoring and the gate; runs in every build
  ExtractionEvalIT          live: RUN_LIVE_EVALS=true + a key; prints scores and cost; compares with baseline.json
```

## A case

```json
{"id":"c3-cancelled-eur","covers":"currency other than GBP; reason = illness of a relative",
 "input":"We cancelled our trip to Rome because my father was admitted to hospital on 2026-06-20 ...",
 "expected":{"lossType":"TRIP_CANCELLED","amountClaimed":"840.00","currency":"EUR", "...": "..."},
 "source":"drafted by claude-haiku-5-5, labels checked by hand 2026-11-02"}
```

- `id` stable and readable; `covers` says why the case exists (an edge, a trap, a regression).
- `source` says where it came from (see [synthetic-data.md](synthetic-data.md)).
- One case per behaviour you'd be embarrassed to get wrong.

## What to measure

| Metric | Why |
|---|---|
| Accuracy per field (exact, after normalising case and spaces) | Finds the weak field; one number hides it |
| Decision accuracy and a confusion table (pay / need info / refer) | Which mistakes: a wrong "refer" costs time, a wrong "pay" costs money |
| Citations verified (share of citations that match the source) | Grounding, not just plausible prose |
| Refused and unusable rate | Cases that silently went to a human |
| Cost per case, and p95 latency | The two numbers a product owner asks first |
| The injection cases, separately | A prompt change can quietly weaken the defence |

## Graders

- **Exact match** for ids, dates, enums, amounts (normalise first: `"1,250.00"` vs `"1250.00"` is your bug, not the
  model's).
- **Set overlap** for lists (`missingInformation`): precision and recall against the expected items, after
  normalising wording, or a small synonym map.
- **A model as judge** only for prose (the coverage explanation), with a written rubric, a different and stronger
  model than the one being graded, and a check of the judge itself against 20 hand-graded answers. A judge you
  haven't checked is an opinion with a number on it.
- Never let the model that drafted the cases grade them.

## The gate

- `baseline.json` holds the accepted scores. The live eval fails when the worst field drops more than a set
  tolerance below the baseline, or below a floor (say 0.9). A deliberate trade-off updates the baseline in the
  same PR, with the reason in the PR description.
- Model output varies run to run: run the live eval 3 times for a decision and compare means and minimums. A
  one-point move on 60 cases (1.7%) is noise until it repeats.
- The report names the prompt version (`AuditRecord.versionOf`), the model, the date and the total cost, so every
  number can be traced to what produced it.

## Running live evals

- Deliberately, never on every push: locally with `RUN_LIVE_EVALS=true`, in CI only by hand or with a PR label
  ([ci-evals.yml](ci-evals.yml)).
- Print the cost of every run. On Haiku 5.5 with the policy cached, ~60 cases × 2 calls is in the order of 10–20
  cents; measure it rather than trusting this line.
- A big re-run that isn't urgent goes through the Message Batches API at half price.

## Improving against the eval

- Change one thing at a time (the prompt, the schema descriptions, effort, the model), run, record the scores next
  to the prompt version, keep or revert.
- Tune on `dev`, report `test`. Tuning on the test set turns it into a dev set and the score into fiction.
- The built-in `claude-api` skill helps: `/claude-api build-eval` (interview to design the set and grader),
  `/claude-api hillclimb` (a structured improve-measure loop with a train/test split), `/claude-api cost-optimize`
  (cheapest model and effort that keep the score).
