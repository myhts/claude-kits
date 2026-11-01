## Working with the model (merge into CLAUDE.md)

- **Spending money needs a yes.** Anything that calls the real model (a live eval, a smoke test with a key, a
  script) runs only when I ask for it, and says its expected cost first. Normal builds and tests never call it.
- **The key** lives in a gitignored `.env`, loaded only for the command that needs it (running the app, a live
  eval); never in code, config, tests, logs or chat, and **never exported in the shell profile**: Claude Code started
  from a shell with `ANTHROPIC_API_KEY` set bills that key instead of my subscription. If you see a key anywhere in the
  repo, stop and tell me.
- **Invented data only**: claims, people, policies and wording are made up for this project. Never anything from a
  real employer, client or person, even anonymised.
- **Prompts are code**: a prompt change gets a version (its hash) and an eval run before it's called better.
- **Read `.claude/skills/llm-engineering`** before writing or reviewing code that calls the model; reviewers apply
  its `review-checklist.md` to such changes.
- Models: the app's own calls (API key) use `claude-haiku-5-5`; work done in Claude Code runs on my subscription.
  SDK `com.anthropic:anthropic-java` pinned. For current API facts use the built-in `claude-api` skill.
