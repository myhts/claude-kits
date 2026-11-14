"""make.py: writes the diagrams used by HOW-IT-WORKS.md.

    python3 docs/assets/how-it-works/make.py    (needs Google Chrome or Chromium; set CHROME to its path if it isn't found)

Each diagram is a hand-editable SVG in this folder. Headless Chrome renders it twice, to <name>-light.png and
<name>-dark.png, at twice its size and with a transparent background. HOW-IT-WORKS.md shows the one that matches the
reader's GitHub theme. PNGs are used for the same reason as in make-images.py: they look the same in every viewer.

The colours are CSS variables. Each SVG carries the light values in its own <style>, so it also opens correctly in a
browser; DARK below overrides them for the dark image. Edit the SVGs and re-run; don't edit the PNGs by hand.
"""
import os
import pathlib
import re
import shutil
import subprocess
import tempfile

HERE = pathlib.Path(__file__).parent
DARK = ("svg { --ink: #f0f6fc; --quiet: #9198a1; --edge: #7d8590; --grid: #3d444d; --accent: #4493f8; "
        "--tint: rgba(145, 152, 161, 0.14); --paper: #0d1117; }")


def chrome():
    for c in (os.environ.get("CHROME"), "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
              shutil.which("google-chrome"), shutil.which("chromium"), shutil.which("chromium-browser")):
        if c and os.path.exists(c):
            return c
    raise SystemExit("Chrome or Chromium not found: set CHROME to its path")


def render(name, source, browser, work):
    w, h = re.search(r'width="(\d+)" height="(\d+)"', source).groups()
    src = work / f"{name}.svg"
    src.write_text(source)
    subprocess.run([browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={work / 'profile'}",
                    "--force-device-scale-factor=2", "--default-background-color=00000000",
                    f"--window-size={w},{h}", f"--screenshot={HERE / (name + '.png')}", src.as_uri()],
                   check=True, capture_output=True)


browser = chrome()
written = []
with tempfile.TemporaryDirectory() as tmp:
    for path in sorted(HERE.glob("*.svg")):
        light = path.read_text()
        dark = light.replace("</style>", f"</style>\n<style>{DARK}</style>", 1)
        for theme, source in (("light", light), ("dark", dark)):
            render(f"{path.stem}-{theme}", source, browser, pathlib.Path(tmp))
            written.append(f"{path.stem}-{theme}.png")
print(f"wrote {', '.join(written)} to {HERE}")
