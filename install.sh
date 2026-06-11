#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
LINK_PATH="$BIN_DIR/devman"
SHELL_RC=""
COMPLETION_SHELL="bash"
ASSUME_YES="${ASSUME_YES:-false}"

if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
    ASSUME_YES="true"
fi

say() {
    printf '%s\n' "$*"
}

confirm() {
    local prompt=$1
    if [[ "$ASSUME_YES" == "true" ]]; then
        return 0
    fi
    read -r -p "$prompt (y/N): " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

detect_shell_rc() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        SHELL_RC="$HOME/.zshrc"
        COMPLETION_SHELL="zsh"
    else
        SHELL_RC="$HOME/.bashrc"
        COMPLETION_SHELL="bash"
    fi
}

install_dependencies() {
    local deps=(git curl jq unzip tar gpg)

    say "Checking dependencies..."
    local missing=()
    local dep
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ "${#missing[@]}" -eq 0 ]]; then
        say "All required dependencies are available."
        return 0
    fi

    say "Missing: ${missing[*]}"
    if ! confirm "Install missing dependencies when supported"; then
        say "Skipping dependency installation."
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y git curl jq unzip tar gnupg
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git curl jq unzip tar gnupg2
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y git curl jq unzip tar gnupg2
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --needed git curl jq unzip tar gnupg
    elif command -v brew >/dev/null 2>&1; then
        brew install git curl jq unzip gpg || true
    elif [[ "$(uname -s | tr '[:upper:]' '[:lower:]')" == *mingw* || "$(uname -s | tr '[:upper:]' '[:lower:]')" == *msys* ]]; then
        say "Git Bash detected. Install missing dependencies with winget, Chocolatey, Scoop, or Git for Windows packages."
        say "Required: ${missing[*]}"
    else
        say "No supported package manager detected. Install manually: ${missing[*]}"
    fi
}

install_link() {
    mkdir -p "$BIN_DIR"
    chmod +x "$ROOT_DIR/devman.sh"
    ln -sf "$ROOT_DIR/devman.sh" "$LINK_PATH"
    say "Linked: $LINK_PATH -> $ROOT_DIR/devman.sh"
}

ensure_shell_setup() {
    detect_shell_rc
    touch "$SHELL_RC"

    local marker_start="# >>> DevMan setup >>>"
    local marker_end="# <<< DevMan setup <<<"
    if grep -qF "$marker_start" "$SHELL_RC"; then
        say "Shell setup already exists in $SHELL_RC"
        return 0
    fi

    cat >> "$SHELL_RC" << EOF

$marker_start
export PATH="\$HOME/.local/bin:\$PATH"
if command -v devman >/dev/null 2>&1; then
  eval "\$(devman completion $COMPLETION_SHELL)"
fi
$marker_end
EOF
    say "Added PATH and completion setup to $SHELL_RC"
}

main() {
    say "Installing DevMan from $ROOT_DIR"
    install_dependencies
    install_link
    ensure_shell_setup
    say ""
    say "Done. Restart your shell or run:"
    say "  source $SHELL_RC"
    say ""
    say "Try:"
    say "  devman"
    say "  devman learn roadmap"
}

main "$@"
