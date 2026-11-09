# Safety rules

These hold for the whole run, in every phase. When one applies, write it into PROGRESS.md under "Constraints" so a
later session sees it too.

## Confidential data

- Before reading data files, look for signs of client or personal data: folders like `client-data/`, `customers/`,
  `dumps/`, `exports/`, `*.sql` / `*.csv` / `*.xlsx` dumps, fixtures with real names, emails, addresses, policy or
  account numbers. Ask the user before opening them, and whether they're gitignored.
- Everything shown on the page or in a guide is **invented or anonymised**: demo tenants, fake names, example.com
  emails, made-up ids. Captured requests/rows/messages get scrubbed: tokens, API keys, cookies, passwords,
  connection strings, real names, emails, phone numbers, addresses, IPs outside localhost.
- Never send confidential data to an external API, including LLM APIs the project calls. Test data for those paths
  is invented.
- Don't read secret values from `.env*`, vaults or CI settings; you only need the variable names.

## Shared resources

- Find out what's shared before running anything: remote databases or brokers in config, kube contexts, cloud
  credentials, a shared Docker host, other projects' containers and ports on this machine (`docker ps`, `lsof -i`).
- Touch only what you start. Never stop, prune or reconfigure other projects' containers, volumes, networks or images.
  `docker system prune` and similar are out unless the user names exactly what to delete.
- Shared state is never "tidied up" without asking: consumer-group offsets, shared DB tables, queues, caches, feature
  flags, DNS, IAM.
- Load and fault labs run on the user's own machine unless they explicitly name another machine they own. On shared
  hosts, Kubernetes clusters or anything with real users: plan-only.

## The codebase

- Work on a branch if you change tracked files; commit only when asked.
- Changes you may make without asking: files under the explorer folder, `.vscode/launch.json` when `.vscode/` is
  untracked. Everything else (dependencies, build files, Dockerfiles, app code for failure switches, README links)
  is proposed at a gate first.
- Bugs found while tracing or measuring are reported (what, repro, impact), not fixed. The user decides.
- Leave the machine as you found it: stop processes you started, say what data you left behind and how to remove it.
