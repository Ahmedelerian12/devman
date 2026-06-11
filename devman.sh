#!/usr/bin/env bash

# ==============================================================================
# DevMan - Unified DevOps Tool Manager (v4 Premium Edition)
# ==============================================================================

set -eo pipefail # Exit on error and pipe failures

# Colors for output
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'
NC=$'\e[0m' # No Color

# Directories
DEVMAN_DIR="${DEVMAN_DIR:-$HOME/.devman}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="$HOME/.config/devman"
LOG_FILE="$DEVMAN_DIR/devman.log"
LEARNING_PROGRESS_FILE="$DEVMAN_DIR/learning-progress.json"

DEVMAN_SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
    resolved_path=$(readlink -f "$DEVMAN_SCRIPT_PATH" 2>/dev/null || true)
    [[ -n "$resolved_path" ]] && DEVMAN_SCRIPT_PATH="$resolved_path"
fi
DEVMAN_SCRIPT_DIR="$(cd "$(dirname "$DEVMAN_SCRIPT_PATH")" && pwd)"

mkdir -p "$INSTALL_DIR"
mkdir -p "$DEVMAN_DIR/versions"
mkdir -p "$CONFIG_DIR"

# Detect OS and Architecture
OS_DETECTED=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$OS_DETECTED" == "darwin" ]]; then
    OS="darwin"
    EXE_EXT=""
    ARCHIVE_EXT="tar.gz"
elif [[ "$OS_DETECTED" == *"mingw"* || "$OS_DETECTED" == *"msys"* || "$OS_DETECTED" == *"cygwin"* ]]; then
    OS="windows"
    EXE_EXT=".exe"
    ARCHIVE_EXT="zip"
else
    OS="linux"
    EXE_EXT=""
    ARCHIVE_EXT="tar.gz"
fi

ARCH_DETECTED=$(uname -m)
if [[ "$ARCH_DETECTED" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH_DETECTED" == "aarch64" || "$ARCH_DETECTED" == "arm64" ]]; then
    ARCH="arm64"
elif [[ "$ARCH_DETECTED" == *"386"* || "$ARCH_DETECTED" == *"686"* ]]; then
    ARCH="386"
else
    ARCH="amd64" # default fallback
fi

# Check if INSTALL_DIR is in PATH (Warn only on stderr)
if [[ ":$PATH:" != *":$INSTALL_DIR:"* && "${1:-}" != "learn" && "${1:-}" != "completion" ]]; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH.${NC}" >&2
    echo "Add this to your ~/.bashrc or ~/.zshrc:" >&2
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
fi

# Locate registry.json
REGISTRY_PATH=""
if [[ -n "$DEVMAN_REGISTRY" && -f "$DEVMAN_REGISTRY" ]]; then
    REGISTRY_PATH="$DEVMAN_REGISTRY"
elif [[ -f "$DEVMAN_SCRIPT_DIR/registry.json" ]]; then
    REGISTRY_PATH="$DEVMAN_SCRIPT_DIR/registry.json"
elif [[ -f "$CONFIG_DIR/registry.json" ]]; then
    REGISTRY_PATH="$CONFIG_DIR/registry.json"
fi

# Fallback: if no registry exists, write the default one to config
if [[ -z "$REGISTRY_PATH" ]]; then
    REGISTRY_PATH="$CONFIG_DIR/registry.json"
    cat << 'EOF' > "$REGISTRY_PATH"
{
  "docker-compose": {
    "type": "github",
    "repo": "docker/compose",
    "pattern": "docker-compose-${OS}-${ARCH_RAW}${EXE_EXT}",
    "checksum_pattern": "docker-compose-${OS}-${ARCH_RAW}${EXE_EXT}.sha256"
  },
  "helm": {
    "type": "github",
    "repo": "helm/helm",
    "pattern": "helm-${VERSION}-${OS}-${ARCH}.${ARCHIVE_EXT}",
    "checksum_pattern": "helm-${VERSION}-${OS}-${ARCH}.${ARCHIVE_EXT}.sha256"
  },
  "k9s": {
    "type": "github",
    "repo": "derailed/k9s",
    "pattern": "k9s_${OS_CAP}_${ARCH}.${ARCHIVE_EXT}",
    "checksum_pattern": "checksums.sha256"
  },
  "kubectl": {
    "type": "direct",
    "url": "https://dl.k8s.io/release/${VERSION}/bin/${OS}/${ARCH}/kubectl${EXE_EXT}",
    "latest_version_url": "https://dl.k8s.io/release/stable.txt",
    "checksum_url": "https://dl.k8s.io/release/${VERSION}/bin/${OS}/${ARCH}/kubectl${EXE_EXT}.sha256",
    "post_install": "echo 'Running kubectl hook...'; kubectl version --client"
  },
  "minikube": {
    "type": "github",
    "repo": "kubernetes/minikube",
    "pattern": "minikube-${OS}-${ARCH}${EXE_EXT}",
    "checksum_pattern": "minikube-${OS}-${ARCH}${EXE_EXT}.sha256"
  },
  "stern": {
    "type": "github",
    "repo": "stern/stern",
    "pattern": "stern_${VERSION_NO_V}_${OS}_${ARCH}.${ARCHIVE_EXT}",
    "checksum_pattern": "stern_${VERSION_NO_V}_checksums.txt"
  },
  "terraform": {
    "type": "direct",
    "url": "https://releases.hashicorp.com/terraform/${VERSION_NO_V}/terraform_${VERSION_NO_V}_${OS}_${ARCH}.zip",
    "latest_version_url": "https://checkpoint-api.hashicorp.com/v1/check/terraform",
    "latest_version_jq": ".current_version",
    "checksum_url": "https://releases.hashicorp.com/terraform/${VERSION_NO_V}/terraform_${VERSION_NO_V}_SHA256SUMS",
    "gpg_signature_pattern": "terraform_${VERSION_NO_V}_SHA256SUMS.sig",
    "gpg_key_url": "https://www.hashicorp.com/.well-known/pgp-key.txt"
  },
  "tflint": {
    "type": "github",
    "repo": "terraform-linters/tflint",
    "pattern": "tflint_${OS}_${ARCH}.zip",
    "checksum_pattern": "checksums.txt"
  },
  "yq": {
    "type": "github",
    "repo": "mikefarah/yq",
    "pattern": "yq_${OS}_${ARCH}${EXE_EXT}",
    "checksum_pattern": "checksums"
  }
}
EOF
fi


# Load DevMan modules
DEVMAN_LIB_DIR="${DEVMAN_LIB_DIR:-$DEVMAN_SCRIPT_DIR/lib}"

for module in helpers tools env registry maintenance installer bootstrap learning tui; do
    module_path="$DEVMAN_LIB_DIR/$module.sh"
    if [[ ! -f "$module_path" ]]; then
        echo "Error: DevMan module not found: $module_path" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$module_path"
done
# ==============================================================================
# MAIN CLI
# ==============================================================================

case "$1" in
    install)
        check_prereqs
        if [[ -z "$2" ]]; then
            echo -e "${RED}Usage: $0 install <tool_name> [version]${NC}" >&2
            exit 1
        fi
        install_tool "$2" "$3"
        ;;
    install-all)
        check_prereqs
        install_all
        ;;
    use)
        if [[ -z "$2" || -z "$3" ]]; then
            echo -e "${RED}Usage: $0 use <tool_name> <version>${NC}" >&2
            exit 1
        fi
        set_active_version "$2" "$3"
        ;;
    uninstall)
        if [[ -z "$2" ]]; then
            echo -e "${RED}Usage: $0 uninstall <tool_name> [version]${NC}" >&2
            exit 1
        fi
        uninstall_tool "$2" "$3"
        ;;
    versions)
        if [[ -z "$2" ]]; then
            echo -e "${RED}Usage: $0 versions <tool_name>${NC}" >&2
            exit 1
        fi
        list_versions "$2"
        ;;
    list)
        check_prereqs
        list_tools
        ;;
    bootstrap)
        bootstrap_sample "$2"
        ;;
    logs)
        if [[ -f "$LOG_FILE" ]]; then
            cat "$LOG_FILE"
        else
            echo "No logs found at $LOG_FILE"
        fi
        ;;
    prune)
        prune_cache
        ;;
    registry)
        check_prereqs
        case "$2" in
            add)
                registry_add "$3" "$4" "$5" "$6" "$7"
                ;;
            remove)
                registry_remove "$3"
                ;;
            sync)
                registry_sync "$3"
                ;;
            *)
                echo "DevMan - Registry CLI Manager"
                echo "Usage: $0 registry {add|remove|sync}"
                echo ""
                echo "Examples:"
                echo "  $0 registry add new-tool github new/repo"
                echo "  $0 registry remove new-tool"
                echo "  $0 registry sync https://url-to-shared-registry.json"
                ;;
        esac
        ;;
    auto-switch)
        auto_switch_versions "$2"
        ;;
    run)
        check_prereqs
        run_adhoc_tool "$2" "$@"
        ;;
    check-updates)
        check_prereqs
        check_updates
        ;;
    upgrade)
        check_prereqs
        upgrade_tools "$2"
        ;;
    export)
        export_lockfile "$2"
        ;;
    import)
        check_prereqs
        import_lockfile "$2"
        ;;
    learn)
        shift
        learning_dispatch "$@"
        ;;
    tui)
        check_prereqs
        interactive_tui
        ;;
    completion)
        if [[ "$2" == "zsh" ]]; then
            echo "#compdef devman"
            echo "autoload -U +X bashcompinit && bashcompinit"
        fi
        cat << 'EOF'
_devman_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="list install install-all use uninstall versions bootstrap logs registry prune completion auto-switch run check-updates upgrade export import learn tui"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    case "${prev}" in
        install|uninstall|versions|bootstrap)
            local tools
            tools=$(jq -r 'keys[]' "$REGISTRY_PATH" 2>/dev/null || echo "")
            if [[ "${prev}" == "bootstrap" ]]; then
                tools="terraform kubernetes docker"
            fi
            COMPREPLY=( $(compgen -W "${tools}" -- ${cur}) )
            return 0
            ;;
        use|upgrade)
            local tools
            tools=$(jq -r 'keys[]' "$REGISTRY_PATH" 2>/dev/null || echo "")
            COMPREPLY=( $(compgen -W "${tools}" -- ${cur}) )
            return 0
            ;;
        registry)
            COMPREPLY=( $(compgen -W "add remove sync" -- ${cur}) )
            return 0
            ;;
        learn)
            COMPREPLY=( $(compgen -W "roadmap start next complete progress activity plan init lab validate cheatsheet project check tools quiz reset help" -- ${cur}) )
            return 0
            ;;
        cheatsheet|cheat|cs)
            COMPREPLY=( $(compgen -W "current flow all linux git shell docker kubernetes terraform ansible cicd observability security cloud capstone" -- ${cur}) )
            return 0
            ;;
        start|complete|done|lab|scaffold|validate|check|doctor|quiz)
            COMPREPLY=( $(compgen -W "linux git shell docker kubernetes terraform ansible cicd observability security cloud capstone" -- ${cur}) )
            return 0
            ;;
        completion)
            COMPREPLY=( $(compgen -W "bash zsh" -- ${cur}) )
            return 0
            ;;
    esac

    if [[ ${COMP_CWORD} -eq 3 ]]; then
        local prev_prev="${COMP_WORDS[COMP_CWORD-2]}"
        if [[ "${prev_prev}" == "use" || "${prev_prev}" == "uninstall" ]]; then
            local tool="${prev}"
            local versions=""
            if [[ -d "$DEVMAN_DIR/versions/$tool" ]]; then
                versions=$(find "$DEVMAN_DIR/versions/$tool" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || ls "$DEVMAN_DIR/versions/$tool" 2>/dev/null)
            fi
            COMPREPLY=( $(compgen -W "${versions}" -- ${cur}) )
            return 0
        fi
    fi
}

_devman_chpwd_hook() {
    if command -v devman &>/dev/null; then
        devman auto-switch --silent
    fi
}

if [[ -n "$ZSH_VERSION" ]]; then
    typeset -ga chpwd_functions
    if [[ "${chpwd_functions[(r)_devman_chpwd_hook]}" != "_devman_chpwd_hook" ]]; then
        chpwd_functions+=(_devman_chpwd_hook)
    fi
else
    if [[ ";$PROMPT_COMMAND;" != *";_devman_chpwd_hook;"* ]]; then
        PROMPT_COMMAND="_devman_chpwd_hook;$PROMPT_COMMAND"
    fi
fi

complete -F _devman_completions devman
EOF
        ;;
    *)
        # If in an interactive terminal, default to TUI dashboard
        if [[ -t 0 && -t 1 && -z "$1" ]]; then
            check_prereqs
            interactive_tui
        else
            echo "DevMan - Unified DevOps Tool Manager (v4 Premium)"
            echo "Usage: $0 {list|install <tool> [version]|install-all|use <tool> <version>|versions <tool>|uninstall <tool> [version]|bootstrap <type>|logs|prune|registry {add|remove|sync}|completion <bash|zsh>|auto-switch [--silent]|run <tool>@<version> <args>|check-updates|upgrade [tool]|export [file]|import [file]|learn <command>|tui}"
            echo ""
            echo "Examples:"
            echo "  $0                              # Launches interactive TUI dashboard"
            echo "  $0 run terraform@1.5.0 version  # Ad-hoc runner without linking version"
            echo "  $0 learn roadmap                # Shows the automated DevOps learning path"
            echo "  $0 learn lab docker             # Creates a Docker practice lab"
            echo "  $0 learn cheatsheet docker      # Shows step-by-step Docker help"
            echo "  $0 learn validate docker        # Validates lab files and tools"
            echo "  $0 check-updates                # Lists tools with pending updates"
            echo "  $0 upgrade                      # Upgrades all installed tools"
            echo "  $0 export devman.lock           # Locks environment version settings"
            echo "  $0 import devman.lock           # Installs and matches lockfile settings"
        fi
        ;;
esac
