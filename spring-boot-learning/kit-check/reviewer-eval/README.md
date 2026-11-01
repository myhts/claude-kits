# Reviewer evaluation: compare two versions of an agent fairly

A repeatable method for deciding whether a changed agent is actually better, instead of trusting a few good-looking
reports. Used twice so far: `code-reviewer` (uses the project's context) vs `blind-reviewer` (code only), then the
rewritten `code-reviewer` vs its previous version.

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

## Pending: the LLM checks in `security-reviewer` and `blind-reviewer` (prepared 2026-10-25, not run)

`code-reviewer`, `security-reviewer` and `blind-reviewer` gained checks for code that calls a model (the first two
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
- **Runs**: `for n in 1 2 3; do ./run.sh security-reviewer $n & ./run.sh security-reviewer-before $n & done; wait`,
  then the same for `blind-reviewer`; then steps 5–8 below. 12 headless reviews in all. Pass `prepare-llm.sh` the
  commit before the LLM checks were added, now that they're committed.
  `run.sh` runs on your Claude Code subscription (it unsets any API key, so nothing is billed to the API) with
  `MODEL=opus` by default, as in the 2026-10-19 run; compare scores only within one model.

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
   lists web fetches).
6. **Blind the reports**: strip anything that identifies the agent (fingerprint lines, label words, run-folder paths),
   pair one of each under labels X and Y, keep the mapping in `mapping.secret`: `python3 blind.py work <dir> <agent A>
   <agent B>`. Then read the output for anything else that gives an agent away.
7. **Grade each pair with a separate agent** that verifies every finding in the code against the answer key and writes
   `pairN-grades.json`.
8. **Unblind and total**: `python3 score.py <dir with mapping.secret and pairN-grades.json>`.

## Rerun it

```bash
./prepare.sh ~/code/your-project ~/code/your-eval/project-context.md
for n in 1 2 3; do ./run.sh code-reviewer $n & ./run.sh blind-reviewer $n & done; wait
python3 extract.py work
python3 blind.py work ~/code/your-eval code-reviewer blind-reviewer
# grade each pair (step 7), then:
python3 score.py ~/code/your-eval
```
