# Coding standards

The `code-reviewer` agent reads this file on its standards axis. The implementer doesn't: it makes the code work, and
review makes it good.

Keep only **judgement calls** here. A rule a tool can check (a banned import, a file location, a formatting choice)
belongs in a linter rule, a hook or a CI job, where it costs nothing to enforce. `/retro` sorts new rules into the
right place.

The reviewer also applies the pack's review checklist (named in `docs/agents/stack.md`) and `GLOSSARY.md`: a word the
glossary lists under _Avoid_, in code, UI text or tests, is a violation.

## Names come from the glossary

Types, functions, tests, UI labels and log messages use the glossary's terms. When no term fits, that is a gap to settle
with `/grill-with-docs`, not a name to invent in the code.

## Comments say why

Code shows what it does. A comment earns its place by explaining a reason the code can't show. When that reason is a
decision someone might reverse, it belongs in an ADR, and the comment points at it.

## Tests go through the front door

Tests exercise the module through its public interface, at the seams agreed for the ticket, and set up their data
through the same interface. When a test needs a setup function that doesn't exist, add it to the module rather than
writing rows or fields directly.

## Failures are visible

Nothing is swallowed. An error at a boundary becomes a clear, typed response for the caller, and the original cause is
kept.
