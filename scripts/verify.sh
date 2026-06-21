#!/usr/bin/env bash
# ============================================================================
#  Claude Code Enhancement Kit -- Post-Install Verification
# ============================================================================
#  Checks that all components are properly installed and reports health.
#
#  Usage:  bash scripts/verify.sh          (full check)
#          bash scripts/verify.sh --quiet  (exit code only)
# ============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
#  Configuration
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
BIN_DIR="$HOME/.local/bin"
QUIET=false
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNED_CHECKS=0
FAILED_CHECKS=0

# ---------------------------------------------------------------------------
#  Colors
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    MAGENTA=$'\033[35m'
    CYAN=$'\033[36m'
    WHITE=$'\033[37m'
else
    BOLD="" DIM="" RESET=""
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
fi

# ---------------------------------------------------------------------------
#  Output helpers
# ---------------------------------------------------------------------------
pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    [[ "$QUIET" == true ]] && return
    echo "  ${GREEN}PASS${RESET}  $*"
}

warning() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WARNED_CHECKS=$((WARNED_CHECKS + 1))
    [[ "$QUIET" == true ]] && return
    echo "  ${YELLOW}WARN${RESET}  $*"
}

failed() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    [[ "$QUIET" == true ]] && return
    echo "  ${RED}FAIL${RESET}  $*"
}

section() {
    [[ "$QUIET" == true ]] && return
    echo ""
    echo "  ${MAGENTA}${BOLD}$*${RESET}"
    echo "  ${DIM}$(printf '%.0s-' {1..56})${RESET}"
}

# ---------------------------------------------------------------------------
#  Parse arguments
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=true ;;
        --help|-h)
            echo "Usage: bash scripts/verify.sh [--quiet] [--help]"
            echo ""
            echo "  --quiet   Suppress output, exit 0 if healthy, 1 if not"
            echo "  --help    Show this help message"
            exit 0
            ;;
    esac
done

# ---------------------------------------------------------------------------
#  Banner
# ---------------------------------------------------------------------------
if [[ "$QUIET" != true ]]; then
    echo ""
    echo "${CYAN}${BOLD}"
    echo "    ============================================================"
    echo "     Claude Code Enhancement Kit -- Health Report"
    echo "    ============================================================"
    echo "${RESET}"
fi

# ---------------------------------------------------------------------------
#  1. Prerequisites
# ---------------------------------------------------------------------------
check_prerequisites() {
    section "Prerequisites"

    if command -v git &>/dev/null; then
        pass "git installed ($(git --version | sed 's/git version //'))"
    else
        failed "git not installed"
    fi

    if command -v node &>/dev/null; then
        pass "node installed ($(node --version))"
    else
        failed "node not installed"
    fi

    if command -v npx &>/dev/null; then
        pass "npx available"
    else
        failed "npx not available"
    fi

    if command -v claude &>/dev/null; then
        pass "claude CLI installed"
    else
        warning "claude CLI not installed"
    fi
}

# ---------------------------------------------------------------------------
#  2. Directory structure
# ---------------------------------------------------------------------------
check_directories() {
    section "Directory Structure"

    if [[ -d "$CLAUDE_DIR" ]]; then
        pass "~/.claude/ exists"
    else
        failed "~/.claude/ not found"
        return
    fi

    for dir in library rules skills agents; do
        if [[ -d "$CLAUDE_DIR/$dir" ]]; then
            local count
            count=$(find "$CLAUDE_DIR/$dir" -type f 2>/dev/null | wc -l)
            if [[ "$count" -gt 0 ]]; then
                pass "$dir/ -- $count files"
            else
                warning "$dir/ -- exists but empty"
            fi
        else
            failed "$dir/ -- not found"
        fi
    done
}

# ---------------------------------------------------------------------------
#  3. Libraries
# ---------------------------------------------------------------------------
check_libraries() {
    section "Libraries"

    local lib_dir="$CLAUDE_DIR/library"
    if [[ ! -d "$lib_dir" ]]; then
        failed "Library directory missing"
        return
    fi

    local expected_libs=("cia-library" "emisario-library" "fairy-library" "sombra-library")
    for lib in "${expected_libs[@]}"; do
        if [[ -d "$lib_dir/$lib" ]]; then
            local count
            count=$(find "$lib_dir/$lib" -type f -name '*.md' 2>/dev/null | wc -l)
            if [[ "$count" -gt 0 ]]; then
                pass "$lib -- $count markdown files"
            else
                warning "$lib -- directory exists but no .md files"
            fi
        else
            warning "$lib -- not installed"
        fi
    done

    # Check for any additional libraries from the kit
    local extra_libs=("forge-library" "sentinel-library" "shadow-library")
    for lib in "${extra_libs[@]}"; do
        if [[ -d "$lib_dir/$lib" ]]; then
            local count
            count=$(find "$lib_dir/$lib" -type f 2>/dev/null | wc -l)
            pass "$lib -- $count files (extra)"
        fi
    done
}

# ---------------------------------------------------------------------------
#  4. Rules
# ---------------------------------------------------------------------------
check_rules() {
    section "Rules"

    local rules_dir="$CLAUDE_DIR/rules"
    if [[ ! -d "$rules_dir" ]]; then
        failed "Rules directory missing"
        return
    fi

    local core_rules=(
        "no-hardcode.md"
        "auto-skills.md"
        "force-skills.md"
        "parallel-agents.md"
        "project-memory.md"
        "code-standards.md"
        "agents.md"
    )

    for rule in "${core_rules[@]}"; do
        if [[ -f "$rules_dir/$rule" ]]; then
            pass "$rule"
        else
            warning "$rule -- not found"
        fi
    done

    # Count total rules
    local total
    total=$(find "$rules_dir" -type f \( -name '*.md' -o -name '*.mdc' \) 2>/dev/null | wc -l)
    pass "Total rule files: $total"
}

# ---------------------------------------------------------------------------
#  5. Skills
# ---------------------------------------------------------------------------
check_skills() {
    section "Skills"

    local skills_dir="$CLAUDE_DIR/skills"
    if [[ ! -d "$skills_dir" ]]; then
        failed "Skills directory missing"
        return
    fi

    local core_skills=(
        "brainstorming"
        "systematic-debugging"
        "test-driven-development"
        "verification-before-completion"
        "dispatching-parallel-agents"
        "writing-plans"
        "executing-plans"
        "lulu-team"
        "ponytail"
        "web-quality-audit"
    )

    for skill in "${core_skills[@]}"; do
        if [[ -d "$skills_dir/$skill" ]]; then
            # Check for SKILL.md or COMMAND.md inside
            if [[ -f "$skills_dir/$skill/SKILL.md" ]] || [[ -f "$skills_dir/$skill/COMMAND.md" ]]; then
                pass "$skill"
            else
                warning "$skill -- directory exists but no SKILL.md/COMMAND.md"
            fi
        else
            warning "$skill -- not installed"
        fi
    done

    # Count total skills
    local total
    total=$(find "$skills_dir" -maxdepth 1 -type d 2>/dev/null | wc -l)
    total=$((total - 1))  # subtract the skills dir itself
    pass "Total skill directories: $total"
}

# ---------------------------------------------------------------------------
#  6. Agents
# ---------------------------------------------------------------------------
check_agents() {
    section "Agents"

    local agents_dir="$CLAUDE_DIR/agents"
    if [[ ! -d "$agents_dir" ]]; then
        failed "Agents directory missing"
        return
    fi

    local core_agents=(
        "kotlin-master.md"
        "laravel-specialist.md"
        "security-reviewer.md"
        "code-reviewer.md"
        "planner.md"
        "architect.md"
        "tdd-guide.md"
    )

    for agent in "${core_agents[@]}"; do
        if [[ -f "$agents_dir/$agent" ]]; then
            pass "$agent"
        else
            warning "$agent -- not found"
        fi
    done

    # Count total agents
    local total
    total=$(find "$agents_dir" -type f -name '*.md' 2>/dev/null | wc -l)
    pass "Total agent files: $total"
}

# ---------------------------------------------------------------------------
#  7. MCP Servers
# ---------------------------------------------------------------------------
check_mcp_servers() {
    section "MCP Servers"

    if ! command -v claude &>/dev/null; then
        warning "claude CLI not available -- cannot verify MCP servers"
        return
    fi

    # Try to check settings files for MCP config
    local settings_file="$CLAUDE_DIR/settings.json"
    local local_settings="$CLAUDE_DIR/settings.local.json"

    if [[ -f "$settings_file" ]] || [[ -f "$local_settings" ]]; then
        local check_file
        if [[ -f "$local_settings" ]]; then
            check_file="$local_settings"
        else
            check_file="$settings_file"
        fi

        for server in memory sequential-thinking context7 playwright; do
            if grep -q "\"$server\"" "$check_file" 2>/dev/null; then
                pass "MCP server: $server (found in settings)"
            else
                warning "MCP server: $server (not found in settings)"
            fi
        done
    else
        warning "No settings file found -- cannot verify MCP servers"
        warning "Run 'claude mcp list' manually to check"
    fi
}

# ---------------------------------------------------------------------------
#  8. Shortcuts
# ---------------------------------------------------------------------------
check_shortcuts() {
    section "Shortcut Commands"

    local shortcuts=("claudeskip" "zero" "lulu" "codex")

    for name in "${shortcuts[@]}"; do
        local found=false

        # Check shell script
        if [[ -x "$BIN_DIR/$name" ]]; then
            pass "$name (shell script)"
            found=true
        fi

        # Check .bat file (Windows)
        if [[ -f "$BIN_DIR/${name}.bat" ]]; then
            pass "${name}.bat (Windows batch)"
            found=true
        fi

        if [[ "$found" == false ]]; then
            warning "$name -- not installed"
        fi
    done

    # Check PATH
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        pass "$BIN_DIR is in PATH"
    else
        warning "$BIN_DIR is NOT in PATH -- shortcuts may not work from terminal"
    fi
}

# ---------------------------------------------------------------------------
#  9. CLAUDE.md
# ---------------------------------------------------------------------------
check_claude_md() {
    section "Configuration"

    if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
        local size
        size=$(wc -c < "$CLAUDE_DIR/CLAUDE.md")
        local lines
        lines=$(wc -l < "$CLAUDE_DIR/CLAUDE.md")
        pass "CLAUDE.md exists ($lines lines, $size bytes)"

        # Check if it has key sections
        if grep -q "CLAUDE CODE" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
            pass "CLAUDE.md has enhancement kit sections"
        else
            warning "CLAUDE.md may not include enhancement kit config"
        fi
    else
        warning "CLAUDE.md not found -- Claude Code will use defaults"
    fi

    # Check manifest
    if [[ -f "$CLAUDE_DIR/.installed-manifest" ]]; then
        local manifest_lines
        manifest_lines=$(grep -v '^#' "$CLAUDE_DIR/.installed-manifest" 2>/dev/null | grep -c . || echo "0")
        pass "Install manifest: $manifest_lines entries"
    else
        warning "No install manifest found"
    fi
}

# ---------------------------------------------------------------------------
#  Health Report
# ---------------------------------------------------------------------------
show_report() {
    if [[ "$QUIET" == true ]]; then
        if [[ "$FAILED_CHECKS" -gt 0 ]]; then
            exit 1
        else
            exit 0
        fi
    fi

    echo ""
    echo "${CYAN}${BOLD}    ============================================================"
    echo "     Health Report"
    echo "    ============================================================${RESET}"
    echo ""

    local health_pct=0
    if [[ "$TOTAL_CHECKS" -gt 0 ]]; then
        health_pct=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    fi

    # Health bar
    local bar_width=40
    local filled=$(( (health_pct * bar_width) / 100 ))
    local empty=$(( bar_width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="="; done
    for ((i=0; i<empty; i++)); do bar+="."; done

    local color="$GREEN"
    local status="HEALTHY"
    if [[ "$health_pct" -lt 50 ]]; then
        color="$RED"
        status="UNHEALTHY"
    elif [[ "$health_pct" -lt 80 ]]; then
        color="$YELLOW"
        status="DEGRADED"
    fi

    echo "    ${BOLD}Status:${RESET}  ${color}${BOLD}${status}${RESET}"
    echo "    ${BOLD}Health:${RESET}  ${color}[${bar}]${RESET} ${health_pct}%"
    echo ""
    echo "    ${GREEN}Passed:${RESET}   $PASSED_CHECKS"
    echo "    ${YELLOW}Warnings:${RESET} $WARNED_CHECKS"
    echo "    ${RED}Failed:${RESET}   $FAILED_CHECKS"
    echo "    ${DIM}Total:${RESET}    $TOTAL_CHECKS checks"
    echo ""

    if [[ "$FAILED_CHECKS" -gt 0 ]]; then
        echo "    ${RED}${BOLD}Action required:${RESET} Re-run the installer to fix failures."
        echo "    ${DIM}bash install.sh --force${RESET}"
    elif [[ "$WARNED_CHECKS" -gt 0 ]]; then
        echo "    ${YELLOW}Some optional components missing.${RESET} Run installer to add them."
    else
        echo "    ${GREEN}All systems operational.${RESET}"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
#  Main
# ---------------------------------------------------------------------------
main() {
    check_prerequisites
    check_directories
    check_libraries
    check_rules
    check_skills
    check_agents
    check_mcp_servers
    check_shortcuts
    check_claude_md
    show_report
}

main "$@"
