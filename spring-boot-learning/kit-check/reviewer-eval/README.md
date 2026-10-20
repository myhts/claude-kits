# Reviewer evaluation: compare two versions of an agent fairly

A repeatable method for deciding whether a changed agent is actually better, instead of trusting a few good-looking
reports. Used once so far, on `code-reviewer` (uses the project's context) vs `blind-reviewer` (code only).

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
   pair one of each under labels X and Y, keep the mapping in `mapping.secret`.
7. **Grade each pair with a separate agent** that verifies every finding in the code against the answer key and writes
   `pairN-grades.json`.
8. **Unblind and total**: `python3 score.py <dir with mapping.secret and pairN-grades.json>`.

## Rerun it

```bash
./prepare.sh ~/code/your-project ~/code/your-eval/project-context.md
for n in 1 2 3; do ./run.sh code-reviewer $n & ./run.sh blind-reviewer $n & done; wait
python3 extract.py work
# blind, pair and grade (steps 6–7), then:
python3 score.py ~/code/your-eval
```
