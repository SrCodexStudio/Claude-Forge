#!/usr/bin/env bash
# ============================================================================
#  Claude Code Enhancement Kit -- Installer (Windows / Git Bash)
# ============================================================================
#  Installs libraries, rules, skills, agents, MCP servers and shortcuts
#  into %USERPROFILE%\.claude\ for Windows environments running Git Bash.
#
#  Usage:  bash install-win.sh            (interactive)
#          bash install-win.sh --force    (overwrite existing files)
#          bash install-win.sh --dry-run  (show what would happen)
# ============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
#  Configuration
# ---------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"
FORCE=false
DRY_RUN=false
INSTALLED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

# Windows path resolution
if [[ -n "${USERPROFILE:-}" ]]; then
    WIN_HOME="$USERPROFILE"
else
    WIN_HOME="C:\\Users\\$USER"
fi

# Convert Windows path to Git Bash path for internal use
CLAUDE_DIR="$HOME/.claude"
BIN_DIR="$HOME/.local/bin"

# Windows native paths for .bat files
WIN_CLAUDE_DIR="${WIN_HOME}\\.claude"
WIN_BIN_DIR="${WIN_HOME}\\.local\\bin"

MANIFEST_FILE="$CLAUDE_DIR/.installed-manifest"

# MCP servers to register
MCP_SERVERS=(
    "memory|npx|-y|@anthropic-ai/claude-code-mcp-server|memory"
    "sequential-thinking|npx|-y|@anthropic-ai/claude-code-mcp-server|sequential-thinking"
    "context7|npx|-y|@anthropic-ai/claude-code-mcp-server|context7"
    "playwright|npx|-y|@anthropic-ai/claude-code-mcp-server|playwright"
)

# Shortcut commands
SHORTCUTS=(
    "claudeskip|claude --dangerously-skip-permissions"
    "zero|claude -p \"Run ZERO HARDCODE scan on this project\""
    "lulu|claude -p \"Run lulu-team discussion on this topic\""
    "codex|claude -p \"Explain this codebase architecture\""
)

# ---------------------------------------------------------------------------
#  Colors and formatting
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
banner() {
    echo ""
    echo "${CYAN}${BOLD}"
    echo "    ============================================================"
    echo "     Claude Code Enhancement Kit  v${VERSION}  (Windows)"
    echo "    ============================================================"
    echo ""
    echo "     Libraries | Rules | Skills | Agents | MCP Servers"
    echo "    ============================================================"
    echo "${RESET}"
}

info()    { echo "  ${BLUE}[INFO]${RESET}    $*"; }
ok()      { echo "  ${GREEN}[  OK]${RESET}    $*"; }
warn()    { echo "  ${YELLOW}[WARN]${RESET}    $*"; }
fail()    { echo "  ${RED}[FAIL]${RESET}    $*"; }
skip()    { echo "  ${DIM}[SKIP]${RESET}    $*"; }
step()    { echo ""; echo "  ${MAGENTA}${BOLD}--- $* ---${RESET}"; }
done_msg(){ echo "  ${GREEN}${BOLD}[DONE]${RESET}    $*"; }

# ---------------------------------------------------------------------------
#  Parse arguments
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --force)   FORCE=true ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: bash install-win.sh [--force] [--dry-run] [--help]"
            echo ""
            echo "  --force     Overwrite existing files (except CLAUDE.md)"
            echo "  --dry-run   Show what would be installed without changing anything"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *) fail "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
#  Windows environment detection
# ---------------------------------------------------------------------------
detect_windows() {
    step "Detecting Windows environment"

    if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
        ok "Git Bash detected: $(uname -s)"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        ok "Windows shell detected: $OSTYPE"
    else
        warn "Not running in Git Bash -- this installer is for Windows"
        warn "Use install.sh for Linux/macOS instead"
        read -r -p "  Continue anyway? [y/N] " response
        if [[ "$response" != "y" && "$response" != "Y" ]]; then
            exit 1
        fi
    fi

    ok "Home directory: $HOME"
    ok "Windows home:   $WIN_HOME"
    ok "Claude dir:     $CLAUDE_DIR"
}

# ---------------------------------------------------------------------------
#  Prerequisites check
# ---------------------------------------------------------------------------
check_prerequisites() {
    step "Checking prerequisites"
    local missing=0

    # git
    if command -v git &>/dev/null; then
        ok "git $(git --version | head -1 | sed 's/git version //')"
    else
        fail "git not found -- install from https://git-scm.com/"
        missing=$((missing + 1))
    fi

    # node
    if command -v node &>/dev/null; then
        ok "node $(node --version)"
    else
        fail "node not found -- install from https://nodejs.org/"
        missing=$((missing + 1))
    fi

    # npx
    if command -v npx &>/dev/null; then
        ok "npx available"
    else
        fail "npx not found -- comes with Node.js"
        missing=$((missing + 1))
    fi

    # claude CLI
    if command -v claude &>/dev/null; then
        ok "claude CLI found"
    else
        warn "claude CLI not found -- install from https://claude.ai/download"
        warn "MCP server setup will be skipped"
    fi

    if [[ $missing -gt 0 ]]; then
        echo ""
        fail "Missing $missing prerequisite(s). Install them and re-run."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
#  Directory setup
# ---------------------------------------------------------------------------
setup_directories() {
    step "Setting up directories"
    local dirs=(
        "$CLAUDE_DIR"
        "$CLAUDE_DIR/library"
        "$CLAUDE_DIR/rules"
        "$CLAUDE_DIR/skills"
        "$CLAUDE_DIR/agents"
        "$BIN_DIR"
    )
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                info "Would create: $dir"
            else
                mkdir -p "$dir"
                ok "Created $dir"
            fi
        else
            ok "Exists: $dir"
        fi
    done
}

# ---------------------------------------------------------------------------
#  Copy helper -- copies a directory tree, records to manifest
# ---------------------------------------------------------------------------
copy_dir() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local count=0

    if [[ ! -d "$src" ]]; then
        skip "Source not found: $src"
        return
    fi

    # Check if source has any files
    local file_count
    file_count=$(find "$src" -type f 2>/dev/null | wc -l)
    if [[ "$file_count" -eq 0 ]]; then
        skip "$label: source directory is empty"
        return
    fi

    while IFS= read -r -d '' file; do
        local rel="${file#$src/}"
        local target="$dest/$rel"
        local target_dir
        target_dir="$(dirname "$target")"

        if [[ -f "$target" ]] && [[ "$FORCE" != true ]]; then
            skip "Already exists: $rel"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            info "Would copy: $rel"
        else
            mkdir -p "$target_dir"
            cp "$file" "$target"
            echo "$target" >> "$MANIFEST_FILE"
            count=$((count + 1))
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        fi
    done < <(find "$src" -type f -print0 2>/dev/null)

    if [[ "$DRY_RUN" == true ]]; then
        info "$label: $file_count file(s) would be installed"
    else
        ok "$label: $count file(s) installed"
    fi
}

# ---------------------------------------------------------------------------
#  Install content
# ---------------------------------------------------------------------------
install_libraries() {
    step "Installing libraries"
    copy_dir "$REPO_DIR/library" "$CLAUDE_DIR/library" "Libraries"
}

install_rules() {
    step "Installing rules"
    copy_dir "$REPO_DIR/rules" "$CLAUDE_DIR/rules" "Rules"
}

install_skills() {
    step "Installing skills"
    copy_dir "$REPO_DIR/skills" "$CLAUDE_DIR/skills" "Skills"
}

install_agents() {
    step "Installing agents"
    copy_dir "$REPO_DIR/agents" "$CLAUDE_DIR/agents" "Agents"
}

install_templates() {
    step "Installing templates"
    if [[ -d "$REPO_DIR/templates" ]]; then
        copy_dir "$REPO_DIR/templates" "$CLAUDE_DIR/templates" "Templates"
    else
        skip "No templates directory found"
    fi
}

# ---------------------------------------------------------------------------
#  CLAUDE.md handling (never overwrite)
# ---------------------------------------------------------------------------
handle_claude_md() {
    step "Checking CLAUDE.md"
    local src="$REPO_DIR/templates/CLAUDE.md"
    local dest="$CLAUDE_DIR/CLAUDE.md"

    if [[ -f "$dest" ]]; then
        warn "CLAUDE.md already exists -- will NOT overwrite"
        warn "Your custom CLAUDE.md is preserved at: $dest"
        if [[ -f "$src" ]]; then
            info "A template is available at: $src"
            info "Merge manually if you want new features"
        fi
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    elif [[ -f "$src" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            info "Would install CLAUDE.md template"
        else
            cp "$src" "$dest"
            echo "$dest" >> "$MANIFEST_FILE"
            ok "Installed CLAUDE.md template"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        fi
    else
        skip "No CLAUDE.md template in repo"
    fi
}

# ---------------------------------------------------------------------------
#  MCP server setup
# ---------------------------------------------------------------------------
setup_mcp_servers() {
    step "Setting up MCP servers"

    if ! command -v claude &>/dev/null; then
        warn "claude CLI not found -- skipping MCP setup"
        warn "Install Claude CLI and re-run, or add servers manually"
        return
    fi

    for entry in "${MCP_SERVERS[@]}"; do
        IFS='|' read -r name cmd arg1 arg2 arg3 <<< "$entry"
        if [[ "$DRY_RUN" == true ]]; then
            info "Would add MCP server: $name"
        else
            if claude mcp add "$name" "$cmd" "$arg1" "$arg2" "$arg3" 2>/dev/null; then
                ok "MCP server: $name"
            else
                warn "MCP server '$name' may already exist or failed to add"
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
#  Shortcut .bat files for Windows
# ---------------------------------------------------------------------------
create_shortcuts() {
    step "Creating shortcut commands (.bat files)"

    for entry in "${SHORTCUTS[@]}"; do
        IFS='|' read -r name cmd <<< "$entry"
        local bat_path="$BIN_DIR/${name}.bat"
        local sh_path="$BIN_DIR/$name"

        # Create .bat file for cmd.exe / PowerShell
        if [[ -f "$bat_path" ]] && [[ "$FORCE" != true ]]; then
            skip "Shortcut exists: ${name}.bat"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        elif [[ "$DRY_RUN" == true ]]; then
            info "Would create: ${name}.bat"
        else
            # Write .bat content using printf to avoid Git Bash path translation
            printf '@echo off\r\n' > "$bat_path"
            printf '%s %%*\r\n' "$cmd" >> "$bat_path"
            echo "$bat_path" >> "$MANIFEST_FILE"
            ok "Created ${name}.bat"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        fi

        # Also create shell script for Git Bash
        if [[ -f "$sh_path" ]] && [[ "$FORCE" != true ]]; then
            skip "Shortcut exists: $name (shell)"
        elif [[ "$DRY_RUN" == true ]]; then
            info "Would create: $name (shell)"
        else
            cat > "$sh_path" << SHORTCUT_EOF
#!/usr/bin/env bash
# Auto-generated by Claude Code Enhancement Kit installer (Windows)
exec $cmd "\$@"
SHORTCUT_EOF
            chmod +x "$sh_path" 2>/dev/null || true
            echo "$sh_path" >> "$MANIFEST_FILE"
            ok "Created $name (shell)"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        fi
    done

    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        warn "$BIN_DIR is not in your PATH"
        info "For Git Bash, add to ~/.bashrc:"
        echo "    ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
        echo ""
        info "For Windows CMD/PowerShell, add to system PATH:"
        echo "    ${CYAN}${WIN_BIN_DIR}${RESET}"
        echo ""
    fi
}

# ---------------------------------------------------------------------------
#  Verification
# ---------------------------------------------------------------------------
verify_installation() {
    step "Verifying installation"
    local checks_passed=0
    local checks_total=0

    # Check directories
    for dir in library rules skills agents; do
        checks_total=$((checks_total + 1))
        if [[ -d "$CLAUDE_DIR/$dir" ]]; then
            local count
            count=$(find "$CLAUDE_DIR/$dir" -type f 2>/dev/null | wc -l)
            if [[ "$count" -gt 0 ]]; then
                ok "$dir: $count files"
                checks_passed=$((checks_passed + 1))
            else
                warn "$dir: directory exists but is empty"
            fi
        else
            fail "$dir: not found"
        fi
    done

    # Check shortcuts
    for entry in "${SHORTCUTS[@]}"; do
        IFS='|' read -r name _ <<< "$entry"
        checks_total=$((checks_total + 1))
        if [[ -f "$BIN_DIR/${name}.bat" ]] || [[ -x "$BIN_DIR/$name" ]]; then
            ok "Shortcut: $name"
            checks_passed=$((checks_passed + 1))
        else
            warn "Shortcut missing: $name"
        fi
    done

    echo ""
    if [[ "$checks_passed" -eq "$checks_total" ]]; then
        done_msg "All $checks_total checks passed"
    else
        warn "$checks_passed/$checks_total checks passed"
    fi
}

# ---------------------------------------------------------------------------
#  Summary
# ---------------------------------------------------------------------------
show_summary() {
    echo ""
    echo "${CYAN}${BOLD}    ============================================================"
    echo "     Installation Summary  (Windows)"
    echo "    ============================================================${RESET}"
    echo ""
    echo "    ${GREEN}Installed:${RESET}  $INSTALLED_COUNT files"
    echo "    ${YELLOW}Skipped:${RESET}    $SKIPPED_COUNT files (already existed)"
    if [[ "$FAILED_COUNT" -gt 0 ]]; then
        echo "    ${RED}Failed:${RESET}     $FAILED_COUNT files"
    fi
    echo ""
    echo "    ${BOLD}Installed to:${RESET}  $CLAUDE_DIR"
    echo "    ${BOLD}Windows path:${RESET}  $WIN_CLAUDE_DIR"
    echo "    ${BOLD}Shortcuts in:${RESET}  $BIN_DIR"
    echo "    ${BOLD}Manifest:${RESET}      $MANIFEST_FILE"
    echo ""
    echo "${CYAN}${BOLD}    ============================================================"
    echo "     Quick Start"
    echo "    ============================================================${RESET}"
    echo ""
    echo "    Git Bash:"
    echo "      Start a session:     ${GREEN}claude${RESET}"
    echo "      Skip permissions:    ${GREEN}claudeskip${RESET}"
    echo "      Hardcode scan:       ${GREEN}zero${RESET}"
    echo "      Team discussion:     ${GREEN}lulu${RESET}"
    echo "      Explain codebase:    ${GREEN}codex${RESET}"
    echo ""
    echo "    CMD / PowerShell:"
    echo "      Skip permissions:    ${GREEN}claudeskip.bat${RESET}"
    echo "      Hardcode scan:       ${GREEN}zero.bat${RESET}"
    echo ""
    echo "    Uninstall:             ${YELLOW}bash uninstall.sh${RESET}"
    echo "    Verify:                ${YELLOW}bash scripts/verify.sh${RESET}"
    echo ""
}

# ---------------------------------------------------------------------------
#  Main
# ---------------------------------------------------------------------------
main() {
    banner

    if [[ "$DRY_RUN" == true ]]; then
        echo "    ${YELLOW}${BOLD}DRY RUN MODE -- no changes will be made${RESET}"
        echo ""
    fi

    # Initialize manifest
    if [[ "$DRY_RUN" != true ]]; then
        mkdir -p "$(dirname "$MANIFEST_FILE")"
        echo "# Claude Code Enhancement Kit -- installed files (Windows)" > "$MANIFEST_FILE"
        echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)" >> "$MANIFEST_FILE"
        echo "# Version: $VERSION" >> "$MANIFEST_FILE"
        echo "# Platform: Windows (Git Bash)" >> "$MANIFEST_FILE"
    fi

    detect_windows
    check_prerequisites
    setup_directories
    install_libraries
    install_rules
    install_skills
    install_agents
    install_templates
    handle_claude_md
    setup_mcp_servers
    create_shortcuts
    verify_installation
    show_summary
}

main "$@"
