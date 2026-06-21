# Claude Code Enhancement Suite

> Global instruction file for Claude Code. Keep under 300 lines. Details in `rules/`.

---

## Overview

An opinionated enhancement suite for Claude Code that enforces security-first development,
automatic skill activation, parallel agent orchestration, and context-efficient sessions.
Works across all project types: Kotlin, PHP/Laravel, Python, TypeScript, React, Next.js, Go.

**Philosophy**: Elite code quality through automation. Every rule exists to prevent a class
of mistake that costs time. Security is non-negotiable. Simplicity beats cleverness.

---

## Rule Priority

Rules execute in this order. Higher priority overrides lower.

| # | Rule | File | Summary |
|---|------|------|---------|
| 0 | **ZERO HARDCODE** | `rules/no-hardcode.md` | Scan for hardcoded secrets before ANY code change. No tokens, passwords, IPs, or fallback defaults in source. All values in .env/config. |
| 0.5 | **AUTO-SKILLS** | `rules/auto-skills.md` | Detect context and invoke matching skill automatically: create -> brainstorming, bug -> systematic-debugging, implement -> TDD, done -> verify. |
| P | **PONYTAIL** | `rules/force-skills.md` | Lazy senior dev mode. YAGNI first. stdlib over deps. One-liner over abstraction. Deletion over addition. Always active. |
| H | **HEADROOM** | `rules/headroom.md` | Context compression principles. Stale read detection, output bloat control, structural skeleton preservation. 60-95% savings. Runs silently. |
| K | **KARPATHY** | `rules/karpathy-coding.md` | Think before coding. State assumptions. Simplicity first. Surgical changes. Goal-driven execution with verification loops. |
| 1 | **PROJECT MEMORY** | `rules/project-memory.md` | Create `.claude/` in every project. Auto-save progress, decisions, architecture. Read before work, never ask "what were we doing?" |
| 2 | **PARALLEL x8** | `rules/parallel-agents.md` | Complex tasks (3+ files) -> 8 agents in 3 rounds with code contracts. Foundation -> Core -> Integration. |
| 3 | **AGENT SELECT** | `rules/agents.md` | Route to correct specialist agent by project type. See Agent Selection below. |
| 4 | **CODE STANDARDS** | `rules/code-standards.md` | 400-line file limit. 50-line function limit. SOLID. DRY. Immutability. Explicit error handling. |
| 5 | **PROCESS MGMT** | `rules/process-management.md` | Check port before starting servers. Kill duplicates. Never leave orphan processes. |
| 6 | **GIT WORKFLOW** | `rules/git-workflow.md` | Conventional commits. Feature branches. TDD approach. Code review after writing. |
| 7 | **CONTEXT SAVE** | `rules/context-preservation.md` | Persist decisions to MCP memory. Recovery protocol on session restart. |
| 8 | **WEB QUALITY** | `rules/force-skills.md` | 6 mandatory quality skills for all web projects. See Web Quality below. |

---

## Agent Selection by Project Type

Claude automatically selects the correct specialist agent based on project detection.

| Project Type | Detection | Primary Agent | Support Agents |
|-------------|-----------|---------------|----------------|
| Minecraft / Kotlin | `build.gradle.kts`, `plugin.yml` | `kotlin-master` (sole agent) | -- |
| PHP / Laravel | `composer.json`, `artisan` | `laravel-specialist` | `php-pro`, `fullstack-developer` |
| Dashboard / SaaS | Clear development intent | `laravel-dashboard-architect` | `laravel-specialist` |
| React / Next.js | `next.config.js`, `package.json` | `react-specialist` | `nextjs-developer`, `typescript-pro` |
| Python / Django | `manage.py`, `pyproject.toml` | `python-pro` | `django-developer` |
| Go | `go.mod` | General agent | -- |

**Always active** (all project types):
- `security-reviewer` -- runs after code touching auth, input, APIs, secrets
- `code-reviewer` -- runs after writing or modifying code
- `tdd-guide` -- enforces test-first methodology

---

## Library Auto-Loading

Libraries are reference knowledge that agents MUST read before writing code for that domain.

| Library | Path | When to Load |
|---------|------|-------------|
| Fairy Library | `~/.claude/library/fairy-library/` | Any Minecraft/Kotlin plugin work |
| Emisario Library | `~/.claude/library/emisario-library/` | Any Laravel/PHP/web project |
| CIA Library | `~/.claude/library/cia-library/` | Security audits, pentesting, hardening |
| Sombra Library | `~/.claude/library/sombra-library/` | ProGuard/R8 obfuscation (Java/Kotlin JARs only) |

**Loading protocol**: Invoke the matching skill first (e.g., `fairy-library`). If the skill is
not found, fall back to reading the markdown files directly from the paths above. Never skip
the library -- it contains version-specific API patterns that training data may lack.

---

## Language Rules

| Context | Language |
|---------|----------|
| Internal reasoning | English |
| Responses to user | User's language (match what they write in) |
| Code (variables, functions, classes) | English |
| `.claude/` project memory files | English |
| Comments in code | English |

---

## Web Quality Enforcement

For ANY web project (detected by `composer.json`, `package.json` with react/next/vue,
`.blade.php`, `.html`, or user mention of website/landing/dashboard), these 6 skills
are MANDATORY:

| Skill | When | What |
|-------|------|------|
| `accessibility` | During UI development | WCAG 2.2, ARIA, keyboard nav, contrast 4.5:1 |
| `best-practices` | During development | CSP headers, Trusted Types, SRI, no inline scripts |
| `core-web-vitals` | After creating pages | LCP, INP, CLS optimization |
| `performance` | During and after build | Lazy loading, async scripts, image optimization, cache |
| `seo` | For public pages | Meta tags, JSON-LD structured data, canonical URLs |
| `web-quality-audit` | Before declaring done | Master audit with 150+ checks |

**Workflow**: Build with accessibility + best-practices active -> optimize with performance +
core-web-vitals -> add seo for public pages -> run web-quality-audit as final gate ->
only then declare the task complete.

---

## Parallel Agents Protocol

When a task involves 3+ files, activate parallel execution:

```
Round 1 (Foundation -- no dependencies):
  Agent 1: Architect (structure, build config)
  Agent 2: Database (models, repositories)
  Agent 8: Security (validators, permissions)

Round 2 (Core -- depends on Round 1 output):
  Agent 3: Services (business logic)
  Agent 6: API (interfaces, middleware)
  Agent 7: Tests (unit + integration)

Round 3 (Integration -- depends on Rounds 1+2):
  Agent 4: Controllers (routes, commands)
  Agent 5: Events (listeners, observers)
```

**Critical rules**:
- Write exact code contracts BEFORE launching agents
- Each agent gets scope contracts (allowed_files, forbidden_files)
- Later rounds receive REAL code from earlier rounds, not descriptions
- Run 4 verification gates after completion: Scope, Contract, Build, Acceptance
- Never say "integration errors are expected" -- contracts prevent them

Full protocol: `rules/parallel-agents.md`

---

## Auto-Skill Activation

Skills fire automatically based on what Claude detects in the conversation:

| Detected Context | Skill Invoked |
|-----------------|---------------|
| User asks to CREATE/BUILD/MAKE | `brainstorming` -> `speckit` pipeline |
| Bug, error, test failure | `systematic-debugging` |
| Writing implementation code | `test-driven-development` |
| Complex task (3+ steps) | `writing-plans` |
| About to claim "done/fixed" | `verification-before-completion` |
| 2+ independent tasks | `dispatching-parallel-agents` |
| Web project detected | `web-quality-audit` + 5 quality skills |
| Session ending | `wrap-up` |

**Exceptions**: Simple questions, reading/exploring code, documentation-only tasks,
or when user says "skip brainstorming" or "just do it."

---

## MCP Servers

| Server | Purpose | Used For |
|--------|---------|----------|
| `memory` | Persistent memory across sessions | Decisions, preferences, bug solutions |
| `sequential-thinking` | Structured step-by-step reasoning | Architecture, debugging, complex problems |
| `context7` | Up-to-date library documentation | Framework APIs, version-specific syntax |
| `playwright` | Browser automation and E2E testing | Visual testing, user flow validation |

---

## Key Conventions

- **File limits**: 400 lines per file (800 absolute max). Functions under 50 lines. Max 4 nesting levels.
- **No hardcode**: All configurable values in .env or config files. No `|| 'default'` fallbacks in code.
- **Fail fast**: Missing required env vars throw errors, not silent defaults.
- **Process safety**: Always check if a port is in use before starting a server. Kill duplicates.
- **Project memory**: Every project gets a `.claude/` directory. Read it at session start. Update it after changes.
- **Temp file cleanup**: Delete any temporary files (patches, scripts, helpers) immediately after use.
- **Git**: Conventional commits (`feat:`, `fix:`, `refactor:`). Feature branches. Never force-push main.

---

## File Reference

Detailed rules are split into modules under `rules/`:

| Category | Files |
|----------|-------|
| Security | `no-hardcode.md`, `force-skills.md` (security-review enforcement) |
| Quality | `code-standards.md`, `karpathy-coding.md`, `headroom.md` |
| Workflow | `auto-skills.md`, `force-skills.md`, `workflow.md`, `git-workflow.md` |
| Architecture | `parallel-agents.md`, `agents.md`, `project-memory.md` |
| Context | `context-preservation.md`, `thinking-mode.md`, `performance.md`, `mcp-system.md` |
| Language-specific | `kotlin.md`, `laravel.md`, `php.md`, `python.md`, `typescript.md`, `react-nextjs.md` |
| Operations | `process-management.md`, `design-workflow.md` |
