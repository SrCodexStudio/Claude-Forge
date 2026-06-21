<p align="center">
<pre align="center">
     ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
    ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
    ██║     ██║     ███████║██║   ██║██║  ██║█████╗  
    ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  
    ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
     ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
    █████╗  ██║   ██║██████╔╝██║  ███╗█████╗  
    ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  
    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
</pre>
</p>

<p align="center">
  <strong>The complete enhancement system for Claude Code.</strong><br>
  40+ rules. 30+ agents. 3 libraries. One command to install.
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> &bull;
  <a href="#-architecture">Architecture</a> &bull;
  <a href="#-libraries">Libraries</a> &bull;
  <a href="#-skills">Skills</a> &bull;
  <a href="docs/INSTALL.md">Install Guide</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://github.com/SrCodexStudio/claude-forge/stargazers"><img src="https://img.shields.io/github/stars/SrCodexStudio/claude-forge?style=social" alt="Stars"></a>
  <a href="https://github.com/SrCodexStudio/claude-forge/issues"><img src="https://img.shields.io/github/issues/SrCodexStudio/claude-forge" alt="Issues"></a>
  <img src="https://img.shields.io/badge/claude%20code-compatible-blueviolet" alt="Claude Code Compatible">
  <img src="https://img.shields.io/badge/lines%20of%20knowledge-38%2C000%2B-brightgreen" alt="38,000+ Lines">
</p>

---

## What is Claude Forge?

Claude Forge is a **drop-in enhancement system** for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that transforms the default CLI into a hardened, opinionated development environment. It installs behavioral rules, specialized agents, reference libraries, and quality skills directly into your `~/.claude/` directory -- no forks, no patches, no wrappers.

Think of it as a `.dotfiles` repo, but for your AI coding assistant.

**Before Claude Forge**, Claude Code is a general-purpose coding tool. **After Claude Forge**, it becomes a security-aware, quality-enforcing, multi-agent development system that refuses to hardcode secrets, compresses its own context window, and can spin up 12 debating experts on any architecture decision.

---

## Why Claude Forge?

| Problem | Claude Forge Solution |
|---|---|
| Claude hardcodes API keys in code | **Zero Hardcode Policy** scans every file before work begins |
| Claude writes too much code | **Ponytail Mode** enforces YAGNI -- 80-94% less code |
| Context window fills up mid-session | **Headroom Compression** saves 60-95% of context |
| No security review happens | **Sentinel Library** provides 16,000+ lines of OWASP knowledge |
| Web projects ship without audits | **Web Quality Gate** runs 6 mandatory quality checks |
| Architecture decisions lack depth | **Lulu Team** runs 12-agent, 6-round adversarial debates |
| Agent forgets project state between sessions | **Project Memory** auto-saves progress to `.claude/` |
| Every project starts from scratch | **40+ rules** auto-load based on detected project type |

---

## Before vs After

```
                    BEFORE Claude Forge              AFTER Claude Forge
                    ──────────────────               ─────────────────
Security            Hopes for the best               Zero Hardcode scan on every task
Code volume         200 lines when 50 would do       Ponytail: stdlib first, one-liner if possible
Context usage       Burns through 1M tokens           Headroom: 60-95% compression
Web quality         "It looks fine to me"             6 automated quality gates (a11y, perf, SEO...)
Architecture        One perspective                   12 agents debating across 6 rounds
Knowledge base      Training data (stale)             38,000+ lines of curated, current patterns
Agent selection     Generic agent for everything      30+ specialized agents auto-selected
Project memory      Forgets everything between runs   Auto-saves to .claude/ directory
Laravel patterns    Generic PHP advice                17,000 lines of Laravel/React/Tailwind
Obfuscation         "Use ProGuard somehow"            5,600 lines of ProGuard/R8 recipes
Pentesting          "Be careful with security"        16,000 lines of OWASP + VPS hardening
```

---

## :rocket: Quick Start

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Windows 10/11, macOS, or Linux
- Git

### Installation

```bash
git clone https://github.com/SrCodexStudio/claude-forge.git
cd claude-forge
```

See **[docs/INSTALL.md](docs/INSTALL.md)** for the full installation guide, including:
- Automated installer script
- Manual installation steps
- Per-component installation
- Uninstall instructions

### Verify Installation

After installing, open Claude Code and type:

```
What rules and skills do you have loaded?
```

Claude should list the Forge rules, libraries, and skills. If it mentions Zero Hardcode, Ponytail, and Headroom -- you are good to go.

---

## :building_construction: Architecture

```
~/.claude/
├── CLAUDE.md                  # Master config -- personality, rules, priorities
├── rules/                     # 40+ behavioral rules (auto-loaded)
│   ├── no-hardcode.md         #   Zero Hardcode Policy (Rule #0)
│   ├── auto-skills.md         #   Skill auto-activation table
│   ├── force-skills.md        #   Mandatory skill enforcement
│   ├── parallel-agents.md     #   8-agent parallel execution
│   ├── project-memory.md      #   .claude/ project memory system
│   ├── code-standards.md      #   SOLID, DRY, KISS enforcement
│   ├── laravel.md             #   Laravel-specific patterns
│   ├── kotlin.md              #   Kotlin/Minecraft patterns
│   ├── typescript.md          #   TypeScript strict patterns
│   ├── react-nextjs.md        #   React 18+ / Next.js 14+
│   ├── python.md              #   Python 3.10+ patterns
│   ├── php.md                 #   PHP 8.x modern patterns
│   └── ...                    #   Git, security, process mgmt, etc.
│
├── agents/                    # 30+ specialized subagents
│   ├── kotlin-master.md       #   Minecraft/Kotlin all-in-one
│   ├── laravel-specialist.md  #   Laravel framework expert
│   ├── security-reviewer.md   #   OWASP vulnerability scanner
│   ├── code-reviewer.md       #   Quality gate reviewer
│   └── ...                    #   React, Next.js, Python, DB, etc.
│
├── skills/                    # Invokable skill modules
│   ├── zero-hardcode/         #   Secret scanning enforcement
│   ├── ponytail-mode/         #   YAGNI lazy-senior-dev mode
│   ├── headroom-compress/     #   Context compression engine
│   ├── web-quality-gate/      #   6-skill web quality audit
│   └── lulu-team/             #   12-agent adversarial debate
│
├── library/                   # Reference knowledge bases
│   ├── sentinel-library/      #   16,000+ lines cybersecurity
│   ├── forge-library/         #   17,000+ lines Laravel/React
│   └── shadow-library/        #   5,600+ lines ProGuard/R8
│
├── scripts/                   # Utility scripts (.bat/.sh)
├── templates/                 # Project scaffolding templates
└── docs/                      # Documentation
    └── INSTALL.md             #   Installation guide
```

### How Components Interact

```
                         User prompt arrives
                                |
                                v
                    ┌───────────────────────┐
                    │   CLAUDE.md (master)   │
                    │   Loads personality,   │
                    │   priorities, language │
                    └───────────┬───────────┘
                                |
                    ┌───────────v───────────┐
                    │   rules/ (auto-load)   │
                    │   40+ behavioral rules │
                    │   matched by context   │
                    └───────────┬───────────┘
                                |
               ┌────────────────┼────────────────┐
               |                |                |
    ┌──────────v──────┐  ┌─────v──────┐  ┌──────v──────────┐
    │  Zero Hardcode  │  │  Ponytail  │  │  Auto-Skills    │
    │  (Rule #0)      │  │  (YAGNI)   │  │  Detection      │
    │  Scans FIRST    │  │  Always on │  │  Context-aware  │
    └──────────┬──────┘  └─────┬──────┘  └──────┬──────────┘
               |                |                |
               └────────────────┼────────────────┘
                                |
               ┌────────────────v────────────────┐
               │        Skill Activation         │
               │  brainstorming -> planning ->   │
               │  TDD -> debugging -> verify     │
               └────────────────┬────────────────┘
                                |
          ┌─────────────────────┼─────────────────────┐
          |                     |                     |
   ┌──────v──────┐    ┌────────v────────┐    ┌───────v───────┐
   │   Agents    │    │   Libraries     │    │   Quality     │
   │   30+ specs │    │   38,000+ lines │    │   Gates       │
   │   per stack │    │   3 domains     │    │   6 checks    │
   └─────────────┘    └─────────────────┘    └───────────────┘
```

---

## :books: Libraries

Claude Forge ships three curated reference libraries. These are **not** generic documentation -- they are dense, opinionated pattern collections designed to be loaded into Claude's context before writing code.

### Sentinel Library -- Cybersecurity Intelligence

> `library/sentinel-library/` -- 16,000+ lines

| Module | Coverage |
|---|---|
| `01-owasp-web-attacks.md` | OWASP Top 10, SQL injection, XSS, CSRF, SSRF, deserialization |
| `02-vps-network-infrastructure.md` | VPS hardening, iptables, fail2ban, SSH, Docker security |
| `03-pentesting-defensive-coding.md` | White-hat methodology, secure code patterns, PHP/JS/Java/Kotlin |

**When it activates:** Any security review, code audit, VPS configuration, or when the `security-review` skill is invoked.

### Forge Library -- Laravel / React / Tailwind

> `library/forge-library/` -- 17,000+ lines

| Module | Coverage |
|---|---|
| `01-laravel-complete.md` | Laravel 10-13, Eloquent, queues, events, Sanctum, testing |
| `02-react-tailwind-ui.md` | React 19, Tailwind CSS 4, Inertia.js, component patterns |
| `03-security-nginx-optimization.md` | Nginx hardening, CSP headers, rate limiting, caching |

**When it activates:** Any Laravel, PHP, or web project (detected by `composer.json`, `artisan`, `.blade.php` files).

### Shadow Library -- Code Obfuscation

> `library/shadow-library/` -- 5,600+ lines

| Module | Coverage |
|---|---|
| `01-proguard-complete.md` | ProGuard/R8 rules, Gradle integration, keep rules, string encryption |

**When it activates:** Any obfuscation task, ProGuard configuration, or JAR protection request. Minecraft plugin protection is a primary use case.

---

## :shield: Core Skills

### Zero Hardcode Policy

**Priority: #0 -- runs before everything else.**

Every time Claude Forge writes or modifies code, it announces `EJECUTANDO CHEQUEO DE HARDCODEO...` and scans for:
- Hardcoded secrets, tokens, API keys, passwords
- Fallback anti-patterns: `|| 'value'`, `?? 'default'`, `?: 'fallback'`
- Inline config defaults: `config('key', 30)`, `os.getenv('X', 'default')`
- Hardcoded IPs, URLs, ports, connection strings

Violations are fixed **before** any other work begins.

### Ponytail Mode -- Lazy Senior Dev

Always active. Before writing any code, Claude climbs a decision ladder:

```
1. Does this need to exist at all?          (YAGNI)
2. Does the standard library do this?       (Use it)
3. Does a native platform feature cover it? (Use it)
4. Does an installed dependency solve it?   (Use it)
5. Can this be one line?                    (Make it one line)
6. Only then: write minimal code
```

Result: **80-94% less code** compared to default Claude Code output. No speculative abstractions. No boilerplate nobody asked for. Deletion over addition.

### Headroom Compression

Autonomous context management that runs silently every session:
- Detects stale file reads (file edited after it was read)
- Compresses Bash output (keeps errors, drops noise)
- Classifies content types and applies type-specific compression
- Protects recent context (last 4 messages never compressed)
- Targets **60-95% context savings** without quality loss

### Web Quality Gate

Six mandatory quality skills that auto-activate for any web project:

| Skill | What It Checks |
|---|---|
| `accessibility` | WCAG 2.2, ARIA, keyboard navigation, contrast ratios |
| `best-practices` | CSP headers, Trusted Types, SRI, no deprecated APIs |
| `core-web-vitals` | LCP, INP, CLS optimization |
| `performance` | Lazy loading, async scripts, responsive images, caching |
| `seo` | Meta tags, JSON-LD structured data, canonical URLs |
| `web-quality-audit` | Master audit with 150+ checks (runs last as verification) |

**Trigger:** Detected automatically when working on files like `composer.json`, `package.json`, `.blade.php`, `.html`, or any web framework.

### Lulu Team -- 12-Agent Adversarial Debate

For critical decisions, Claude Forge can spawn 12 specialized agents that run 6 rounds of structured debate:

```
Round 1: Research          Independent web search + library consultation
Round 2: Analysis          Each agent analyzes from their expertise domain
Round 3: Debate            Cross-agent rebuttals and counterarguments
Round 4: Devil's Advocate  Stress-test every conclusion
Round 5: Innovation        Creative alternatives and edge cases
Round 6: Consensus         Final recommendation with implementation roadmap
```

**Trigger:** User says "lulu", "team discussion", or "multi-agent debate".

---

## :robot: Agent System

Claude Forge includes 30+ specialized subagents, auto-selected based on project type:

| Project Type | Detection | Agents Used |
|---|---|---|
| **Minecraft / Kotlin** | `build.gradle.kts`, `plugin.yml` | `kotlin-master` (single all-in-one agent) |
| **PHP / Laravel** | `composer.json`, `artisan` | `laravel-specialist`, `php-pro`, `security-reviewer` |
| **React / Next.js** | `package.json` + next | `react-specialist`, `nextjs-developer`, `typescript-pro` |
| **Python / Django** | `manage.py`, `pyproject.toml` | `python-pro`, `django-developer`, `database-optimizer` |
| **Dashboard / SaaS** | Explicit user intent | `laravel-dashboard-architect` |
| **Any project** | Always | `code-reviewer`, `security-reviewer` |

### Parallel Agent Execution (x8)

For complex tasks (3+ files), Claude Forge automatically distributes work across 8 agents in 3 rounds:

```
Round 1 (Foundation):     Architect + Database + Security
Round 2 (Core Logic):     Services + API + Tests
Round 3 (Integration):    Controllers + Events

Each round's agents receive REAL output from previous rounds.
Contracts are defined BEFORE launch -- no integration drift.
```

---

## :scroll: Rules System

40+ rules in `rules/` auto-load based on context. No manual activation needed.

| Category | Rules | Purpose |
|---|---|---|
| **Security** | `no-hardcode`, `security` | Zero tolerance for secrets in code |
| **Quality** | `code-standards`, `karpathy-coding` | SOLID, DRY, KISS, surgical changes |
| **Workflow** | `auto-skills`, `force-skills` | Automatic skill pipeline activation |
| **Language** | `kotlin`, `laravel`, `php`, `python`, `typescript`, `react-nextjs` | Stack-specific patterns and conventions |
| **Operations** | `git-workflow`, `process-management` | Commit standards, port conflict prevention |
| **Context** | `context-preservation`, `project-memory`, `headroom` | Memory management across sessions |
| **Thinking** | `thinking-mode`, `performance` | Extended reasoning, model selection |

### Rule Priority Order

```
#0    Zero Hardcode          Always first -- security scan
#0.4  Lulu Team Override     If triggered, overrides all skill matching
#0.5  Auto-Skill Detection   Context-aware skill activation
#0.6  Temp File Cleanup      Delete all temporary files after use
#0.7  Web Quality Gate       Auto-active for web projects
#0.8  Codegraph Integration  Use code graph when available
#0.9  Task Tracking          Checklist for every task
#1    Project Memory         .claude/ directory management
#2    Parallel Agents        8-agent distribution for complex tasks
```

---

## :wrench: Commands Reference

| Command | Description |
|---|---|
| `/plan` | Create structured implementation plan |
| `/brainstorming` | Explore intent and approaches before coding |
| `/tdd` | Enforce test-driven development workflow |
| `/systematic-debugging` | Find root cause before proposing fixes |
| `/verification-before-completion` | Run verification commands before claiming done |
| `/web-quality-audit` | Run 150+ web quality checks |
| `/accessibility` | WCAG 2.2 compliance audit |
| `/seo` | Meta tags, structured data, JSON-LD audit |
| `/performance` | Loading, bundling, image optimization audit |
| `/core-web-vitals` | LCP, INP, CLS analysis |
| `/best-practices` | CSP, security headers, SRI audit |
| `/security-review` | OWASP vulnerability scan |
| `/code-review` | Quality and maintainability review |
| `/ponytail-review` | Find over-engineering to delete |
| `/ponytail-audit` | Whole-repo over-engineering scan |
| `/ponytail-debt` | List all `ponytail:` deferred items |
| `/headroom` | Context compression analysis |
| `/compact-guard` | Safe compaction with state preservation |
| `/deslop` | Remove AI-generated filler from code |
| `/lulu-team` | Launch 12-agent adversarial debate |
| `/learn` | Extract reusable patterns from session |
| `/handoff` | Generate session handoff document |
| `/recall` | Search past session memories |
| `/wiki` | Persistent research wiki management |
| `ejecuta la orden 66` | Full system security and performance audit |

---

## :gear: Configuration

Claude Forge is configured through `CLAUDE.md` at `~/.claude/CLAUDE.md`. Key sections:

| Section | Controls |
|---|---|
| `SUPER REGLAS` | Priority table for all rules |
| `PARALLEL AGENTS` | Agent count and activation threshold |
| `WEB QUALITY SKILLS` | Which quality gates are mandatory |
| `IDIOMA` | Response language (default: user's language, code: English) |
| `MCPs ACTIVOS` | Which MCP servers are expected |

---

## :camera: Screenshots

> Screenshots coming soon. To contribute screenshots, see [Contributing](#-contributing).

<!--
![Zero Hardcode Scan](docs/screenshots/zero-hardcode.png)
![Ponytail Mode](docs/screenshots/ponytail-mode.png)
![Lulu Team Debate](docs/screenshots/lulu-team.png)
![Web Quality Gate](docs/screenshots/web-quality-gate.png)
-->

---

## :handshake: Contributing

Contributions are welcome. Before submitting:

1. **Rules** go in `rules/` as standalone `.md` files
2. **Skills** go in `skills/<skill-name>/` with a `SKILL.md`
3. **Agents** go in `agents/` as `.md` files
4. **Libraries** go in `library/<library-name>/` with numbered modules

### Guidelines

- All rule/skill/agent files must be self-contained markdown
- Library modules should be numbered (`01-`, `02-`, `03-`)
- Test your additions with Claude Code before submitting
- Follow existing naming conventions
- Do not hardcode secrets or real credentials in examples

### Reporting Issues

Open an issue on GitHub with:
- Claude Code version
- OS and shell
- Steps to reproduce
- Expected vs actual behavior

---

## :page_facing_up: License

MIT License. See [LICENSE](LICENSE) for details.

---

## :star: Star History

<!-- Replace with actual repo URL after rename -->
[![Star History Chart](https://api.star-history.com/svg?repos=SrCodexStudio/claude-forge&type=Date)](https://star-history.com/#SrCodexStudio/claude-forge&Date)

---

<p align="center">
  <sub>Built by <a href="https://github.com/SrCodexStudio">SrCodexStudio</a> -- forging better AI-assisted development.</sub>
</p>
