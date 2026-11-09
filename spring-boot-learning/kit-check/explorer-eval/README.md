# Explorer evaluation: which model should read the code?

`/project-explorer` starts by surveying the repository: what each service exposes, what it calls, what it stores. On
a big repository it hands that reading to subagents, one per service. Reading is a lot of tokens and little judgement,
so a cheaper model might do it just as well, while the main session (Opus) keeps the judgement: the map, the flows,
the explanations. This evaluation tests that before the explorer changes, with answers taken from the code itself.

**Status:** run on 2026-11-09: five runs, Opus once and Sonnet and Haiku twice each. **Decision: Sonnet for the readers
only** ([results](#results-2026-11-09)); the map, the flows, the explanations and every other judgement stay on Opus.
The decision rule below was fixed the same day, before any run.

## The test

| | |
|---|---|
| **Repository** | a copy of Google's Online Boutique ([myhts/claude-kits-boutique](https://github.com/myhts/claude-kits-boutique)): 11 services, 5 languages, gRPC, Redis |
| **Arms** | readers on `opus`, `sonnet`, `haiku`; the main session is Opus in every arm |
| **Each run** | headless, in a fresh clone; the explorer's Phase 0 and 1 only; nothing is run or built; it stops before gate 1 having written `survey.json` ([survey-format.md](survey-format.md)) and `draft-map.md` |
| **Answer key** | taken from the repository by `answers.mjs`: the rpcs in `protos/`, the frontend's routes, the calls each Kubernetes Deployment is configured for, and the store behind the cart. A person reads it before any run |
| **Measured** | entry points, calls and stores found; every cited `file:line` checked; what was left "unsure"; usage per model at list price |
| **Then** | a blind read of the three draft maps (labels X, Y, Z), by a fresh agent and by a person |

**Models, as Claude Code resolves the aliases (2026-11-09):** `opus` → `claude-opus-5-5`, `sonnet` →
`claude-sonnet-5-5`, `haiku` → `claude-haiku-4-5`. Claude Code doesn't recognise `claude-haiku-5-5`, so the Haiku arm
is Haiku 4.5: what a subagent with `model: haiku` actually gets. Every session also makes a few small Haiku 4.5 calls of
its own; `usage.mjs` includes them.

## The decision rule (fixed 2026-11-09, before any run)

An arm **passes** when it:
1. finds every required call that the Opus arm found;
2. finds at least **95%** of the required entry points;
3. cites **no broken** `file:line`.

Calls an arm reports that aren't in the key are listed, and a person checks each in the code; a wrong one fails the
arm. **The choice is the cheapest arm that passes** (Haiku, then Sonnet, then Opus). If none passes, the readers stay
on Opus. If two arms are close (one fails on a single item), each runs once more. The blind read can overturn a choice
only if the chosen arm's draft map is clearly worse, and the reason is written down.

**One scorer fix after the Opus run, before Sonnet or Haiku was scored.** Opus wrote notes in brackets after names
(`EmailService.SendOrderConfirmation (DummyEmailService: logs …)`), which the scorer read as part of the name, so a
method it had found counted as missed. The scorer now ignores a note in brackets, and lists the calls not in the key in
two groups: to a workload of the app (could be invented, so check these first) and to something outside it
(telemetry, a cloud API). The rule above didn't change, and `self-test.sh` covers both.

## Results (2026-11-09)

Same commit (`c7cb6d5b`), same request, a fresh clone and session per run. "Found" is the survey the main session
wrote; "readers" is the readers' own fact sheets before it checked and merged them (`sheets.mjs`).

| Run | Entry points | Calls | Store | Refs (broken) | Readers: broken refs | Readers: "unsure" | List price | Readers' share |
|---|---|---|---|---|---|---|---|---|
| Opus 1 | 23/23 | 14/14 | 1/1 | 118 (0) | 0 | 71 | $4.02 | about $2.6 |
| Sonnet 1 | 23/23 | 14/14 | 1/1 | 85 (0) | 0 | 48 | $2.09 | $0.73 |
| Sonnet 2 | 23/23 | 14/14 | 1/1 | 94 (0) | 0 | 61 | $2.45 | $0.83 |
| Haiku 1 | 23/23 | 14/14 | 1/1 | 79 (0) | 1 | 5 | $2.14 | $0.73 |
| Haiku 2 | 23/23 | 14/14 | 1/1 | 83 (0) | 0 | 3 | $2.64 | $0.95 |

- **Every arm found everything, in every run.** No reader invented a call between services. Every call outside the
  app (telemetry, the profiler, Secret Manager, AlloyDB, Gemini) was checked against the line it cites, and is real.
- **Cheaper readers halve the bill:** $2.09 to $2.64 a run against $4.02. What's left is mostly the main session on
  Opus ($1.35 to $1.69), which does the judgement and the map.
- **Haiku's lower price didn't show.** Its readers made three to four times the tool calls of Sonnet's (143 and 158
  against 33 and 46), so they cost as much or more in both runs. They also left far fewer notes on what they couldn't
  trace (3 to 5 against 48 to 61), and one sheet put eight lines in one reference, which the main session split.
- **The blind read** (a fresh agent, maps labelled X, Y, Z) ranked Opus's map first, Haiku's second and Sonnet's
  third, and found **none clearly worse**: all three get the topology right, each with a few slips on failure paths.
  The main session writes the map in every arm, so this mostly measures that session, not the readers.
- **Choice: Sonnet.** It passes, and it was the cheapest by measured usage in both runs. The order in brackets in the
  rule assumed list prices; the measurements overturned it. The blind read can't overturn the choice, since no map was
  clearly worse. **Approved by the owner the same day, for the readers only:** the map, the flows, the explanations
  and every other judgement stay on Opus.
- **Limits:** one repository; Opus ran once, the others twice. `haiku` is Haiku 4.5 here, so test again when Claude
  Code offers Haiku 5.5. The readers ran as background tasks, so a slower arm costs the main session more rounds
  (Haiku's runs took four rounds, the others one).

## Files

| File | What it does |
|---|---|
| `answers.mjs` | builds the answer key from the repository |
| `run.sh` | one headless run per arm, loading the pipeline plugin from this checkout (`--plugin-dir`) |
| `survey-format.md` | the fact sheet every reader returns, given to every arm word for word |
| `score.mjs` | scores the surveys against the key and applies the rule |
| `usage.mjs` | usage per model from a run's log: exact for a headless run, estimated for an interactive session |
| `sheets.mjs` | the readers' own fact sheets from a run's log, as one survey, to score the readers alone |
| `self-test.sh` | proves the scripts on a tiny invented repository, offline, with no model calls |

## Run it

```bash
cd spring-boot-learning/kit-check/explorer-eval
B=path/to/claude-kits-boutique   # your clone of myhts/claude-kits-boutique
./self-test.sh
mkdir -p work && node answers.mjs "$B" --optional 'assistant|/bot|product-meta|loadgenerator|shoppingassistant' > work/answers.json
# read work/answers.json, then:
for arm in opus sonnet haiku; do ./run.sh "$B" "$arm" 1; done
node score.mjs work/answers.json work/opus-1/repo opus=work/opus-1/survey.json sonnet=work/sonnet-1/survey.json haiku=work/haiku-1/survey.json
for arm in opus sonnet haiku; do node usage.mjs "work/$arm-1/run.jsonl"; done
# the readers alone, before the main session checked their work:
for arm in opus sonnet haiku; do node sheets.mjs "work/$arm-1/run.jsonl" > "work/$arm-1/raw-survey.json"; done
node score.mjs work/answers.json work/opus-1/repo opus=work/opus-1/raw-survey.json sonnet=work/sonnet-1/raw-survey.json haiku=work/haiku-1/raw-survey.json
```

The runs go one after another, so they don't compete for your plan's rate limits. Results, the draft maps and an ADR
go to the showcase repository; the outcome is summarised here.
