# The survey on a big repository

A repository with more than a handful of services or modules is too much to read in one context. Hand the reading to
subagents and keep the judgement here. On a small repository, read it yourself and skip this page.

## Who does what

| Work | Who | Model |
|---|---|---|
| Reading one service or module and returning its fact sheet | one Explore subagent per service or module, all started in one message | `model: "sonnet"` |
| Checking and merging the sheets; the map and flow list; the gates; the flows, explanations, concepts and labs; reading screenshots | this session | Opus |
| Any other subagent | | `model: "opus"` |

**Why:** measured in claude-kits `kit-check/explorer-eval/` (2026-11-09) on an 11-service, 5-language repository.
Sonnet readers found every entry point, call and store the Opus readers found, with no broken references, in two runs
out of two, and halved the cost of the run. Haiku readers found the same, but made 3 to 4 times the tool calls, cost
no less, and noted far less of what they couldn't trace. If this session isn't on Opus, say so in one line at the
start: the map and the flows are judgement.

## What each reader gets

Its folder, the format and the rules below, and "return only the fact sheet":

```json
{
  "name": "checkoutservice",
  "language": "Go",
  "entryPoints": [{ "name": "CheckoutService.PlaceOrder", "ref": "src/checkoutservice/main.go:226" }],
  "calls": [{ "to": "paymentservice", "how": "gRPC", "ref": "src/checkoutservice/main.go:390" }],
  "stores": [{ "name": "Redis", "ref": "src/cartservice/src/cartstore/RedisCartStore.cs:40" }],
  "unsure": ["anything it couldn't trace, one line each"]
}
```

| Field | What goes in it |
|---|---|
| `name` | the service, by the name it's deployed under |
| `entryPoints` | what something outside the service can call: a gRPC method as `Service.Method`, an HTTP route as `METHOD /path`, a consumer as `consume <topic>`, a schedule as `cron <expression>` |
| `calls` | each other service or outside system it talks to over the network, by its deployed name, and how (gRPC, HTTP, a queue) |
| `stores` | each database, cache or file store it reads or writes |
| `ref` | the line where it happens, as `path:line` from the repository root: one line per item |
| `unsure` | whatever couldn't be traced to a line |

**Rules for readers:** report only what the code shows, never a guess from a name. Every item cites its line; an item
without one goes in `unsure`. Read-only commands; don't run or build anything.

## Merging and checking (this session)

1. **One sheet per folder.** If one is missing or unreadable, read that folder yourself.
2. **Merge** into `survey.json` in the output folder: `{ "services": [ <sheet>, … ] }`.
3. **Check coverage** against what the repository declares, where it declares it:
   - every contract (proto services, OpenAPI paths, route tables, topics) appears as an entry point;
   - every address a deployment is given (`*_ADDR`-style variables, compose `depends_on`, Kubernetes manifests)
     appears as a call or a store.
   Anything missing: read it and add it, or say in PROGRESS.md why it's left out.
4. **Spot-check references**, calls between services first: open a few cited lines per sheet. A wrong one means
   checking the rest of that sheet. A ref listing several lines becomes one item per line.
5. **A call no contract or deployment supports** gets verified by you before it goes on the map.

Then draft the map and the flow list from `survey.json` (SKILL.md, Phase 1).
