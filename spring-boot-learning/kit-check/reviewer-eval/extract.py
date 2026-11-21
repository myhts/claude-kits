"""extract.py <dir>: for each <agent>-<n>.jsonl write <agent>-<n>.report.md and print an audit of tool calls.

Audit: every tool call made inside the subagent (parent_tool_use_id set), flagging reads of prose/project-context
files (CLAUDE.md, *.md, .claude/, docs/, git log messages) and web fetches. Also the models the subagent's own
messages came from (proof that a model arm ran on its model), the run's cost at list price and its wall-clock time,
and at the end the mean cost and time per agent: the numbers the model-and-effort rule in the README chooses by.
"""
import json, pathlib, re, statistics, sys
from collections import defaultdict

d = pathlib.Path(sys.argv[1])
PROSE = re.compile(r"(CLAUDE|README|LESSONS|PROGRESS)[^/]*\.md|\.md\b|/\.claude/|\.claude/|/docs/|\bgit log\b(?!.*%H)")
costs, times = defaultdict(list), defaultdict(list)
for f in sorted(d.glob("*-[0-9].jsonl")):
    report, calls, flagged, web, cost, turns, secs, models = None, 0, [], [], None, None, None, set()
    for line in f.read_text().splitlines():
        try:
            m = json.loads(line)
        except json.JSONDecodeError:
            continue
        if m.get("type") == "result":
            report, cost, turns = m.get("result"), m.get("total_cost_usd"), m.get("num_turns")
            secs = (m.get("duration_ms") or 0) / 1000
        if m.get("type") == "assistant" and m.get("parent_tool_use_id"):
            models.add(m["message"].get("model") or "?")
            for c in m["message"].get("content", []):
                if c.get("type") != "tool_use":
                    continue
                calls += 1
                arg = json.dumps(c.get("input", {}))
                if c["name"] in ("WebFetch", "WebSearch"):
                    web.append(arg[:140])
                elif PROSE.search(arg):
                    flagged.append(f"{c['name']} {arg[:160]}")
    (d / f"{f.stem}.report.md").write_text(report or "(no result)")
    print(f"== {f.stem}: subagent on {', '.join(sorted(models)) or '(no subagent ran)'}, tool calls {calls}, "
          f"cost ${cost}, {secs or 0:.0f} s, report {len(report or '')} chars")
    if cost is not None:
        costs[f.stem.rsplit("-", 1)[0]].append(cost)
        times[f.stem.rsplit("-", 1)[0]].append(secs)
    for x in flagged:
        print("   PROSE/CONTEXT:", x)
    for x in web:
        print("   WEB:", x)
if costs:
    print("\nper agent, mean of its runs (list price; on a subscription nothing is billed, but it compares arms fairly):")
    for a in sorted(costs, key=lambda a: statistics.mean(costs[a])):
        print(f"   {a:40} ${statistics.mean(costs[a]):.3f}   {statistics.mean(times[a]):4.0f} s   ({len(costs[a])} runs)")
