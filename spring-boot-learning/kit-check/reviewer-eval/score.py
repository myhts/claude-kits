"""score.py <dir> [--baseline <agent>]: unblind the graders' JSON with mapping.secret and apply the rules in answer-key.md.

With --baseline, also applies the model-and-effort rule in the README to the other agent (an arm of the baseline):
it passes when every run has full marks on each known defect the baseline got full marks on in all of its runs, it
has no more wrong findings than the baseline, and the baseline doesn't win on points. Cost is not judged here:
extract.py prints it, and the cheapest passing arm is the choice.
"""
import json, pathlib, re, statistics, sys
from collections import Counter, defaultdict

args = sys.argv[1:]
baseline = args.pop(args.index("--baseline") + 1) if "--baseline" in args else None
args = [a for a in args if a != "--baseline"]
d = pathlib.Path(args[0])
POINTS = {"VALID-high": 2, "VALID-medium": 1, "VALID-low": 0.5, "DEBATABLE": 0, "WRONG": -2}
mapping = {}
for line in (d / "mapping.secret").read_text().splitlines():
    pair, rest = line.split(":")
    for side, who in re.findall(r"(X|Y)=(\S+)", rest):
        mapping[(pair.strip(), side)] = who

runs = defaultdict(list)            # agent -> [run score]
known = defaultdict(set)            # agent -> {Kx (full or partial)}
classes = defaultdict(Counter)      # agent -> class counts
full = defaultdict(list)            # agent -> [{Kx with full marks} per run]
for (pair, side), who in sorted(mapping.items()):
    gd = d / "grading" if (d / "grading").is_dir() else d
    g = json.loads((gd / f"{pair}-grades.json").read_text())
    agent = who.rsplit("-", 1)[0]
    score, seen, full_run = 0.0, set(), set()
    for f in g[side]:
        if f["class"] == "KNOWN" or f.get("known"):
            k, credit = f["known"], f.get("credit") or "full"
            if k in seen:              # duplicates within one report count once
                continue
            seen.add(k)
            pts = 3 if credit == "full" else 1.5
            if credit == "full":
                full_run.add(k)
            known[agent].add(f"{k}{'' if credit == 'full' else '(partial)'}")
            classes[agent][f"KNOWN-{credit}"] += 1
        else:
            pts = POINTS[f["class"]]
            classes[agent][f["class"]] += 1
        score += pts
    runs[agent].append(score)
    full[agent].append(full_run)
    print(f"{pair} {side} = {who:16} score {score:5.1f}  findings {len(g[side])}")

means = {a: statistics.mean(s) for a, s in runs.items()}
for a in runs:
    print(f"\n{a}: runs {runs[a]} mean {means[a]:.2f}\n  known found (union): {sorted(known[a])}\n  classes: {dict(classes[a])}")
(a1, m1), (a2, m2) = sorted(means.items(), key=lambda x: -x[1])
margin = m1 - m2
verdict = a1 if margin >= 2 and margin >= 0.15 * m1 else "DRAW"
print(f"\nmargin {margin:.2f} (needs >= 2 and >= {0.15 * m1:.2f}) -> {verdict}")

if baseline:
    if baseline not in runs:
        sys.exit(f"--baseline {baseline}: not in mapping.secret (agents: {sorted(runs)})")
    arm = next(a for a in runs if a != baseline)
    key = lambda k: int(k[1:]) if k[1:].isdigit() else 0
    need = sorted(set.intersection(*full[baseline]), key=key)
    missed = [f"run {i + 1}: {', '.join(sorted(set(need) - got, key=key))}" for i, got in enumerate(full[arm]) if set(need) - got]
    wrong_arm, wrong_base = classes[arm]["WRONG"], classes[baseline]["WRONG"]
    checks = [
        (not missed, f"full marks in every run on the {len(need)} known defects the baseline always got"
                     + (f" (missed: {'; '.join(missed)})" if missed else "")),
        (wrong_arm <= wrong_base, f"wrong findings {wrong_arm} against the baseline's {wrong_base}"),
        (verdict != baseline, f"points: {means[arm]:.2f} against {means[baseline]:.2f}, the baseline doesn't win"
                              if verdict != baseline else f"points: the baseline wins ({means[baseline]:.2f} against {means[arm]:.2f})"),
    ]
    print(f"\nmodel-and-effort rule, {arm} against baseline {baseline}:")
    for ok, text in checks:
        print(f"  {'ok  ' if ok else 'FAIL'} {text}")
    print(f"  -> {arm} {'PASSES' if all(ok for ok, _ in checks) else 'FAILS'}")
