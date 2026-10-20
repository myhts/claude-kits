# ClaudeProjects: a Claude Code toolkit for learning and building Spring Boot systems

Agents, skills, an MCP setup and scripts that turn [Claude Code](https://claude.com/claude-code) into a **mentor,
reviewer and test partner** while *you* build, plus an implementer for when you want something done for you. Built for
Spring Boot 4 (Java 21, Postgres, Kafka, Redis); several parts work on any stack.

Every code claim in the skills is proved by a test (`spring-boot-learning/kit-check/`: 35 tests on Spring Boot 4.1.1),
and the templates are built and run by scripts before they ship.

## What you get

| | |
|---|---|
| **7 agents** | `mentor` · `code-reviewer` · `blind-reviewer` (independent, no project context) · `security-reviewer` · `deploy-reviewer` · `implementer` (writes code only when named) · `e2e-tester` |
| **14 skills** | `/learning-loop` · `/interview-drill` · `spring-boot` · `testing-patterns` · `jpa-patterns` · `transactions` · `resilience-patterns` · `logging-patterns` · `design-patterns` · `distributed-systems` · `system-design` · `java-modern` · `build-templates` · `e2e-testing` |
| **MCP** | Playwright MCP (a browser for Claude), limited to localhost, for exploring a running app and planning tests |
| **End-to-end testing** | Playwright + Testcontainers template: your app and its databases in containers, tests through the API and the UI |
| **`/project-explorer`** | Turns any codebase (any language) into an interactive architecture explorer with debug walkthroughs and optional scaling labs |
| **Scripts** | `setup.sh` (once), `new-project.sh` (a new project with everything installed), `spring-boot-learning/install.sh` (add the kit to an existing project) |

## Start

You need: [Claude Code](https://claude.com/claude-code), git, Java 21+, Docker, Node 22+, curl.

```bash
git clone https://github.com/myhts/ClaudeProjects.git && cd ClaudeProjects
./setup.sh                          # checks your tools; makes /project-explorer available in every project
./new-project.sh my-shop --e2e      # Spring Boot 4.1.1 + Postgres + the kit + end-to-end tests
cd my-shop && claude                # fill in "This project" at the end of CLAUDE.md first
> /learning-loop
```

Already have a project? `./spring-boot-learning/install.sh ~/code/your-project --dry-run`, then without `--dry-run`.
It never overwrites your files.

## Then

- **[GUIDE.md](GUIDE.md)**: the handbook. Every piece step by step, the workflows (a learning session, reviews,
  e2e tests, turning a project into interview material), applying it to other stacks, and how to improve it.
- **[spring-boot-learning/README.md](spring-boot-learning/README.md)**: the kit itself.
- **[skills/project-explorer/README.md](skills/project-explorer/README.md)**: the explorer skill.

## Layout

```
setup.sh, new-project.sh, GUIDE.md
spring-boot-learning/        the kit: install.sh, kit/ (agents, skills, CLAUDE.md), kit-e2e/, kit-check/ (the proofs)
skills/project-explorer/     a personal skill, linked into ~/.claude/skills/ by setup.sh
<your projects>/             created by new-project.sh; ignored by this repo (each is its own repository)
```

## Credits

The learning kit started from [piomin/claude-ai-spring-boot](https://github.com/piomin/claude-ai-spring-boot)
(Apache-2.0) and was reworked into a learning edition; `spring-boot-learning/NOTICE.md` lists what changed.
