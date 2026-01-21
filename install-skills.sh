#!/usr/bin/env bash
# install-skills.sh - Install agent-duo skills to Claude Code and Codex CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INSTALL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[INSTALL]${NC} $1"; }

install_claude_skills() {
    local claude_skills_dir="$HOME/.claude/skills"

    log_info "Installing skills for Claude Code..."

    if [[ ! -d "$claude_skills_dir" ]]; then
        mkdir -p "$claude_skills_dir"
    fi

    cp "$SKILLS_DIR/peer-work.md" "$claude_skills_dir/"
    cp "$SKILLS_DIR/peer-review.md" "$claude_skills_dir/"

    log_info "Claude skills installed to $claude_skills_dir"
}

install_codex_skills() {
    # Codex CLI uses a similar skill structure
    local codex_skills_dir="$HOME/.codex/skills"

    log_info "Installing skills for Codex CLI..."

    if [[ ! -d "$codex_skills_dir" ]]; then
        mkdir -p "$codex_skills_dir"
        log_warn "Created $codex_skills_dir (verify this is correct for your Codex setup)"
    fi

    cp "$SKILLS_DIR/peer-work.md" "$codex_skills_dir/"
    cp "$SKILLS_DIR/peer-review.md" "$codex_skills_dir/"

    log_info "Codex skills installed to $codex_skills_dir"
}

show_usage() {
    cat << 'EOF'
Agent Duo Skills Installer

Usage:
  ./install-skills.sh [options]

Options:
  --claude-only    Only install Claude Code skills
  --codex-only     Only install Codex CLI skills
  --help           Show this help message

After installation, agents can use the skills with:
  Claude: claude --skill peer-work
  Codex:  codex --skill peer-work
EOF
}

main() {
    case "${1:-all}" in
        --claude-only)
            install_claude_skills
            ;;
        --codex-only)
            install_codex_skills
            ;;
        --help)
            show_usage
            ;;
        all|*)
            install_claude_skills
            install_codex_skills
            ;;
    esac

    log_info "Installation complete!"
    log_info ""
    log_info "To use in an Agent Duo session:"
    log_info "  1. Run ./start.sh [task-file]"
    log_info "  2. In Claude's terminal: claude --skill peer-work"
    log_info "  3. In Codex's terminal:  codex --skill peer-work"
}

main "$@"
