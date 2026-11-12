# The prompt sheet

For rounds without the plugin. These prompts are short enough to type from memory, and they work in Claude Code,
Cursor, Copilot chat or an online editor's assistant. Guide mode quotes them by number.

| # | Phase | Type |
|---|---|---|
| 1 | Orient (Build) | "Here's the brief: … List the five questions whose answers would change the design most, each with your guess and why it matters. No code." |
| 2 | Orient | "Which files handle …? Trace one request from entry to storage, citing file and line. Mark what you're unsure of." |
| 3 | Reproduce | "Write one failing test for: … → expected …. Only the test." |
| 4 | Fix | "Make this test pass with the smallest change. Don't edit any test." |
| 5 | Diagnose: the cause | "This fails with: …. Give three likely causes, each with the one check that would rule it out." |
| 6 | Diagnose: the edges | "For …, list at most eight edge cases: boundaries, twice and at once, each dependency failing, time and money, permissions. Each with input → expected (from the brief, not the code), risk, and unit or database." |
| 7 | Fix: options | "Give two or three ways to fix this, the smallest first. For each: where it lives, the pattern if any and the problem it solves, its cost, its size." |
| 8 | Fix: the sweep | "Where else in the code does this same mistake appear?" |
| 9 | Review | "Review … for bugs only: Correct, Safe, Reliable, in that order. Quote file:line and an input that breaks it. Flag any test made easier." |
| 10 | Wrap (Build) | "Given …, what breaks first at 10× and 100×? Say 'unknown' where there's no number." |
| 11 | Any time | "Explain … in five lines, and what breaks if line … is removed." Use it before you explain the code aloud |

**Their assistant can't edit files** (as in Meta's round): give it one function or one test at a time, and make the
change yourself. Never paste the whole repo.

**No AI at all:** the same phases. The prompts become the questions you ask yourself.
