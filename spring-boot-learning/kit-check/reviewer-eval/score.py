"""score.py <dir>: unblind the graders' JSON with mapping.secret and apply the rules in answer-key.md."""
import json, pathlib, re, statistics, sys
from collections import Counter, defaultdict

d = pathlib.Path(sys.argv[1])
POINTS = {"VALID-high": 2, "VALID-medium": 1, "VALID-low": 0.5, "DEBATABLE": 0, "WRONG": -2}
mapping = {}
for line in (d / "mapping.secret").read_text().splitlines():
    pair, rest = line.split(":")
    for side, who in re.findall(r"(X|Y)=(\S+)", rest):
        mapping[(pair.strip(), side)] = who

runs = defaultdict(list)            # agent -> [run score]
known = defaultdict(set)            # agent -> {Kx (full or partial)}
classes = defaultdict(Counter)      # agent -> class counts
for (pair, side), who in sorted(mapping.items()):
    gd = d / "grading" if (d / "grading").is_dir() else d
    g = json.loads((gd / f"{pair}-grades.json").read_text())
    agent = who.rsplit("-", 1)[0]
    score, seen = 0.0, set()
    for f in g[side]:
        if f["class"] == "KNOWN" or f.get("known"):
            k, credit = f["known"], f.get("credit") or "full"
            if k in seen:              # duplicates within one report count once
                continue
            seen.add(k)
            pts = 3 if credit == "full" else 1.5
            known[agent].add(f"{k}{'' if credit == 'full' else '(partial)'}")
            classes[agent][f"KNOWN-{credit}"] += 1
        else:
            pts = POINTS[f["class"]]
            classes[agent][f["class"]] += 1
        score += pts
    runs[agent].append(score)
    print(f"{pair} {side} = {who:16} score {score:5.1f}  findings {len(g[side])}")

means = {a: statistics.mean(s) for a, s in runs.items()}
for a in runs:
    print(f"\n{a}: runs {runs[a]} mean {means[a]:.2f}\n  known found (union): {sorted(known[a])}\n  classes: {dict(classes[a])}")
(a1, m1), (a2, m2) = sorted(means.items(), key=lambda x: -x[1])
margin = m1 - m2
verdict = a1 if margin >= 2 and margin >= 0.15 * m1 else "DRAW"
print(f"\nmargin {margin:.2f} (needs >= 2 and >= {0.15 * m1:.2f}) -> {verdict}")
