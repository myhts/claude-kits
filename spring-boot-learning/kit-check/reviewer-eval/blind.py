"""blind.py <work dir> <out dir> <agent A> <agent B> [label A] [label B]: step 6 of the method.

Strips what identifies the agent (report-format words, empty sections, run-folder paths) from <work>/<agent>-<n>.report.md
(written by extract.py), pairs run n of A with run n of B under X and Y in random order, and keeps the mapping in
<out>/mapping.secret for score.py. Check the output for anything else that gives the agent away before grading.
"""
import pathlib, random, re, sys

work, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
a, b = sys.argv[3], sys.argv[4]
label_a, label_b = (sys.argv[5], sys.argv[6]) if len(sys.argv) > 6 else (a, b)
out.mkdir(parents=True, exist_ok=True)


def blind(text):
    lines, kept, skipping = text.splitlines(), [], None
    for line in lines:
        if re.match(r"^#+ Review \(spec\)", line):
            skipping = "spec"                    # code-reviewer's spec axis with no ticket: no findings to grade
            continue
        if skipping == "spec":
            if line.startswith("---") or line.startswith("**Summary") or line.startswith("#"):
                skipping = None
            else:
                continue
        if re.match(r"^\s*Files reviewed", line):
            skipping = "files"
            continue
        if skipping == "files":
            continue
        if line.startswith("Which finding") or "docs/agents/stack.md" in line:
            continue                             # the closing question; a note on which pipeline files it found
        kept.append(line)
    t = "\n".join(kept)
    t = re.sub(r"/\S*?/work/run-[\w-]+/", "", t)
    t = re.sub(r"^#+ Review \(standards\)", "## Review", t, flags=re.M)
    t = re.sub(r"^#+ Review:", "## Review:", t, flags=re.M)
    t = re.sub(r"^### Must fix \(bugs, data loss, security\)", "### Must fix", t, flags=re.M)
    t = re.sub(r"^### (Judgement calls|Worth knowing)", "### Other notes", t, flags=re.M)
    t = re.sub(r"[Jj]udgement calls?", "notes", t)
    t = re.sub(r"[Ww]orth knowing", "notes", t)
    t = re.sub(r"\bstandards finding", "finding", t)
    t = re.sub(r"^Standards: ", "", t, flags=re.M)
    t = re.sub(r"\b(this|the|on your|each) axis\b", "this part", t)
    return t.strip() + "\n"


rng = random.SystemRandom()
mapping = []
for n in (1, 2, 3):
    pair = [(label_a, work / f"{a}-{n}.report.md"), (label_b, work / f"{b}-{n}.report.md")]
    rng.shuffle(pair)
    for side, (who, f) in zip("XY", pair):
        (out / f"pair{n}-{side}.md").write_text(blind(f.read_text()))
    mapping.append(f"pair{n}: X={pair[0][0]}-{n} Y={pair[1][0]}-{n}")
(out / "mapping.secret").write_text("\n".join(mapping) + "\n")
print("blinded 3 pairs into", out)
