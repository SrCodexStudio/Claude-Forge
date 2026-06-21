# Installation Guide

> Tell Claude Code: "Read INSTALL.md and follow every step."

---

## Prerequisites

Before installing, ensure you have:

| Tool | Minimum Version | Check Command |
|------|----------------|---------------|
| Claude Code CLI | Latest | `claude --version` |
| Node.js | 18+ | `node --version` |
| Git | 2.30+ | `git --version` |
| Git Bash (Windows) | Included with Git | `bash --version` |

Install Claude Code CLI if missing:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 1. Clone the Repository

```bash
cd ~/Documents/GitHub
git clone https://github.com/YOUR_USERNAME/no_name_t.git
cd claude-forge
```

If you already have the repo, pull the latest changes:

```bash
cd ~/Documents/GitHub/claude-forge
git pull origin main
```

---

## 2. Run the Install Script

### Linux / macOS

```bash
chmod +x install.sh
./install.sh
```

### Windows (Git Bash)

```bash
bash install-win.sh
```

### What the Script Does

The installer performs these steps automatically:

1. Backs up your existing `~/.claude/` directory to `~/.claude/backup-YYYY-MM-DD/`
2. Copies all components to the correct locations
3. Merges CLAUDE.md (appends new content, does not replace existing)
4. Sets up MCP server configuration
5. Creates .bat shortcuts (Windows only)
6. Runs verification checks

---

## 3. What Gets Installed Where

### Libraries -> `~/.claude/library/`

Reference knowledge bases that agents read before writing code.

| Library | Contents | Used By |
|---------|----------|---------|
| `fairy-library/` | Paper/Bukkit API, Kotlin patterns, security | Minecraft/Kotlin projects |
| `emisario-library/` | Laravel 13, React 19, Tailwind 4, Nginx | PHP/Laravel projects |
| `cia-library/` | OWASP attacks, VPS hardening, pentesting | Security audits |
| `sombra-library/` | ProGuard/R8 obfuscation for Java/Kotlin | Code protection |

Files installed:

```
~/.claude/library/
  fairy-library/
    01-paper-bukkit-api.md
    02-kotlin-minecraft.md
    03-security-optimization.md
  emisario-library/
    01-laravel-complete.md
    02-react-tailwind-ui.md
    03-security-nginx-optimization.md
  cia-library/
    01-owasp-web-attacks.md
    02-vps-network-infrastructure.md
    03-pentesting-defensive-coding.md
  sombra-library/
    01-proguard-complete.md
```

### Rules -> `~/.claude/rules/`

Behavioral rules that Claude Code follows in every session.

| Rule File | Purpose |
|-----------|---------|
| `no-hardcode.md` | Zero Hardcode policy -- no secrets in code |
| `force-skills.md` | Auto-skill activation and enforcement |
| `auto-skills.md` | Context-based skill detection |
| `parallel-agents.md` | 8-agent parallel execution protocol |
| `project-memory.md` | Auto-save progress to .claude/ directories |
| `headroom.md` | Context compression (60-95% savings) |
| `karpathy-coding.md` | Think-before-coding discipline |
| `code-standards.md` | Code quality standards |
| `process-management.md` | Port/process duplicate prevention |
| `context-preservation.md` | Memory persistence between sessions |
| `thinking-mode.md` | Deep reasoning configuration |
| `git-workflow.md` | Commit and PR conventions |
| `design-workflow.md` | Visual design standards |
| `mcp-system.md` | MCP server usage rules |
| `performance.md` | Model selection and context management |
| `workflow.md` | Per-stack development workflows |
| `agents.md` | Agent orchestration and selection |
| `kotlin.md` | Kotlin/Minecraft-specific rules |
| `laravel.md` | Laravel/PHP-specific rules |
| `php.md` | Modern PHP 8.x rules |
| `python.md` | Python 3.10+ rules |
| `typescript.md` | TypeScript strict-mode rules |
| `react-nextjs.md` | React 18+ / Next.js 14+ rules |

### Skills -> `~/.claude/skills/`

Reusable capabilities invoked automatically or via slash commands. Over 160 skills are installed, organized by category:

- **Core**: brainstorming, plan, tdd, verify, systematic-debugging
- **Web Quality**: accessibility, best-practices, core-web-vitals, performance, seo, web-quality-audit
- **GEO/SEO**: geo-audit, geo-citability, geo-schema, geo-technical, geo-report
- **Code**: code-review, security-review, deslop, refactor-clean, smart-commit
- **Ponytail**: ponytail, ponytail-audit, ponytail-review, ponytail-debt
- **Context**: headroom, compact-guard, strategic-compact, token-efficiency
- **Libraries**: fairy-library, emisario-library, cia-library, sombra-library
- **Speckit Pipeline**: speckit-specify, speckit-plan, speckit-tasks, speckit-implement

### Agents -> `~/.claude/agents/`

Specialized agent definitions (35 agents total):

- **General**: architect, planner, code-reviewer, security-reviewer, tdd-guide
- **Language**: kotlin-master, laravel-specialist, php-pro, python-pro, typescript-pro
- **Framework**: react-specialist, nextjs-developer, django-developer, fullstack-developer
- **Domain**: laravel-dashboard-architect, pterodactyl-guard, tebex-store-designer
- **Operations**: build-error-resolver, refactor-cleaner, doc-updater, e2e-runner

### CLAUDE.md -> `~/.claude/CLAUDE.md`

The global instruction file. The installer **merges** new content into your existing CLAUDE.md rather than replacing it. If no CLAUDE.md exists, it creates one from the template.

---

## 4. MCP Server Setup

The following MCP servers should be configured in your Claude Code settings. Add them to `~/.claude/settings.json` under the `mcpServers` key:

### memory (Persistent Memory)

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
```

### sequential-thinking (Structured Reasoning)

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
```

### context7 (Up-to-date Library Docs)

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

### playwright (E2E Testing & Browser Automation)

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-playwright"]
    }
  }
}
```

### Combined Configuration

Your `~/.claude/settings.json` should contain all four servers. The install script adds them automatically, but if you need to add them manually, merge the blocks above into a single `mcpServers` object.

---

## 5. Batch Shortcuts Setup (Windows)

The installer creates `.bat` files in your PATH for quick Claude Code invocations:

| Shortcut | Command | What It Does |
|----------|---------|-------------|
| `claudeskip` | `claude --skip-permissions` | Start Claude Code skipping permission prompts |
| `zero` | `claude "run zero hardcode scan"` | Run a hardcode audit on current directory |
| `lulu` | `claude "lulu team discussion"` | Launch 12-agent Lulu team debate |
| `codex` | `claude --model opus` | Start Claude Code with Opus model |

### Manual Setup (if script did not run)

Create each `.bat` file in a directory on your PATH (e.g., `C:\Users\YourName\bin\`):

```bat
:: claudeskip.bat
@echo off
claude --skip-permissions %*
```

```bat
:: zero.bat
@echo off
claude "ejecuta chequeo de hardcodeo en el directorio actual" %*
```

```bat
:: lulu.bat
@echo off
claude "lulu team discussion: %*"
```

```bat
:: codex.bat
@echo off
claude --model opus %*
```

Add the directory to your PATH if it is not already there.

---

## 6. Verification

After installation, verify everything is in place:

### Quick Check

```bash
# Verify directory structure
ls ~/.claude/library/    # Should show 4 libraries
ls ~/.claude/rules/      # Should show 20+ rule files
ls ~/.claude/skills/     # Should show 160+ skill directories
ls ~/.claude/agents/     # Should show 30+ agent files
ls ~/.claude/CLAUDE.md   # Should exist
```

### Full Verification

```bash
# Count installed components
echo "Libraries: $(ls ~/.claude/library/ | wc -l)"
echo "Rules:     $(ls ~/.claude/rules/ | wc -l)"
echo "Skills:    $(ls ~/.claude/skills/ | wc -l)"
echo "Agents:    $(ls ~/.claude/agents/ | wc -l)"

# Verify MCP servers are configured
grep -c "mcpServers" ~/.claude/settings.json

# Test Claude Code starts
claude --version
```

### Expected Counts

| Component | Expected Count |
|-----------|---------------|
| Libraries | 4 |
| Rules | 25+ |
| Skills | 160+ |
| Agents | 30+ |

---

## 7. Uninstall

To remove all installed components:

```bash
# Option A: Restore from backup
cp -r ~/.claude/backup-YYYY-MM-DD/* ~/.claude/

# Option B: Remove specific components
rm -rf ~/.claude/library/fairy-library
rm -rf ~/.claude/library/emisario-library
rm -rf ~/.claude/library/cia-library
rm -rf ~/.claude/library/sombra-library
# Remove individual rule files (check rules/ directory for the full list)
# Remove individual skill directories (check skills/ directory for the full list)
# Remove individual agent files (check agents/ directory for the full list)
```

The installer always creates a backup before modifying anything. Check `~/.claude/` for directories named `backup-YYYY-MM-DD`.

To remove batch shortcuts (Windows):

```bash
rm ~/bin/claudeskip.bat ~/bin/zero.bat ~/bin/lulu.bat ~/bin/codex.bat
```

---

## Troubleshooting

### "claude: command not found"

Claude Code CLI is not installed or not on your PATH.

```bash
npm install -g @anthropic-ai/claude-code
```

If installed but not found, check your npm global bin path:

```bash
npm bin -g
```

Add that directory to your PATH.

### "Permission denied" when running install script

```bash
chmod +x scripts/install.sh
# or on Windows Git Bash:
bash scripts/install-win.sh
```

### MCP server fails to start

MCP servers are installed on-demand via `npx`. Ensure you have internet access and Node.js 18+. If a server hangs:

```bash
# Clear npx cache
npx clear-npx-cache
# Retry
npx -y @modelcontextprotocol/server-memory
```

### Skills not showing in Claude Code

Skills must be in `~/.claude/skills/` as directories containing a `SKILL.md` file (or similar). Verify:

```bash
ls ~/.claude/skills/brainstorming/
# Should contain SKILL.md or similar
```

### CLAUDE.md was replaced instead of merged

Restore from backup:

```bash
cp ~/.claude/backup-YYYY-MM-DD/CLAUDE.md ~/.claude/CLAUDE.md
```

Then manually merge the new content from `templates/CLAUDE.md` in this repo.

### "Port already in use" errors during development

The process management rules handle this automatically. If you see this outside Claude Code:

```bash
# Windows
netstat -ano | findstr :3000
taskkill /F /PID <PID>

# Linux/Mac
lsof -i :3000
kill -9 $(lsof -t -i:3000)
```

### Context gets slow or degraded

The headroom system handles this automatically. If you notice slowness:

1. Run `/compact` in Claude Code to compress context
2. The compact-guard skill preserves critical state during compaction
3. Context recovery reads `.claude/progress/current-task.md` to restore state

### Install script fails midway

The script is idempotent -- run it again safely. It skips components that are already correctly installed and only updates what is missing or outdated.

---

## Updating

To update to the latest version:

```bash
cd ~/Documents/GitHub/claude-forge
git pull origin main
bash install-win.sh   # Windows
./install.sh           # Linux/Mac
```

The installer detects existing installations and only updates changed files.
