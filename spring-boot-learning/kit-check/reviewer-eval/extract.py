"""extract.py <dir>: for each <agent>-<n>.jsonl write <agent>-<n>.report.md and print an audit of tool calls.

Audit: every tool call made inside the subagent (parent_tool_use_id set), flagging reads of prose/project-context
files (CLAUDE.md, *.md, .claude/, docs/, git log messages) and web fetches.
"""
import json, pathlib, re, sys

d = pathlib.Path(sys.argv[1])
PROSE = re.compile(r"(CLAUDE|README|LESSONS|PROGRESS)[^/]*\.md|\.md\b|/\.claude/|\.claude/|/docs/|\bgit log\b(?!.*%H)")
for f in sorted(d.glob("*-[0-9].jsonl")):
    report, calls, flagged, web, cost, turns = None, 0, [], [], None, None
    for line in f.read_text().splitlines():
        try:
            m = json.loads(line)
        except json.JSONDecodeError:
            continue
        if m.get("type") == "result":
            report, cost, turns = m.get("result"), m.get("total_cost_usd"), m.get("num_turns")
        if m.get("type") == "assistant" and m.get("parent_tool_use_id"):
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
    print(f"== {f.stem}: subagent tool calls {calls}, cost ${cost}, report {len(report or '')} chars")
    for x in flagged:
        print("   PROSE/CONTEXT:", x)
    for x in web:
        print("   WEB:", x)
