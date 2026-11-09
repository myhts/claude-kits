# project-explorer (Claude Code skill)

Turns any repository into an interactive architecture explorer with step-by-step debugging flows, checkbox guides
and, if you ask for them, scaling labs. Claude does the work; this folder holds the instructions, the page engine and
the tools.

## Use it in a project

It comes with the `pipeline` plugin of claude-kits, and copy installs of the learning kit put it in
`.claude/skills/`:

```
cd ~/code/some-project
claude                      # or open the project in VS Code with Claude Code
> /pipeline:project-explorer      # with the plugin; /project-explorer in a copy install
```

You can add what you care about: `/project-explorer focus on the payments service` or
`/project-explorer resume`. It stops and asks at four points:

1. which flows to build, and whether the page is a **standalone HTML file** or a page **inside your React / Next /
   Vue / Svelte app** (offered only when one is detected);
2. before adding any debugger dependency or editing tracked config;
3. which concept ladders to build, **whether you want labs to scale it**, whether it may add dev-only failure
   switches, and where load may run;
4. the hand-over: what was verified, what wasn't, and the bugs it found (reported, never silently fixed).

Progress is kept in `docs/explorer/PROGRESS.md`, so a later session picks up where the last one stopped.

## What you get in the project

`docs/explorer/explorer.html` (open from disk; code links jump to the line in your editor), `TOUR.md`, `FLOWS.md`,
`LABS.md`, `MEASURED.md`, debugger configs in `.vscode/launch.json`, and `docs/explorer/tools/` so anyone can rebuild:

```
node docs/explorer/tools/bundle-html.mjs docs/explorer/src/explorer-data.js docs/explorer/explorer.html
node docs/explorer/tools/check-explorer.mjs docs/explorer/explorer.html
```

## Without the plugin

- **One repo, for the whole team**: copy this folder to `<repo>/.claude/skills/project-explorer/` and commit; everyone
  who opens that repo in Claude Code gets `/project-explorer`.
- **Every repo on your machine**: copy it to `~/.claude/skills/project-explorer/`. A repo that also has the plugin then
  lists it twice, so prefer the plugin where you can.

Requirements: Node 22+, and Chrome or Chromium for the visual check.

## Try the engine on its own

```
mkdir -p /tmp/xp/src && cp template/engine/* /tmp/xp/src/ && cp template/data/explorer-data.example.js /tmp/xp/src/explorer-data.js
node tools/bundle-html.mjs /tmp/xp/src/explorer-data.js /tmp/xp/explorer.html && open /tmp/xp/explorer.html
```
