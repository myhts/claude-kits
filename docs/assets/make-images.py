"""make-images.py: writes the flow images used by README.md and PIPELINE.md.

    python3 docs/assets/make-images.py          (needs Google Chrome or Chromium; set CHROME to its path if it isn't found)

Each image is drawn as SVG, then rendered by headless Chrome to a PNG at twice its size. The PNGs are what the docs
use: an SVG shown as an image draws its text with the viewer's fonts, and some viewers garble system fonts there,
while a PNG looks the same everywhere. Every image has a transparent background, white text only on filled boxes, and
mid-grey everywhere else, so it reads on GitHub's light and dark themes alike. Edit the STAGES table and re-run; don't
edit the PNGs by hand.
"""
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
from html import escape

OUT = pathlib.Path(__file__).parent
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
GREY = "#8b949e"
PHASES = {"PLAN": "#8250df", "BUILD": "#0969da", "REVIEW": "#9a6700", "SHIP": "#1a7f37"}

# number, phase, title, subtitle, command line, who acts, short name for the strips
STAGES = [
    (1, "PLAN", "Plan the language", "one word per concept", "/grill-with-docs", "YOU + CLAUDE", "Plan"),
    (2, "PLAN", "Event Storming", "event-driven work only", "/to-spec, /to-tickets", "YOU + CLAUDE", "Storm"),
    (3, "BUILD", "Test-first build", "with container tests", "/implement #42", "CLAUDE OR YOU", "Build"),
    (4, "BUILD", "A small PR", "one ticket, ~400 lines", "opened by /implement", "CLAUDE", "PR"),
    (5, "BUILD", "Two reviewers", "agents: context + blind", "run by /implement", "CLAUDE", "Agents"),
    (6, "REVIEW", "Your review", "questions, then a record", "/human-review #57", "YOU", "Review"),
    (7, "REVIEW", "You merge", "Claude can't: merge guard", "the Merge button", "YOU", "Merge"),
    (8, "SHIP", "GitHub Actions", "test, build, push image", "ci.yml · deploy.yml", "CI", "Actions"),
    (9, "SHIP", "Kubernetes", "staging → approve → prod", "set up by /deploy", "CI + YOU", "K8s"),
]


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" '
            f'aria-label="{escape(title)}">\n<title>{escape(title)}</title>\n{body}</svg>\n')


def text(x, y, s, size, fill="#fff", weight=400, family=SANS, anchor="start", opacity=1.0, spacing=0):
    extra = f' letter-spacing="{spacing}"' if spacing else ""
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}"{op} text-anchor="{anchor}"{extra}>{escape(s)}</text>\n')


def arrow(x1, y1, x2, y2):
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{GREY}" stroke-width="2" '
            f'marker-end="url(#head)"/>\n')


HEAD = (f'<defs><marker id="head" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" '
        f'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{GREY}"/></marker></defs>\n')


def stage_box(x, y, w, h, stage):
    n, phase, title, sub, cmd, who, _ = stage
    c = PHASES[phase]
    b = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{c}"/>\n'
    b += f'<circle cx="{x + 22}" cy="{y + 22}" r="12" fill="#fff" fill-opacity="0.22"/>\n'
    b += text(x + 22, y + 26.5, str(n), 13, weight=700, anchor="middle")
    pill_w = 7 + 6.3 * len(who)
    b += (f'<rect x="{x + w - pill_w - 10}" y="{y + 13}" width="{pill_w}" height="18" rx="9" fill="#fff" '
          f'fill-opacity="0.2"/>\n')
    b += text(x + w - pill_w / 2 - 10, y + 25.5, who, 9.5, weight=700, anchor="middle", spacing=0.4)
    b += text(x + 14, y + 62, title, 15, weight=700)
    b += text(x + 14, y + 81, sub, 11.5, opacity=0.85)
    b += f'<line x1="{x + 14}" y1="{y + 96}" x2="{x + w - 14}" y2="{y + 96}" stroke="#fff" stroke-opacity="0.25"/>\n'
    b += text(x + 14, y + 115, cmd, 11, family=MONO, opacity=0.95)
    return b


def phase_label(x1, x2, y, phase):
    c = PHASES[phase]
    b = text(x1, y, phase, 11.5, fill=c, weight=700, spacing=1.6)
    b += f'<line x1="{x1 + 9 * len(phase) + 8}" y1="{y - 4}" x2="{x2}" y2="{y - 4}" stroke="{c}" stroke-width="2"/>\n'
    return b


def hero():
    w, bw, bh, gap, left = 1000, 172, 128, 18, 40
    xs = [left + i * (bw + gap) for i in range(5)]
    r1, r2 = 44, 262                                        # box tops, rows 1 and 2
    b = HEAD
    b += phase_label(xs[0], xs[1] + bw, r1 - 12, "PLAN") + phase_label(xs[2], xs[4] + bw, r1 - 12, "BUILD")
    b += phase_label(xs[0], xs[1] + bw, r2 - 12, "REVIEW") + phase_label(xs[2], xs[3] + bw, r2 - 12, "SHIP")
    for i, st in enumerate(STAGES):
        row, col = (r1, i) if i < 5 else (r2, i - 5)
        b += stage_box(xs[col], row, bw, bh, st)
        if col > 0:
            b += arrow(xs[col - 1] + bw + 2, row + bh / 2, xs[col] - 3, row + bh / 2)
    # from 5 back to the start of row 2
    ret_y = r1 + bh + 34
    x5 = xs[4] + bw / 2
    b += (f'<path d="M{x5},{r1 + bh + 2} V{ret_y} H{left - 22} V{r2 + bh / 2} H{left - 4}" fill="none" '
          f'stroke="{GREY}" stroke-width="2" marker-end="url(#head)"/>\n')
    # the loop back: keep improving
    x = xs[4]
    b += arrow(xs[3] + bw + 2, r2 + bh / 2, x - 3, r2 + bh / 2)
    b += (f'<rect x="{x}" y="{r2}" width="{bw}" height="{bh}" rx="14" fill="none" stroke="{GREY}" '
          f'stroke-width="2" stroke-dasharray="6 5"/>\n')
    b += text(x + 14, r2 + 30, "↻", 20, fill=GREY, weight=700)
    b += text(x + 14, r2 + 62, "Keep improving", 15, fill=GREY, weight=700)
    b += text(x + 14, r2 + 81, "repeated comments → rules", 11.5, fill=GREY)
    b += f'<line x1="{x + 14}" y1="{r2 + 96}" x2="{x + bw - 14}" y2="{r2 + 96}" stroke="{GREY}" stroke-opacity="0.5"/>\n'
    b += text(x + 14, r2 + 115, "/retro", 11.5, fill=GREY, family=MONO)
    # the loop arrow from "keep improving" back up to planning
    b += (f'<path d="M{x + bw},{r2 + 24} H{w - 8} V{r1 - 30} H{xs[0] + 60}" fill="none" stroke="{GREY}" '
          f'stroke-width="1.5" stroke-dasharray="4 5" marker-end="url(#head)"/>\n')
    foot = r2 + bh + 34
    parts = [("Once per repo: ", SANS, 700), ("/setup-project", MONO, 400), ("     ·     Once per app, before step 9: ", SANS, 700),
             ("/deploy", MONO, 400), ("     ·     In Claude Code, type them as ", SANS, 700), ("/pipeline:<name>", MONO, 400)]
    spans = "".join(f'<tspan font-family="{f}" font-weight="{wt}">{escape(s)}</tspan>' for s, f, wt in parts)
    b += f'<text x="{left}" y="{foot}" font-size="12.5" fill="{GREY}" xml:space="preserve">{spans}</text>\n'
    return svg(w, foot + 14, b, "The flow: plan the language, Event Storming, test-first build, a small PR, two "
               "reviewer agents, your review, you merge, GitHub Actions, Kubernetes")


def strip(current):
    sw, gap, x0, h = 72, 6, 10, 28
    w = x0 * 2 + 9 * sw + 8 * gap
    b = ""
    groups = {"PLAN": (0, 1), "BUILD": (2, 4), "REVIEW": (5, 6), "SHIP": (7, 8)}
    for phase, (a, z) in groups.items():
        xa = x0 + a * (sw + gap)
        b += text(xa + 2, 12, phase, 10, fill=GREY, weight=700, spacing=1.4)
    for i, (n, phase, *_rest, short) in enumerate(STAGES):
        x, c = x0 + i * (sw + gap), PHASES[phase]
        if n == current:
            b += f'<rect x="{x}" y="20" width="{sw}" height="{h}" rx="7" fill="{c}"/>\n'
            b += text(x + sw / 2, 38.5, f"{n} {short}", 12, weight=700, anchor="middle")
            b += f'<path d="M{x + sw / 2 - 6},{20 + h + 3} l6,7 l6,-7 z" fill="{c}"/>\n'
        else:
            b += (f'<rect x="{x + 0.75}" y="20.75" width="{sw - 1.5}" height="{h - 1.5}" rx="7" fill="{c}" '
                  f'fill-opacity="0.12" stroke="{c}" stroke-opacity="0.55" stroke-width="1.5"/>\n')
            b += text(x + sw / 2, 38.5, f"{n} {short}", 12, fill=c, weight=600, anchor="middle")
    name = STAGES[current - 1][2]
    return svg(w, 60, b, f"Step {current} of 9: {name}")


def modes():
    cards = [
        ("learn", "You write the code.", "Claude teaches, hints and reviews.", 0.9, "practice projects"),
        ("build-with-me", "Claude writes ~60 lines at a time.", "You check each block and answer 1–2 questions.", 0.35,
         "learning while you ship"),
        ("deliver", "Claude builds the whole ticket.", "You review the PR.", 0.05, "small, clear tickets"),
    ]
    w, cw, ch, gap = 1000, 310, 150, 26
    b = ""
    for i, (name, l1, l2, you, when) in enumerate(cards):
        x = i * (cw + gap) + 4
        b += (f'<rect x="{x}" y="4" width="{cw}" height="{ch}" rx="14" fill="{PHASES["BUILD"]}" '
              f'fill-opacity="0.10" stroke="{PHASES["BUILD"]}" stroke-opacity="0.6" stroke-width="1.5"/>\n')
        b += text(x + 18, 36, name, 17, fill=PHASES["BUILD"], weight=700, family=MONO)
        b += text(x + 18, 62, l1, 13, fill=GREY, weight=700)
        b += text(x + 18, 81, l2, 12.5, fill=GREY)
        bar_w = cw - 36
        b += f'<rect x="{x + 18}" y="100" width="{bar_w}" height="12" rx="6" fill="{PHASES["PLAN"]}"/>\n'
        b += f'<rect x="{x + 18}" y="100" width="{max(bar_w * you, 12)}" height="12" rx="6" fill="{PHASES["SHIP"]}"/>\n'
        b += text(x + 18, 132, "who writes:", 11, fill=GREY)
        b += text(x + 86, 132, "you", 11, fill=PHASES["SHIP"], weight=700)
        b += text(x + 112, 132, "/", 11, fill=GREY)
        b += text(x + 122, 132, "Claude", 11, fill=PHASES["PLAN"], weight=700)
        b += text(x + cw - 18, 132, when, 11, fill=GREY, anchor="end")
    return svg(w, ch + 8, b, "Three build modes: learn, build-with-me, deliver")


def chrome():
    for c in (os.environ.get("CHROME"), "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
              shutil.which("google-chrome"), shutil.which("chromium"), shutil.which("chromium-browser")):
        if c and os.path.exists(c):
            return c
    raise SystemExit("Chrome or Chromium not found: set CHROME to its path")


def render(name, source, browser, work):
    w, h = re.search(r'width="(\d+(?:\.\d+)?)" height="(\d+(?:\.\d+)?)"', source).groups()
    src = work / f"{name}.svg"
    src.write_text(source)
    subprocess.run([browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={work / 'profile'}",
                    "--force-device-scale-factor=2", "--default-background-color=00000000",
                    f"--window-size={round(float(w))},{round(float(h))}", f"--screenshot={OUT / (name + '.png')}",
                    src.as_uri()], check=True, capture_output=True)


images = {"flow": hero(), "modes": modes(), **{f"step-{n}": strip(n) for n in range(1, 10)}}
browser = chrome()
with tempfile.TemporaryDirectory() as tmp:
    for name, source in images.items():
        render(name, source, browser, pathlib.Path(tmp))
print(f"wrote {', '.join(n + '.png' for n in images)} to {OUT}")
