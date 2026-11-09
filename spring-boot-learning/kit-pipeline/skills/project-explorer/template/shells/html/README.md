# Standalone HTML shell

Nothing to copy: `tools/bundle-html.mjs` writes the whole page (engine + styles + data inlined) as one file.

    node docs/explorer/tools/bundle-html.mjs docs/explorer/src/explorer-data.js docs/explorer/explorer.html

Open `docs/explorer/explorer.html` straight from disk. Because it's a `file://` page, code links open the editor at the
line (the engine works out the repo root from `meta.pagePath`). Rebuild after every data change.
