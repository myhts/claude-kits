# Reviewer evaluation: compare two versions of an agent fairly

A repeatable method for deciding whether a changed agent is actually better, instead of trusting a few good-looking
reports. Used twice so far: `code-reviewer` (uses the project's context) vs `blind-reviewer` (code only), then the
rewritten `code-reviewer` vs its previous version.

The same method also answers a second question: which model and effort level an agent should run on. That
comparison is [prepared below](#pending-which-model-and-effort-should-code-reviewer-run-on-rule-fixed-2026-11-21-not-run),
with its rule fixed and no scored run yet.

## Result of the first run (2026-10-19)

Run on a private Spring Boot + Kafka + Redis project's backend (174 files, ~5,700 lines) with 8 known defects.
Result: **a draw**, so the kit keeps both reviewers.

| | code-reviewer (context) | blind-reviewer (code only) |
|---|---|---|
| Run scores | 17.0 · 14.0 · 13.5 | 15.0 · 15.5 · 13.5 |
| **Mean** | **14.83** | **14.67** |
| The two most serious known defects | found in every run | found in every run |
| Real defects outside the answer key (high · medium · low) | 7 · 4 · 8 | 6 · 6 · 7 |
| Opinion-only findings · wrong findings | 2 · 0 | 0 · 0 |
| Cost per review | ≈ $1.3 | ≈ $2.0 |

What it showed: giving the reviewer a detailed description of the features bought nothing measurable; each found
something the other missed (the context one, a misconfigured circuit breaker; the blind one, an authentication-filter
issue); the blind one made no opinion-only findings. Run both on important changes. The raw reports and the answer key
stay with that (private) project, because they describe its defects.

## Second run (2026-11-01): the two-axis `code-reviewer` against its last committed version

`code-reviewer` was rewritten to work on any stack and to review on two axes (standards, spec), with the Spring
checklist moved into the `spring` pack's `review-checklist.md`; it had also gained the LLM checks below. Before
publishing it, it was compared with the version last committed (which had neither change) on the invented
`llm-claims` fixture: 3 Opus runs each, reports blinded and paired, each pair graded by a separate agent against the
answer key.

| | new `code-reviewer` | previous `code-reviewer` |
|---|---|---|
| Run scores | 32.5 · 30.5 · 32.5 | 28.5 · 26.5 · 26.5 |
| **Mean** | **31.83** | **27.17** |
| Known defects (of 10) | all 10, full marks, in every run | 8–9 per run; missed K6 (the sampling parameter the model rejects) every time; K3 (stop reason) partial or missed |
| Other real defects (high · medium · low) | 2 · 0 · 3 | 3 · 1 · 2 |
| Opinion-only · wrong | 6 · 0 | 4 · 0 |
| Cost per review | ≈ $0.47 | ≈ $0.40 |

The lead (4.67) is just under the 15% bar (4.77), so by the rule it's a **draw**. That still meets the condition for
replacing an agent with its own new version, at least as good, and the new one scored higher in every pair. What the
numbers mean: the general defects (secret in config, money as `double`, unbounded input, personal data in logs, the
client built per attempt) were found by both versions, so the rewrite lost nothing there. The gain came from the
model-specific defects, which is where the LLM checklist points. The spec axis had no ticket to read and correctly
said so and stopped. Not yet measured: the spec axis itself, and a fixture with general Spring defects only. The
blinded reports, the grades and the mapping are in `results/2026-11-01-code-reviewer/`: `python3 score.py
results/2026-11-01-code-reviewer` reproduces the totals.

## Pending: the LLM checks in `spring-security-reviewer` and `blind-reviewer` (prepared 2026-10-25, not run)

`code-reviewer`, `spring-security-reviewer` (called `security-reviewer` until 2026-11-05, when that name went to a
stack-neutral reviewer) and `blind-reviewer` gained checks for code that calls a model (the first two
point at `llm-engineering/review-checklist.md`; the blind one at the OWASP Top 10 for LLM Applications). By the
kit's rule, a changed agent is compared with its previous version before the change is trusted. `code-reviewer` has
been (above); the other two are ready to run:

- **Fixture**: `fixtures/llm-claims/`, an invented claims-triage service (Boot 4.1.1, anthropic-java 2.71.0; it
  compiles) with **10 planted defects** across prompt injection, excessive agency, unchecked stop reasons, personal
  data in logs, per-request clients with stacked retries, a sampling parameter the model rejects, unbounded input,
  XSS through model output, a key in config and money as `double`.
- **Answer key**, written before any run: `fixtures/llm-claims.answer-key.md` (never copied into the reviewed code).
  Context for `CLAUDE.md`: `fixtures/llm-claims.context.md`.
- **Setup**: `./prepare-llm.sh [commit]` builds `work/base` with the kit and the `--ai` layer installed, plus each
  agent's previous version from git as `<name>-before` (default `HEAD`; after the change is committed, pass the
  commit before it). Both versions see the same skill files: only the agent text differs.
- **Runs**: `for n in 1 2 3; do ./run.sh spring-security-reviewer $n & ./run.sh spring-security-reviewer-before $n &
  done; wait`,
  then the same for `blind-reviewer`; then steps 5–8 below. 12 headless reviews in all. Pass `prepare-llm.sh` the
  commit before the LLM checks were added, now that they're committed.
  `run.sh` runs on your Claude Code subscription (it unsets any API key, so nothing is billed to the API) with
  `MODEL=opus` by default, as in the 2026-10-19 run; compare scores only within one model.

## Pending: which model and effort should `code-reviewer` run on? (rule fixed 2026-11-21, not run)

Every agent in the kit is `model: inherit`, so a reviewer runs on whatever the session is on: usually the biggest
model at high effort. Reviews are the step that runs most often per PR, so a cheaper setting would save most there,
if it reviews as well. A public benchmark can't say whether it does; this fixture can. Model and effort are tested
together, because a bigger model at lower effort can beat a smaller one at high effort on both quality and cost. The
[explorer evaluation](../explorer-eval/README.md) met the same kind of surprise: Haiku's readers cost no less than
Sonnet's.

| | |
|---|---|
| **Fixture and answer key** | `llm-claims`, as above: 10 planted defects, the key written before any run |
| **Baseline** | `code-reviewer` as shipped (`model: inherit`), in a session on Opus at effort `high` |
| **Arms** | `opus:medium` and `sonnet:high`: copies of the agent with only `model` and `effort` changed in the frontmatter (`prepare-arms.sh`), which is what the kit would ship if the arm won |
| **Session** | Opus at effort `high` in every arm, as when a pipeline step starts a reviewer. Only the reviewer changes |
| **Each arm** | 3 runs, blinded and paired with the baseline's 3 runs, each pair graded by a separate agent |
| **Measured** | points by the scoring rules; known defects with full marks, per run; wrong findings; cost at list price and wall-clock time per run (`extract.py`) |

**The rule (fixed 2026-11-21, before any scored run).** An arm **passes** when:
1. every one of its runs has full marks on each known defect that the baseline got full marks on in all three of
   its runs;
2. it has no more wrong findings than the baseline, over the three runs;
3. the baseline doesn't win on points (a lead of ≥ 2 points and ≥ 15%, as in step 3 of the method).

`python3 score.py <dir> --baseline code-reviewer` applies it. **The choice is the cheapest arm that passes**, by the
mean measured cost of its runs and not by the price per token. If none passes, `code-reviewer` stays on `inherit`.
If an arm fails on one defect in one run, it and the baseline each run three more times. The baseline's reports are
graded twice, once in each pairing: if its two means differ by 2 points or more, the grading is too noisy to choose
by, and both pairings are graded again. The owner approves before the agent's frontmatter changes. The result
covers `code-reviewer` on this fixture only; another reviewer needs its own runs.

```bash
./prepare-llm.sh
./prepare-arms.sh code-reviewer opus:medium sonnet:high
for n in 1 2 3; do for a in code-reviewer code-reviewer-opus-medium code-reviewer-sonnet-high; do
  MODEL=opus EFFORT=high ./run.sh $a $n; done; done        # 9 reviews, one after another
python3 extract.py work                                     # each arm's model, cost and time
python3 blind.py work results/<date>-opus-medium code-reviewer code-reviewer-opus-medium
python3 blind.py work results/<date>-sonnet-high code-reviewer code-reviewer-sonnet-high
# grade each pair (step 7 of the method), then for each of the two folders:
python3 score.py results/<date>-opus-medium --baseline code-reviewer
```

- **Proved so far** (2026-11-21, Claude Code 2.1.311): in one run of the `sonnet:high` arm, the reviewer's own
  messages came from `claude-sonnet-5-5` under an Opus session. Its report was not read or graded. The rule itself
  was checked against the 2026-11-01 grades: the new `code-reviewer` passes as an arm of the old one, and the old
  one fails as an arm of the new (no full marks on K3 or K6 in any run).
- **What a run's cost includes.** The session's own share is in the total: it starts the reviewer and repeats the
  report word for word, about $0.27 of the $0.40 in that one run. It is the same work in every arm, so the
  difference between arms is the reviewer's. When an arm's model differs from the session's, `node ../explorer-eval/usage.mjs
  work/<agent>-<n>.jsonl` splits the cost by model.
- **An agent's own `effort` always has to be set in an arm.** A session's effort reaches a subagent only when both
  run on the same model, so `prepare-arms.sh` takes `<model>:<effort>` and writes both. `run.sh` unsets the
  environment variables that would override an agent's own model or effort.
- **Limits:** one fixture (a Java service that calls a model), the standards axis only (there is no ticket for the
  spec axis to read), two arms. A `haiku:high` arm is added the same way.

## The method

1. **A code-only copy** of a project with **known defects** (`prepare.sh <repo> <project-context.md>`): tracked files
   only, with every document that describes the defects removed, so no reviewer can look the answers up. The kit is
   installed, and `CLAUDE.md`'s "This project" is filled from `project-context.md` (features, intended behaviour,
   architecture): the context a context-using agent is designed to have. Edit `EXCLUDE` in `prepare.sh` to match
   what describes the defects in your project.
2. **Check the isolation first** if an agent is meant to be blind: put a marker line in `CLAUDE.md` and ask each agent
   to quote it. Only the context-using one should.
3. **Write the answer key and the scoring rules before reading any report** (`answer-key.md`, kept with your project,
   not in this repo). The rules used:

   | Class | Points |
   |---|---|
   | known defect, mechanism and location right | 3 (partial: 1.5) |
   | another real defect, verified in the code: high · medium · low | 2 · 1 · 0.5 |
   | opinion, or can't be confirmed | 0 |
   | wrong about the code or the version | −2 |

   Winner: a lead of **≥ 2 points and ≥ 15%** on the mean of 3 runs; otherwise a **draw** (keep both).
4. **3 runs per variant**, same request, each in its own copy, headless: `run.sh <agent> <n>`. Give both agents the
   same note (e.g. "don't run the tests: Docker is shared").
5. **Audit what each agent read** from the transcripts: `python3 extract.py work` (flags any prose or `.claude/` reads,
   lists web fetches; also the model each agent ran on, and the cost and time per run and per agent).
6. **Blind the reports**: strip anything that identifies the agent (fingerprint lines, label words, run-folder paths),
   pair one of each under labels X and Y, keep the mapping in `mapping.secret`: `python3 blind.py work <dir> <agent A>
   <agent B>`. Then read the output for anything else that gives an agent away.
7. **Grade each pair with a separate agent** that verifies every finding in the code against the answer key and writes
   `pairN-grades.json`.
8. **Unblind and total**: `python3 score.py <dir with mapping.secret and pairN-grades.json>`. With `--baseline <agent>`
   it also applies the model-and-effort rule above to the other agent.

## Rerun it

```bash
./prepare.sh ~/code/your-project ~/code/your-eval/project-context.md
for n in 1 2 3; do ./run.sh code-reviewer $n & ./run.sh blind-reviewer $n & done; wait
python3 extract.py work
python3 blind.py work ~/code/your-eval code-reviewer blind-reviewer
# grade each pair (step 7), then:
python3 score.py ~/code/your-eval
```
