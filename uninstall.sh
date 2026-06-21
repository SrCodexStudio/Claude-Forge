#!/usr/bin/env bash
# ============================================================================
#  Claude Code Enhancement Kit -- Uninstaller
# ============================================================================
#  Removes files installed by install.sh or install-win.sh.
#  Uses the manifest file to know exactly what was installed.
#  NEVER removes user's custom CLAUDE.md, settings, or memory.
#
#  Usage:  bash uninstall.sh            (interactive, asks confirmation)
#          bash uninstall.sh --yes      (skip confirmation)
#          bash uninstall.sh --dry-run  (show what would be removed)
# ============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
#  Configuration
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
BIN_DIR="$HOME/.local/bin"
MANIFEST_FILE="$CLAUDE_DIR/.installed-manifest"
CONFIRM=false
DRY_RUN=false
REMOVED_COUNT=0
KEPT_COUNT=0
MISSING_COUNT=0

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
else
    BOLD="" DIM="" RESET=""
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN=""
fi

info()    { echo "  ${BLUE}[INFO]${RESET}    $*"; }
ok()      { echo "  ${GREEN}[  OK]${RESET}    $*"; }
warn()    { echo "  ${YELLOW}[WARN]${RESET}    $*"; }
fail()    { echo "  ${RED}[FAIL]${RESET}    $*"; }
skip()    { echo "  ${DIM}[KEEP]${RESET}    $*"; }
step()    { echo ""; echo "  ${MAGENTA}${BOLD}--- $* ---${RESET}"; }

# ---------------------------------------------------------------------------
#  Parse arguments
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --yes|-y)  CONFIRM=true ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: bash uninstall.sh [--yes] [--dry-run] [--help]"
            echo ""
            echo "  --yes       Skip confirmation prompt"
            echo "  --dry-run   Show what would be removed without changing anything"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *) fail "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
#  Protected files -- NEVER remove these
# ---------------------------------------------------------------------------
PROTECTED_PATTERNS=(
    "*/CLAUDE.md"
    "*/.claude/settings.json"
    "*/.claude/settings.local.json"
    "*/.claude/history.jsonl"
    "*/.claude/agent-memory/*"
    "*/.claude/memory/*"
    "*/.claude/contexts/*"
    "*/.claude/projects/*"
    "*/.claude/cache/*"
    "*/.claude/downloads/*"
    "*/.claude/hooks/*"
    "*/.claude/homunculus/*"
    "*/.claude/file-history/*"
    "*/.claude/backups/*"
)

is_protected() {
    local file="$1"
    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        # shellcheck disable=SC2254
        case "$file" in
            $pattern) return 0 ;;
        esac
    done
    return 1
}

# ---------------------------------------------------------------------------
#  Collect files to remove
# ---------------------------------------------------------------------------
collect_removable_files() {
    local -a files=()

    if [[ -f "$MANIFEST_FILE" ]]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            files+=("$line")
        done < "$MANIFEST_FILE"
    fi

    # Also scan known installed directories for files from the kit
    local known_dirs=(
        "$CLAUDE_DIR/library"
        "$CLAUDE_DIR/rules"
        "$CLAUDE_DIR/skills"
        "$CLAUDE_DIR/agents"
        "$CLAUDE_DIR/templates"
    )

    # Shortcut files
    for name in claudeskip zero lulu codex; do
        [[ -f "$BIN_DIR/$name" ]] && files+=("$BIN_DIR/$name")
        [[ -f "$BIN_DIR/${name}.bat" ]] && files+=("$BIN_DIR/${name}.bat")
    done

    # Deduplicate
    printf '%s\n' "${files[@]}" | sort -u
}

# ---------------------------------------------------------------------------
#  Preview what will be removed
# ---------------------------------------------------------------------------
preview_removal() {
    step "Files that will be removed"

    local has_files=false
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        has_files=true

        if is_protected "$file"; then
            skip "$file (protected)"
            KEPT_COUNT=$((KEPT_COUNT + 1))
        elif [[ -f "$file" ]]; then
            info "$file"
        else
            echo "  ${DIM}[GONE]${RESET}    $file (already removed)"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    done < <(collect_removable_files)

    if [[ "$has_files" == false ]]; then
        warn "No installed files found"
        warn "Nothing to uninstall"
        exit 0
    fi

    step "Files that will be preserved"
    skip "CLAUDE.md (your custom configuration)"
    skip "settings.json (your preferences)"
    skip "history.jsonl (session history)"
    skip "agent-memory/ (persistent memory)"
    skip "projects/ (project-level memory)"
    skip "hooks/ (custom hooks)"
    skip "cache/, downloads/, backups/"
}

# ---------------------------------------------------------------------------
#  Remove files
# ---------------------------------------------------------------------------
remove_files() {
    step "Removing installed files"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        if is_protected "$file"; then
            skip "$file (protected)"
            KEPT_COUNT=$((KEPT_COUNT + 1))
            continue
        fi

        if [[ ! -f "$file" ]]; then
            MISSING_COUNT=$((MISSING_COUNT + 1))
            continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            info "Would remove: $file"
        else
            rm -f "$file"
            ok "Removed: $(basename "$file")"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    done < <(collect_removable_files)

    # Clean up empty directories left behind
    if [[ "$DRY_RUN" != true ]]; then
        step "Cleaning empty directories"
        for dir in "$CLAUDE_DIR/library" "$CLAUDE_DIR/templates"; do
            if [[ -d "$dir" ]]; then
                # Remove directory only if empty (recursively)
                find "$dir" -type d -empty -delete 2>/dev/null || true
                if [[ ! -d "$dir" ]]; then
                    ok "Removed empty: $dir"
                fi
            fi
        done
    fi

    # Remove manifest itself
    if [[ "$DRY_RUN" != true ]] && [[ -f "$MANIFEST_FILE" ]]; then
        rm -f "$MANIFEST_FILE"
        ok "Removed manifest"
    fi
}

# ---------------------------------------------------------------------------
#  Remove MCP servers
# ---------------------------------------------------------------------------
remove_mcp_servers() {
    step "Removing MCP servers"

    if ! command -v claude &>/dev/null; then
        warn "claude CLI not found -- skipping MCP removal"
        return
    fi

    for name in memory sequential-thinking context7 playwright; do
        if [[ "$DRY_RUN" == true ]]; then
            info "Would remove MCP server: $name"
        else
            if claude mcp remove "$name" 2>/dev/null; then
                ok "Removed MCP: $name"
            else
                warn "MCP '$name' may not exist or failed to remove"
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
#  Summary
# ---------------------------------------------------------------------------
show_summary() {
    echo ""
    echo "${CYAN}${BOLD}    ============================================================"
    echo "     Uninstall Summary"
    echo "    ============================================================${RESET}"
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        echo "    ${YELLOW}DRY RUN -- no files were actually removed${RESET}"
    else
        echo "    ${RED}Removed:${RESET}    $REMOVED_COUNT files"
    fi
    echo "    ${GREEN}Kept:${RESET}       $KEPT_COUNT files (protected)"
    echo "    ${DIM}Missing:${RESET}    $MISSING_COUNT files (already gone)"
    echo ""
    echo "    Your CLAUDE.md, settings, and memory are untouched."
    echo ""
    if [[ "$DRY_RUN" != true ]]; then
        echo "    To reinstall: ${GREEN}bash install.sh${RESET}"
        echo ""
    fi
}

# ---------------------------------------------------------------------------
#  Main
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo "${CYAN}${BOLD}"
    echo "    ============================================================"
    echo "     Claude Code Enhancement Kit -- Uninstaller"
    echo "    ============================================================"
    echo "${RESET}"

    if [[ "$DRY_RUN" == true ]]; then
        echo "    ${YELLOW}${BOLD}DRY RUN MODE -- no changes will be made${RESET}"
        echo ""
    fi

    preview_removal

    if [[ "$DRY_RUN" != true ]] && [[ "$CONFIRM" != true ]]; then
        echo ""
        echo -n "  ${YELLOW}Proceed with uninstall?${RESET} [y/N] "
        read -r response
        if [[ "$response" != "y" && "$response" != "Y" ]]; then
            echo ""
            info "Cancelled. Nothing was removed."
            exit 0
        fi
    fi

    remove_files
    remove_mcp_servers
    show_summary
}

main "$@"
