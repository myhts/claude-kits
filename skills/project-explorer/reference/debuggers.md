# Debuggers: detect, add, verify

Goal: the learner presses F5 (or one command) and a breakpoint in any flow step stops there. "Configured" isn't enough;
every breakpoint line on the page must be **verified to hit** while that flow runs.

## 1. Detect what exists

- `.vscode/launch.json`, `.vscode/tasks.json`, `.idea/runConfigurations/*.xml`, `.run/*.run.xml`, `.devcontainer/`,
  `.zed/debug.json`, `.nvim`/DAP configs, Makefile/justfile/npm-script targets named `debug`, Procfile, docker-compose
  services with debug ports (`5005`, `9229`, `5678`, `2345`), `JAVA_TOOL_OPTIONS`/`NODE_OPTIONS` with inspect flags.
- Is `.vscode/` tracked (`git ls-files .vscode`) or ignored? If tracked, new configs are a visible change: say so at the gate.
- Note how the app is normally started (scripts, compose profiles, env files): debug configs should start it the
  same way, only with the debugger attached.

## 2. Add configs (VS Code `launch.json` is the common denominator; add IntelliJ run configs if the team uses them)

| Stack | Launch / attach | Notes |
|---|---|---|
| Java / Kotlin (Spring, Quarkus, Micronaut) | `"type": "java"` launch with `mainClass`, `projectName`, `args`, `env`; or attach to `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005` | Extension: Debugger for Java. Kafka/queue listeners: suspend the thread only (VS Code default) so heartbeats continue |
| Node / TypeScript | `"type": "node"` launch with `runtimeExecutable` (npm/pnpm/tsx), `runtimeArgs`; or attach to `--inspect=9229` | `sourceMaps: true`; for ts-node/tsx/nest, `skipFiles: ["<node_internals>/**"]` |
| Browser (React, Vue, Angular, Svelte) | `"type": "chrome"` (or `msedge`) launch with `url` and `webRoot` | Or DevTools → Sources; Vite/Next source maps work out of the box |
| Next.js | `"type": "node"` launch with `runtimeArgs: ["--inspect"]` on `next dev` for server code + a chrome config for client code | Server components and route handlers run in Node |
| Python (Django, FastAPI, Flask, Celery) | `"type": "debugpy"` launch with `module: "uvicorn" / "django" / "celery"`, `args`, `justMyCode: false` when stepping into libraries | Needs the Python extension (bundles debugpy). In containers: `python -m debugpy --listen 0.0.0.0:5678` (adds a dev dependency: **ask**) |
| Go | `"type": "go"`, `mode: "debug"`, `program` | Needs Delve (`go install github.com/go-delve/delve/cmd/dlv@latest`: **ask**). Build with `-gcflags=all="-N -l"` when attaching |
| .NET | `"type": "coreclr"` launch (`program` = built dll, `preLaunchTask: build`) | C# Dev Kit / C# extension |
| Rust | `"type": "lldb"` (CodeLLDB) with `cargo: { args: ["build", "--bin", …] }` | Debug profile only |
| Ruby / Rails | `"type": "rdbg"` (vscode-rdbg) with `command: "bin/rails"`, `script: "server"` | `debug` gem (Ruby ≥ 3.1 bundled) |
| PHP | `"type": "php"` listen for Xdebug (port 9003) | Xdebug must be installed: **ask** |
| Elixir | `"type": "mix_task"`, `task: "phx.server"` | ElixirLS |
| Mobile (React Native, Flutter, native) | the platform's tooling (Flutter `"type": "dart"`, RN via Expo/Hermes debugger, Xcode, Android Studio) | Usually can't be verified headlessly: say so on the page |
| Serverless / cloud-only | `sam local`, `serverless offline`, Functions Core Tools, LocalStack | If it can't run locally, the page uses logs/traces instead of breakpoints and says so |

Add one config per thing the learner needs to run: each process role (API, worker, scheduler), the browser, and
lab variants (env/args differ). Compound configs for "API + worker" or "two instances". Use `${input:…}` prompts for
values the learner should choose (instance count, a lease size).

Name configs so the page can refer to them: `Run · API`, `Debug · worker`, `Lab · partner down`.

Adding a dependency, a build plugin, a Dockerfile change or anything outside `.vscode/` (or `.idea/`) is a gate:
ask first, say why it's needed, offer the no-change alternative (attach to an existing port, logs).

## 3. Verify every breakpoint line

A line can look right and never hit: inner/anonymous classes and lambdas compile to other classes, async callbacks
run later on other threads, code behind a feature flag or a cache hit is skipped, a blank or comment line never
breaks, source maps may be off by a few lines. So run each flow and prove the line executes:

| Method | How |
|---|---|
| Java `jdb` | Start with JDWP (`suspend=n`), `jdb -attach 5005`, `stop at com.x.Foo:42` (nested: `com.x.Foo$Inner:42`), run the flow, expect `Breakpoint hit`. Script it: feed jdb commands on stdin, grep the output |
| Node / browser CDP | `--inspect` (or headless Chrome `--remote-debugging-port`), `Debugger.enable`, `Debugger.setBreakpointByUrl({ urlRegex, lineNumber })`, run the flow, wait for `Debugger.paused`, then `Debugger.resume` |
| Python | `python -m pdb` for scripts; for servers, a temporary `sys.settrace` hook or `debugpy` + a DAP client; or coverage (below) |
| Go | `dlv debug --headless --listen :2345`, then `dlv connect` with `break file.go:42` / `continue` on stdin |
| Any stack: coverage | Run the flow under line coverage (JaCoCo, c8 / `NODE_V8_COVERAGE`, coverage.py, `go test -cover` / `GOCOVERDIR`, coverlet, simplecov) and confirm the line is covered. Proves execution, not thread/suspend behaviour, but it's universal |

Record each verified line in PROGRESS.md (`file:line: verified by jdb during flow 3`). If a line can't be verified,
move the breakpoint to one that can, or mark the step "(not verified: reason)" in the step text. Never ship an
unverified breakpoint silently.

## 4. Tell the learner the debugging gotchas of this stack

Write them into the step text where they bite: suspend-thread vs suspend-all, consumer session timeouts while paused
(the broker rebalances and redelivers), HTTP client timeouts while the server is paused, hot reload changing line
numbers, minified bundles without source maps, async stack traces, `justMyCode`.
