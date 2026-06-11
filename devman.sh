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
elif [[ -f "$(dirname "$0")/registry.json" ]]; then
    REGISTRY_PATH="$(dirname "$0")/registry.json"
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

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

log_message() {
    local action=$1
    local status=${2:-INFO}
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$status] $action" >> "$LOG_FILE"
}

check_prereqs() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}Error: '$dep' is required but not installed.${NC}" >&2
            echo "Please install it to run DevMan." >&2
            exit 1
        fi
    done
}

check_jq_prereq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' is required for DevMan learning progress tracking.${NC}" >&2
        echo "Install jq, or use learning commands that do not track progress: learn help, plan, lab, tools, or check." >&2
        exit 1
    fi
}

tool_exists() {
    local tool_name=$1
    jq -e ".[\"$tool_name\"]" "$REGISTRY_PATH" &>/dev/null
}

get_tool_field() {
    local tool_name=$1
    local field=$2
    jq -r ".[\"$tool_name\"].$field // empty" "$REGISTRY_PATH"
}

github_curl() {
    local url=$1
    if [[ -n "$GITHUB_TOKEN" ]]; then
        curl -s -H "Authorization: token $GITHUB_TOKEN" "$url"
    else
        curl -s "$url"
    fi
}

resolve_github_version() {
    local repo=$1
    local version=$2
    local api_url=""
    local resolved_tag=""

    if [[ "$version" == "latest" ]]; then
        api_url="https://api.github.com/repos/${repo}/releases/latest"
        local response
        response=$(github_curl "$api_url")
        resolved_tag=$(echo "$response" | jq -r '.tag_name // empty')
        if [[ -z "$resolved_tag" || "$resolved_tag" == "null" ]]; then
            local msg
            msg=$(echo "$response" | jq -r '.message // empty')
            echo -e "${RED}Error: Could not fetch latest release for $repo from GitHub API.${NC}" >&2
            if [[ -n "$msg" ]]; then
                echo -e "${YELLOW}API Message: $msg${NC}" >&2
            fi
            exit 1
        fi
    else
        # Verify the tag exists
        local tag_to_try="$version"
        api_url="https://api.github.com/repos/${repo}/releases/tags/$tag_to_try"
        local response
        response=$(github_curl "$api_url")
        resolved_tag=$(echo "$response" | jq -r '.tag_name // empty')

        if [[ -z "$resolved_tag" || "$resolved_tag" == "null" ]]; then
            # If tag not found, try with prepended "v" if not present
            if [[ "$version" != v* ]]; then
                tag_to_try="v$version"
                api_url="https://api.github.com/repos/${repo}/releases/tags/$tag_to_try"
                response=$(github_curl "$api_url")
                resolved_tag=$(echo "$response" | jq -r '.tag_name // empty')
            fi
        fi

        if [[ -z "$resolved_tag" || "$resolved_tag" == "null" ]]; then
            # If tag not found, try stripping leading "v" if present
            if [[ "$version" == v* ]]; then
                tag_to_try="${version#v}"
                api_url="https://api.github.com/repos/${repo}/releases/tags/$tag_to_try"
                response=$(github_curl "$api_url")
                resolved_tag=$(echo "$response" | jq -r '.tag_name // empty')
            fi
        fi

        if [[ -z "$resolved_tag" || "$resolved_tag" == "null" ]]; then
            echo -e "${RED}Error: Version/Tag '$version' not found for GitHub repository '$repo'.${NC}" >&2
            exit 1
        fi
    fi
    echo "$resolved_tag"
}

resolve_direct_version() {
    local tool_name=$1
    local version=$2
    local latest_url
    latest_url=$(get_tool_field "$tool_name" "latest_version_url")
    local latest_jq
    latest_jq=$(get_tool_field "$tool_name" "latest_version_jq")

    if [[ "$version" == "latest" ]]; then
        if [[ -n "$latest_url" ]]; then
            local resolved=""
            if [[ -n "$latest_jq" ]]; then
                resolved=$(curl -sL "$latest_url" | jq -r "$latest_jq" | tr -d '[:space:]')
            else
                resolved=$(curl -sL "$latest_url" | tr -d '[:space:]')
            fi
            
            if [[ -z "$resolved" || "$resolved" == "null" ]]; then
                echo -e "${RED}Error: Could not resolve latest version for $tool_name from $latest_url.${NC}" >&2
                exit 1
            fi
            echo "$resolved"
        else
            echo "latest"
        fi
    else
        echo "$version"
    fi
}

replace_placeholders() {
    local pattern=$1
    local ver=$2
    local ver_no_v="${ver#v}"

    # Native Bash 4.0+ casing modifications
    local os_cap="${OS^}"
    local os_upper="${OS^^}"
    local arch_upper="${ARCH^^}"

    local result="$pattern"
    result="${result//\$\{VERSION\}/$ver}"
    result="${result//\$\{VERSION_NO_V\}/$ver_no_v}"
    result="${result//\$\{OS\}/$OS}"
    result="${result//\$\{OS_CAP\}/$os_cap}"
    result="${result//\$\{OS_UPPER\}/$os_upper}"
    result="${result//\$\{ARCH\}/$ARCH}"
    result="${result//\$\{ARCH_UPPER\}/$arch_upper}"
    result="${result//\$\{ARCH_RAW\}/$ARCH_DETECTED}" # e.g. x86_64
    result="${result//\$\{EXE_EXT\}/$EXE_EXT}"
    result="${result//\$\{ARCHIVE_EXT\}/$ARCHIVE_EXT}"
    echo "$result"
}

verify_checksum() {
    local file=$1
    local expected_hash=$2

    if [[ -z "$expected_hash" ]]; then
        return 0
    fi

    # Clean hash formatting
    expected_hash=$(echo "$expected_hash" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    local calculated_hash=""
    if command -v sha256sum &>/dev/null; then
        calculated_hash=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum &>/dev/null; then
        calculated_hash=$(shasum -a 256 "$file" | awk '{print $1}')
    elif command -v openssl &>/dev/null; then
        calculated_hash=$(openssl dgst -sha256 "$file" | awk '{print $2}')
    else
        echo -e "${YELLOW}Warning: No sha256sum, shasum, or openssl found. Skipping verification.${NC}" >&2
        return 0
    fi
    
    calculated_hash=$(echo "$calculated_hash" | tr -d '[:space:]')

    if [[ "$calculated_hash" == "$expected_hash" ]]; then
        return 0
    fi
    return 1
}

verify_gpg_signature() {
    local checksums_file=$1
    local sig_file=$2
    local key_url=$3

    if ! command -v gpg &>/dev/null; then
        echo -e "${YELLOW}Warning: 'gpg' command not found. Skipping GPG signature check.${NC}" >&2
        return 0
    fi

    echo -e "${GREEN}Verifying GPG signature of checksums file...${NC}"
    local temp_key
    temp_key=$(mktemp)
    
    if ! curl -sL -f "$key_url" -o "$temp_key"; then
        echo -e "${YELLOW}Warning: Could not fetch GPG public key from $key_url. Skipping GPG check.${NC}" >&2
        rm -f "$temp_key"
        return 0
    fi

    # Import GPG key quietly
    if ! gpg --quiet --import "$temp_key" &>/dev/null; then
        echo -e "${YELLOW}Warning: Failed to import GPG key. Skipping GPG check.${NC}" >&2
        rm -f "$temp_key"
        return 0
    fi
    rm -f "$temp_key"

    # Verify signature
    if gpg --quiet --verify "$sig_file" "$checksums_file" &>/dev/null; then
        echo -e "${GREEN}✓ GPG Signature verified successfully! (Authentic release)${NC}"
        return 0
    else
        echo -e "${RED}Security Error: GPG Signature verification failed! The checksum file is untrusted.${NC}" >&2
        return 1
    fi
}

# ==============================================================================
# ACTIVE VERSION MANAGEMENT
# ==============================================================================

set_active_version() {
    local tool_name=$1
    local version=$2
    local target_bin="$DEVMAN_DIR/versions/$tool_name/$version/$tool_name$EXE_EXT"
    local link_bin="$INSTALL_DIR/$tool_name$EXE_EXT"

    if [[ ! -f "$target_bin" ]]; then
        echo -e "${RED}Error: Version '$version' of '$tool_name' is not installed.${NC}" >&2
        log_message "Activation failed: version '$version' of '$tool_name' not found" "ERROR"
        exit 1
    fi

    # Switch symlink/binary
    rm -f "$link_bin"
    
    echo -e "${GREEN}Activating $tool_name $version...${NC}"
    
    # Try symlinking first (standard for Unix systems and git bash)
    if ln -s "$target_bin" "$link_bin" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully symlinked $tool_name $version -> $link_bin${NC}"
        log_message "Activated version '$version' of '$tool_name' (symlink)" "SUCCESS"
    else
        # Fallback: Copy the binary
        echo -e "${YELLOW}Symlink failed. Falling back to copying the binary...${NC}"
        if cp "$target_bin" "$link_bin"; then
            echo -e "${GREEN}✓ Successfully copied $tool_name $version -> $link_bin${NC}"
            log_message "Activated version '$version' of '$tool_name' (copied fallback)" "SUCCESS"
        else
            echo -e "${RED}Error: Failed to activate $tool_name. Could not link or copy to $link_bin.${NC}" >&2
            log_message "Activation failed for '$tool_name' version '$version' (copy error)" "ERROR"
            exit 1
        fi
    fi

    # Save active state
    echo "$version" > "$DEVMAN_DIR/versions/$tool_name/.active"
}

list_versions() {
    local tool_name=$1
    if ! tool_exists "$tool_name"; then
        echo -e "${RED}Error: Tool '$tool_name' not found in registry.${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Installed versions for $tool_name:${NC}"
    local active_ver=""
    local link_bin="$INSTALL_DIR/$tool_name$EXE_EXT"
    if [[ -f "$link_bin" && -f "$DEVMAN_DIR/versions/$tool_name/.active" ]]; then
        active_ver=$(cat "$DEVMAN_DIR/versions/$tool_name/.active")
    fi

    local found=0
    if [[ -d "$DEVMAN_DIR/versions/$tool_name" ]]; then
        for dir in "$DEVMAN_DIR/versions/$tool_name"/*; do
            if [[ -d "$dir" ]]; then
                found=1
                local v="${dir##*/}"
                if [[ "$v" == "$active_ver" ]]; then
                    echo -e "  ${GREEN}* $v (active)${NC}"
                else
                    echo -e "    $v"
                fi
            fi
        done
    fi

    if [[ $found -eq 0 ]]; then
        echo -e "  ${YELLOW}No versions installed.${NC}"
    fi
}

list_tools() {
    echo -e "${GREEN}Available tools in registry:${NC}"
    echo -e "--------------------------------------------------------"
    printf "%-15s %-18s %s\n" "TOOL" "STATUS" "INSTALLED VERSIONS"
    echo -e "--------------------------------------------------------"

    local tools
    tools=$(jq -r 'keys[]' "$REGISTRY_PATH")

    for tool in $tools; do
        local active_ver=""
        local link_bin="$INSTALL_DIR/$tool$EXE_EXT"
        if [[ -f "$link_bin" ]]; then
            if [[ -f "$DEVMAN_DIR/versions/$tool/.active" ]]; then
                active_ver=$(cat "$DEVMAN_DIR/versions/$tool/.active")
            fi
        fi

        # Get installed versions
        local installed_versions=()
        if [[ -d "$DEVMAN_DIR/versions/$tool" ]]; then
            for dir in "$DEVMAN_DIR/versions/$tool"/*; do
                if [[ -d "$dir" ]]; then
                    installed_versions+=("${dir##*/}")
                fi
            done
        fi

        local status_plain=""
        local status_color=""
        local versions_str=""

        if [[ -n "$active_ver" ]]; then
            status_plain="✓ $active_ver"
            status_color="${GREEN}✓ $active_ver${NC}"
        else
            if [[ ${#installed_versions[@]} -gt 0 ]]; then
                status_plain="○ unlinked"
                status_color="${YELLOW}○ unlinked${NC}"
            else
                status_plain="○ not installed"
                status_color="${NC}○ not installed${NC}"
            fi
        fi

        # Dynamic padding calculation for STATUS column
        local pad_len=$(( 18 - ${#status_plain} ))
        local padding=""
        if [[ $pad_len -gt 0 ]]; then
            padding=$(printf '%*s' "$pad_len" "")
        fi
        local status_formatted="${status_color}${padding}"

        # Format installed versions list, highlighting active version
        local formatted_versions=()
        for v in "${installed_versions[@]}"; do
            if [[ "$v" == "$active_ver" ]]; then
                formatted_versions+=("${GREEN}*${v}${NC}")
            else
                formatted_versions+=("$v")
            fi
        done

        if [[ ${#formatted_versions[@]} -gt 0 ]]; then
            # Join array with commas
            versions_str=$(IFS=,; echo "${formatted_versions[*]}")
        else
            versions_str="none"
        fi

        printf "%-15s %s %s\n" "$tool" "$status_formatted" "$versions_str"
    done
    echo -e "--------------------------------------------------------"
    echo -e "Tip: '*' indicates the active version. Run 'devman use <tool> <version>' to switch."
}

uninstall_tool() {
    local tool_name=$1
    local version=$2

    if ! tool_exists "$tool_name"; then
        echo -e "${RED}Error: Tool '$tool_name' not found in registry.${NC}" >&2
        exit 1
    fi

    local tool_dir="$DEVMAN_DIR/versions/$tool_name"
    
    if [[ -z "$version" || "$version" == "all" ]]; then
        echo -e "${YELLOW}Uninstalling all versions of $tool_name...${NC}"
        rm -rf "$tool_dir"
        rm -f "$INSTALL_DIR/$tool_name$EXE_EXT"
        echo -e "${GREEN}✓ Successfully uninstalled all versions of $tool_name.${NC}"
        log_message "Uninstalled all versions of '$tool_name'" "SUCCESS"
    else
        local target_version_dir="$tool_dir/$version"
        if [[ ! -d "$target_version_dir" ]]; then
            echo -e "${RED}Error: Version '$version' of '$tool_name' is not installed.${NC}" >&2
            exit 1
        fi

        echo -e "${YELLOW}Uninstalling $tool_name version $version...${NC}"
        rm -rf "$target_version_dir"

        local active_ver=""
        if [[ -f "$tool_dir/.active" ]]; then
            active_ver=$(cat "$tool_dir/.active")
        fi

        if [[ "$active_ver" == "$version" ]]; then
            echo -e "${YELLOW}Active version removed. Unlinking $tool_name...${NC}"
            rm -f "$INSTALL_DIR/$tool_name$EXE_EXT"
            rm -f "$tool_dir/.active"
        fi
        echo -e "${GREEN}✓ Successfully uninstalled $tool_name version $version.${NC}"
        log_message "Uninstalled version '$version' of '$tool_name'" "SUCCESS"
    fi
}

# ==============================================================================
# AUTO-SWITCHING ENVIRONMENT HOOK
# ==============================================================================

auto_switch_versions() {
    local silent=$1
    local file=""
    
    # Traverse directory tree upwards to find configuration file
    local dir="$PWD"
    while [[ -n "$dir" ]]; do
        if [[ -f "$dir/.devman-version" ]]; then
            file="$dir/.devman-version"
            break
        elif [[ -f "$dir/.tool-versions" ]]; then
            file="$dir/.tool-versions"
            break
        fi
        local parent="${dir%/*}"
        if [[ "$parent" == "$dir" ]]; then
            break
        fi
        dir="$parent"
    done

    if [[ -n "$file" && -f "$file" ]]; then
        while read -r line || [[ -n "$line" ]]; do
            # Strip carriage returns (CRLF safety)
            line="${line//$'\r'/}"
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$line" ]] && continue
            
            local tool_name
            tool_name=$(echo "$line" | awk '{print $1}')
            local version
            version=$(echo "$line" | awk '{print $2}')
            
            if [[ -n "$tool_name" && -n "$version" ]]; then
                if tool_exists "$tool_name"; then
                    local active_ver=""
                    if [[ -f "$DEVMAN_DIR/versions/$tool_name/.active" ]]; then
                        active_ver=$(cat "$DEVMAN_DIR/versions/$tool_name/.active")
                    fi
                    
                    if [[ "$active_ver" != "$version" ]]; then
                        local target_bin="$DEVMAN_DIR/versions/$tool_name/$version/$tool_name$EXE_EXT"
                        if [[ -f "$target_bin" ]]; then
                            if [[ "$silent" != "--silent" ]]; then
                                echo -e "${BLUE}[DevMan] Auto-switching $tool_name to $version (found in $file)${NC}"
                            fi
                            set_active_version "$tool_name" "$version" >/dev/null
                        else
                            if [[ "$silent" != "--silent" ]]; then
                                echo -e "${YELLOW}[DevMan] Warning: version $version of $tool_name is required by $file but not installed.${NC}" >&2
                            fi
                        fi
                    fi
                fi
            fi
        done < "$file"
    fi
}

# ==============================================================================
# REGISTRY CLI MANAGEMENT
# ==============================================================================

registry_add() {
    local name=$1
    local type=$2
    local repo_or_url=$3
    local pattern=$4
    local latest_version_url=$5

    if [[ -z "$name" || -z "$type" || -z "$repo_or_url" ]]; then
        echo -e "${RED}Usage: devman registry add <name> <github|direct> <repo_or_url> [pattern] [latest_version_url]${NC}" >&2
        exit 1
    fi

    if [[ "$type" != "github" && "$type" != "direct" ]]; then
        echo -e "${RED}Error: Type must be either 'github' or 'direct'.${NC}" >&2
        exit 1
    fi

    # Create temporary JSON payload
    local json_payload=""
    if [[ "$type" == "github" ]]; then
        json_payload=$(jq -n \
            --arg type "$type" \
            --arg repo "$repo_or_url" \
            --arg pattern "${pattern:-${name}_\${VERSION}_\${OS}_\${ARCH}.\${ARCHIVE_EXT}}" \
            '{type: $type, repo: $repo, pattern: $pattern}')
    else
        json_payload=$(jq -n \
            --arg type "$type" \
            --arg url "$repo_or_url" \
            --arg pattern "$pattern" \
            --arg latest "$latest_version_url" \
            '{type: $type, url: $url, pattern: $pattern, latest_version_url: $latest}')
    fi

    # Merge into registry
    local temp_reg
    temp_reg=$(mktemp)
    if jq --argjson entry "$json_payload" --arg key "$name" '.[$key] = $entry' "$REGISTRY_PATH" > "$temp_reg"; then
        mv "$temp_reg" "$REGISTRY_PATH"
        echo -e "${GREEN}✓ Added '$name' to registry.${NC}"
        log_message "Added tool '$name' to registry" "SUCCESS"
    else
        echo -e "${RED}Error: Failed to add tool to registry.${NC}" >&2
        rm -f "$temp_reg"
        exit 1
    fi
}

registry_remove() {
    local name=$1
    if [[ -z "$name" ]]; then
        echo -e "${RED}Usage: devman registry remove <name>${NC}" >&2
        exit 1
    fi

    if ! tool_exists "$name"; then
        echo -e "${RED}Error: Tool '$name' not found in registry.${NC}" >&2
        exit 1
    fi

    local temp_reg
    temp_reg=$(mktemp)
    if jq --arg key "$name" 'del(.[$key])' "$REGISTRY_PATH" > "$temp_reg"; then
        mv "$temp_reg" "$REGISTRY_PATH"
        echo -e "${GREEN}✓ Removed '$name' from registry.${NC}"
        log_message "Removed tool '$name' from registry" "SUCCESS"
    else
        echo -e "${RED}Error: Failed to remove tool from registry.${NC}" >&2
        rm -f "$temp_reg"
        exit 1
    fi
}

registry_sync() {
    local url=$1
    if [[ -z "$url" ]]; then
        if [[ -f "$CONFIG_DIR/config" ]]; then
            source "$CONFIG_DIR/config"
        fi
        url="${DEVMAN_REMOTE_REGISTRY}"
    fi

    if [[ -z "$url" ]]; then
        echo -e "${RED}Error: Please specify a registry URL or define DEVMAN_REMOTE_REGISTRY in $CONFIG_DIR/config.${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Syncing registry from: $url...${NC}"
    local temp_reg
    temp_reg=$(mktemp)
    if curl -sL -f "$url" -o "$temp_reg"; then
        if jq -e '.' "$temp_reg" &>/dev/null; then
            mv "$temp_reg" "$REGISTRY_PATH"
            echo -e "${GREEN}✓ Registry successfully synchronized!${NC}"
            log_message "Registry synchronized from $url" "SUCCESS"
        else
            echo -e "${RED}Error: Downloaded file is not a valid JSON document.${NC}" >&2
            rm -f "$temp_reg"
            exit 1
        fi
    else
        echo -e "${RED}Error: Failed to fetch registry from $url.${NC}" >&2
        rm -f "$temp_reg"
        exit 1
    fi
}

# ==============================================================================
# CACHE PRUNER (CLEANUP)
# ==============================================================================

prune_cache() {
    echo -e "${YELLOW}Scanning for unused tool versions...${NC}"
    local count=0
    local bytes_saved=0

    if [[ ! -d "$DEVMAN_DIR/versions" ]]; then
        echo "No installations found."
        return 0
    fi

    # Traverse tools
    for tool_dir in "$DEVMAN_DIR/versions"/*; do
        if [[ -d "$tool_dir" ]]; then
            local tool_name="${tool_dir##*/}"
            local active_ver=""
            if [[ -f "$tool_dir/.active" ]]; then
                active_ver=$(cat "$tool_dir/.active")
            fi

            # Traverse versions
            for ver_dir in "$tool_dir"/*; do
                if [[ -d "$ver_dir" ]]; then
                    local ver="${ver_dir##*/}"
                    if [[ "$ver" != "$active_ver" ]]; then
                        local size=0
                        if command -v du &>/dev/null; then
                            size=$(du -sb "$ver_dir" 2>/dev/null | awk '{print $1}' || du -sk "$ver_dir" 2>/dev/null | awk '{print $1 * 1024}')
                        fi
                        
                        echo -e "${YELLOW}Removing unused version: $tool_name $ver (${size:-?} bytes)${NC}"
                        rm -rf "$ver_dir"
                        count=$((count + 1))
                        bytes_saved=$((bytes_saved + size))
                    fi
                fi
            done
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "${GREEN}✓ Nothing to prune. Your cache is clean!${NC}"
    else
        echo -e "${GREEN}✓ Pruned $count unused version(s). Saved $((bytes_saved / 1024 / 1024)) MB.${NC}"
        log_message "Pruned $count unused versions, saving $((bytes_saved / 1024 / 1024)) MB" "SUCCESS"
    fi
}

# ==============================================================================
# AD-HOC RUNNER, UPGRADE CHECKER, AND LOCKFILE HANDLERS
# ==============================================================================

run_adhoc_tool() {
    local target=$1
    shift 1 # remove 'run' target

    if [[ "$target" != *@* ]]; then
        echo -e "${RED}Error: Run command requires <tool>@<version> syntax.${NC}" >&2
        echo "Example: devman run terraform@1.5.0 plan" >&2
        exit 1
    fi

    local tool_name="${target%%@*}"
    local version="${target#*@}"
    local target_bin="$DEVMAN_DIR/versions/$tool_name/$version/$tool_name$EXE_EXT"

    if [[ ! -f "$target_bin" ]]; then
        echo -e "${YELLOW}Version '$version' of '$tool_name' is not installed. Installing it now...${NC}"
        install_tool "$tool_name" "$version"
    fi

    # Replace current process directly with target tool execution
    exec "$target_bin" "$@"
}

check_updates() {
    echo -e "${GREEN}Checking for updates... (This might take a moment)${NC}"
    echo -e "------------------------------------------------------------------"
    printf "%-15s %-12s %-12s %-15s\n" "TOOL" "INSTALLED" "LATEST" "STATUS"
    echo -e "------------------------------------------------------------------"

    local tools
    tools=$(jq -r 'keys[]' "$REGISTRY_PATH")

    for tool in $tools; do
        local active_ver=""
        local link_bin="$INSTALL_DIR/$tool$EXE_EXT"
        if [[ -f "$link_bin" && -f "$DEVMAN_DIR/versions/$tool/.active" ]]; then
            active_ver=$(cat "$DEVMAN_DIR/versions/$tool/.active")
        fi

        if [[ -n "$active_ver" ]]; then
            local type
            type=$(get_tool_field "$tool" "type")
            local latest_ver=""
            
            set +e
            if [[ "$type" == "github" ]]; then
                local repo
                repo=$(get_tool_field "$tool" "repo")
                latest_ver=$(resolve_github_version "$repo" "latest" 2>/dev/null)
            elif [[ "$type" == "direct" ]]; then
                latest_ver=$(resolve_direct_version "$tool" "latest" 2>/dev/null)
            fi
            set -e

            if [[ -n "$latest_ver" && "$latest_ver" != "null" ]]; then
                local status_str=""
                if [[ "$active_ver" != "$latest_ver" ]]; then
                    status_str="${YELLOW}Update available${NC}"
                else
                    status_str="${GREEN}Up to date${NC}"
                fi
                printf "%-15s %-12s %-12s %b\n" "$tool" "$active_ver" "$latest_ver" "$status_str"
            else
                printf "%-15s %-12s %-12s %b\n" "$tool" "$active_ver" "unknown" "${RED}Check failed${NC}"
            fi
        fi
    done
    echo -e "------------------------------------------------------------------"
}

upgrade_tools() {
    local target_tool=$1
    
    if [[ -n "$target_tool" && "$target_tool" != "all" ]]; then
        if ! tool_exists "$target_tool"; then
            echo -e "${RED}Error: Tool '$target_tool' not found in registry.${NC}" >&2
            exit 1
        fi
        echo -e "${GREEN}Upgrading $target_tool to latest...${NC}"
        install_tool "$target_tool" "latest"
    else
        echo -e "${GREEN}Upgrading all installed tools to latest...${NC}"
        local tools
        tools=$(jq -r 'keys[]' "$REGISTRY_PATH")
        for tool in $tools; do
            local link_bin="$INSTALL_DIR/$tool$EXE_EXT"
            if [[ -f "$link_bin" ]]; then
                echo -e "\n--- Upgrading $tool ---"
                install_tool "$tool" "latest"
            fi
        done
        echo -e "\n${GREEN}Upgrade completed!${NC}"
    fi
}

export_lockfile() {
    local lock_file=${1:-devman.lock}
    echo -e "${GREEN}Exporting active tools to lockfile: $lock_file...${NC}"

    # Build JSON lock structure
    local json_out="{"
    local first=true

    local tools
    tools=$(jq -r 'keys[]' "$REGISTRY_PATH")
    for tool in $tools; do
        local active_ver=""
        local link_bin="$INSTALL_DIR/$tool$EXE_EXT"
        if [[ -f "$link_bin" && -f "$DEVMAN_DIR/versions/$tool/.active" ]]; then
            active_ver=$(cat "$DEVMAN_DIR/versions/$tool/.active")
        fi

        if [[ -n "$active_ver" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                json_out="$json_out,"
            fi
            json_out="$json_out\n  \"$tool\": \"$active_ver\""
        fi
    done
    json_out="$json_out\n}"

    echo -e "$json_out" > "$lock_file"
    echo -e "${GREEN}✓ Successfully exported lockfile to $lock_file.${NC}"
    log_message "Exported lockfile to $lock_file" "SUCCESS"
}

import_lockfile() {
    local lock_file=${1:-devman.lock}
    if [[ ! -f "$lock_file" ]]; then
        echo -e "${RED}Error: Lockfile '$lock_file' not found.${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Importing tools from lockfile: $lock_file...${NC}"
    log_message "Started importing lockfile from $lock_file" "INFO"

    if ! jq -e '.' "$lock_file" &>/dev/null; then
        echo -e "${RED}Error: Lockfile is not valid JSON.${NC}" >&2
        exit 1
    fi

    local keys
    keys=$(jq -r 'keys[]' "$lock_file")
    for tool in $keys; do
        local version
        version=$(jq -r ".\"$tool\"" "$lock_file")
        if [[ -n "$version" && "$version" != "null" ]]; then
            echo -e "\n--- Importing $tool ($version) ---"
            if tool_exists "$tool"; then
                install_tool "$tool" "$version"
            else
                echo -e "${YELLOW}Warning: Tool '$tool' specified in lockfile is not in registry. Skipping.${NC}" >&2
            fi
        fi
    done
    echo -e "\n${GREEN}✓ Successfully imported all tools from $lock_file!${NC}"
    log_message "Imported lockfile from $lock_file" "SUCCESS"
}

# ==============================================================================
# DOWNLOADER & INSTALLER LOGIC
# ==============================================================================

install_tool() {
    local tool_name=$1
    local version=${2:-latest}

    if ! tool_exists "$tool_name"; then
        echo -e "${RED}Error: Tool '$tool_name' not found in registry.${NC}" >&2
        exit 1
    fi

    log_message "Started installation of '$tool_name' (requested version: $version)" "INFO"

    local type
    type=$(get_tool_field "$tool_name" "type")

    local download_url=""
    local filename=""
    local resolved_tag=""

    echo -e "${GREEN}Resolving version for $tool_name ($version)...${NC}"

    if [[ "$type" == "github" ]]; then
        local repo
        repo=$(get_tool_field "$tool_name" "repo")
        local pattern
        pattern=$(get_tool_field "$tool_name" "pattern")
        
        resolved_tag=$(resolve_github_version "$repo" "$version")
        filename=$(replace_placeholders "$pattern" "$resolved_tag")
        download_url="https://github.com/${repo}/releases/download/${resolved_tag}/${filename}"
    elif [[ "$type" == "direct" ]]; then
        local url_pattern
        url_pattern=$(get_tool_field "$tool_name" "url")
        resolved_tag=$(resolve_direct_version "$tool_name" "$version")
        download_url=$(replace_placeholders "$url_pattern" "$resolved_tag")
        filename="${download_url##*/}"
    else
        echo -e "${RED}Error: Unknown tool type '$type' for $tool_name.${NC}" >&2
        log_message "Installation failed for '$tool_name': unknown tool type '$type'" "ERROR"
        exit 1
    fi

    echo -e "${GREEN}Downloading $tool_name ($resolved_tag)...${NC}"
    echo -e "${YELLOW}URL: $download_url${NC}"

    local temp_file
    temp_file=$(mktemp)

    if ! curl -L -f -# "$download_url" -o "$temp_file"; then
        echo -e "${RED}Error: Failed to download $tool_name from $download_url.${NC}" >&2
        log_message "Failed to download '$tool_name' from $download_url" "ERROR"
        rm -f "$temp_file"
        exit 1
    fi

    # Checksum Verification
    local checksum_pattern
    checksum_pattern=$(get_tool_field "$tool_name" "checksum_pattern")
    local checksum_url_custom
    checksum_url_custom=$(get_tool_field "$tool_name" "checksum_url")
    
    if [[ -n "$checksum_pattern" || -n "$checksum_url_custom" ]]; then
        echo -e "${GREEN}Verifying SHA256 checksum...${NC}"
        
        local checksum_url=""
        if [[ -n "$checksum_url_custom" ]]; then
            checksum_url=$(replace_placeholders "$checksum_url_custom" "$resolved_tag")
        else
            local checksum_filename
            checksum_filename=$(replace_placeholders "$checksum_pattern" "$resolved_tag")
            if [[ "$type" == "github" ]]; then
                checksum_url="https://github.com/${repo}/releases/download/${resolved_tag}/${checksum_filename}"
            else
                checksum_url="${download_url%/*}/${checksum_filename}"
            fi
        fi
        
        local temp_checksums
        temp_checksums=$(mktemp)
        
        if curl -L -f -s "$checksum_url" -o "$temp_checksums"; then
            local expected_hash=""
            if grep -q "$filename" "$temp_checksums" 2>/dev/null; then
                expected_hash=$(grep "$filename" "$temp_checksums" | head -n 1 | awk '{print $1}')
            else
                expected_hash=$(tr -d '[:space:]' < "$temp_checksums")
            fi
            
            if [[ -n "$expected_hash" ]]; then
                # SHA256 checksum check
                if verify_checksum "$temp_file" "$expected_hash"; then
                    echo -e "${GREEN}✓ Checksum verified successfully!${NC}"
                    
                    # GPG Verification if GPG details are in registry
                    local gpg_sig_pattern
                    gpg_sig_pattern=$(get_tool_field "$tool_name" "gpg_signature_pattern")
                    local gpg_key_url
                    gpg_key_url=$(get_tool_field "$tool_name" "gpg_key_url")
                    
                    if [[ -n "$gpg_sig_pattern" && -n "$gpg_key_url" ]]; then
                        local gpg_sig_filename
                        gpg_sig_filename=$(replace_placeholders "$gpg_sig_pattern" "$resolved_tag")
                        local gpg_sig_url=""
                        if [[ "$type" == "github" ]]; then
                            gpg_sig_url="https://github.com/${repo}/releases/download/${resolved_tag}/${gpg_sig_filename}"
                        else
                            gpg_sig_url="${download_url%/*}/${gpg_sig_filename}"
                        fi
                        
                        local temp_sig
                        temp_sig=$(mktemp)
                        if curl -L -f -s "$gpg_sig_url" -o "$temp_sig"; then
                            if ! verify_gpg_signature "$temp_checksums" "$temp_sig" "$gpg_key_url"; then
                                rm -f "$temp_file"
                                rm -f "$temp_checksums"
                                rm -f "$temp_sig"
                                log_message "GPG signature verification failed for $tool_name $resolved_tag" "ERROR"
                                exit 1
                            fi
                        else
                            echo -e "${YELLOW}Warning: Could not fetch GPG signature. Skipping GPG verification.${NC}" >&2
                        fi
                        rm -f "$temp_sig"
                    fi
                else
                    echo -e "${RED}Error: SHA256 Checksum mismatch for $tool_name.${NC}" >&2
                    log_message "SHA256 Checksum verification failed for $tool_name $resolved_tag" "ERROR"
                    rm -f "$temp_file"
                    rm -f "$temp_checksums"
                    exit 1
                fi
            else
                echo -e "${YELLOW}Warning: Could not extract hash from checksum file. Skipping verification.${NC}" >&2
            fi
        else
            echo -e "${YELLOW}Warning: Could not fetch checksum from $checksum_url. Skipping verification.${NC}" >&2
        fi
        rm -f "$temp_checksums"
    fi

    echo -e "${GREEN}Extracting and searching for binary...${NC}"
    local temp_extract_dir
    temp_extract_dir=$(mktemp -d)

    if [[ "$filename" == *.zip ]]; then
        if ! command -v unzip &>/dev/null; then
            echo -e "${RED}Error: 'unzip' is required to extract this tool.${NC}" >&2
            log_message "Installation failed for '$tool_name': missing 'unzip'" "ERROR"
            rm -f "$temp_file"
            rm -rf "$temp_extract_dir"
            exit 1
        fi
        unzip -q -o "$temp_file" -d "$temp_extract_dir"
    elif [[ "$filename" == *.tar.gz || "$filename" == *.tgz ]]; then
        if ! command -v tar &>/dev/null; then
            echo -e "${RED}Error: 'tar' is required to extract this tool.${NC}" >&2
            log_message "Installation failed for '$tool_name': missing 'tar'" "ERROR"
            rm -f "$temp_file"
            rm -rf "$temp_extract_dir"
            exit 1
        fi
        tar -xzf "$temp_file" -C "$temp_extract_dir"
    else
        # Raw binary
        cp "$temp_file" "$temp_extract_dir/$tool_name$EXE_EXT"
    fi

    local binary_find
    # 1. Exact match search
    binary_find=$(find "$temp_extract_dir" -type f \( -name "$tool_name" -o -name "$tool_name$EXE_EXT" \) -print -quit 2>/dev/null)
    
    # 2. Case-insensitive fuzzy search if exact match fails
    if [[ -z "$binary_find" ]]; then
        binary_find=$(find "$temp_extract_dir" -type f -iname "$tool_name*" -print -quit 2>/dev/null)
    fi

    if [[ -z "$binary_find" ]]; then
        echo -e "${RED}Error: Could not find binary matching '$tool_name' in the downloaded archive.${NC}" >&2
        log_message "Failed to locate binary '$tool_name' inside downloaded archive" "ERROR"
        rm -f "$temp_file"
        rm -rf "$temp_extract_dir"
        exit 1
    fi

    local target_dir="$DEVMAN_DIR/versions/$tool_name/$resolved_tag"
    local target_bin="$target_dir/$tool_name$EXE_EXT"
    mkdir -p "$target_dir"
    
    # Safely move binary
    mv "$binary_find" "$target_bin"
    chmod +x "$target_bin"

    # Clean up
    rm -f "$temp_file"
    rm -rf "$temp_extract_dir"

    # Activate version
    set_active_version "$tool_name" "$resolved_tag"

    # Execute Post-Install Hook if defined in registry
    local post_install_raw
    post_install_raw=$(get_tool_field "$tool_name" "post_install")
    if [[ -n "$post_install_raw" && "$post_install_raw" != "null" ]]; then
        echo -e "${GREEN}Running post-installation hook for $tool_name...${NC}"
        local post_install_script
        post_install_script=$(replace_placeholders "$post_install_raw" "$resolved_tag")
        
        # Run in a subshell
        if (eval "$post_install_script"); then
            echo -e "${GREEN}✓ Post-installation hook completed successfully.${NC}"
            log_message "Ran post-installation hook for $tool_name $resolved_tag" "SUCCESS"
        else
            echo -e "${YELLOW}Warning: Post-installation hook failed for $tool_name.${NC}" >&2
            log_message "Post-installation hook failed for $tool_name $resolved_tag" "WARNING"
        fi
    fi
}

install_all() {
    echo -e "${GREEN}Installing all registered tools (latest)...${NC}"
    local tools
    tools=$(jq -r 'keys[]' "$REGISTRY_PATH")
    for tool in $tools; do
        echo -e "\n--- Installing $tool ---"
        install_tool "$tool" "latest"
    done
    echo -e "\n${GREEN}All done!${NC}"
}

# ==============================================================================
# SAMPLE DEPLOYMENT / BOOTSTRAP LOGIC
# ==============================================================================

bootstrap_sample() {
    local type=$1
    if [[ -z "$type" ]]; then
        echo -e "${RED}Error: Please specify a sample type: terraform, kubernetes, or docker.${NC}" >&2
        echo "Usage: devman bootstrap <terraform|kubernetes|docker>" >&2
        exit 1
    fi

    # Convert to lowercase
    type=$(tr '[:upper:]' '[:lower:]' <<< "$type")

    case "$type" in
        terraform|tf)
            echo -e "${GREEN}Creating sample Terraform configuration...${NC}"
            cat << 'EOF' > main.tf
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "local_file" "hello" {
  filename = "${path.module}/hello_devman.txt"
  content  = "Hello from DevMan! Your Terraform installation is working perfectly.\nCreated at: ${timestamp()}\n"
}

output "message" {
  value = "Sample file created at ${local_file.hello.filename}"
}
EOF
            echo -e "${GREEN}✓ Created 'main.tf' in the current directory.${NC}"
            echo -e "To deploy this sample, run:"
            echo -e "  ${YELLOW}terraform init${NC}"
            echo -e "  ${YELLOW}terraform apply${NC}"
            log_message "Bootstrapped Terraform sample configuration" "SUCCESS"

            # Offer to run it if terraform is installed
            if command -v terraform &>/dev/null; then
                echo -e ""
                read -p "Would you like to run 'terraform init && terraform apply' now? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_message "Applying bootstrapped Terraform sample" "INFO"
                    terraform init && terraform apply -auto-approve
                    log_message "Applied Terraform sample" "SUCCESS"
                fi
            fi
            ;;
        kubernetes|k8s)
            echo -e "${GREEN}Creating sample Kubernetes manifest...${NC}"
            cat << 'EOF' > sample-k8s.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devman-sample-app
  labels:
    app: devman-sample
spec:
  replicas: 1
  selector:
    matchLabels:
      app: devman-sample
  template:
    metadata:
      labels:
        app: devman-sample
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: devman-sample-service
spec:
  selector:
    app: devman-sample
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF
            echo -e "${GREEN}✓ Created 'sample-k8s.yaml' in the current directory.${NC}"
            echo -e "To deploy this sample, run:"
            echo -e "  ${YELLOW}kubectl apply -f sample-k8s.yaml${NC}"
            log_message "Bootstrapped Kubernetes sample configuration" "SUCCESS"

            if command -v kubectl &>/dev/null; then
                echo -e ""
                read -p "Would you like to run 'kubectl apply -f sample-k8s.yaml' now? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_message "Applying bootstrapped Kubernetes sample" "INFO"
                    kubectl apply -f sample-k8s.yaml
                    log_message "Applied Kubernetes sample" "SUCCESS"
                fi
            fi
            ;;
        docker|compose)
            echo -e "${GREEN}Creating sample Docker Compose file...${NC}"
            cat << 'EOF' > docker-compose.yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - html_data:/usr/share/nginx/html

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

volumes:
  html_data:
EOF
            echo -e "${GREEN}✓ Created 'docker-compose.yaml' in the current directory.${NC}"
            echo -e "To deploy this sample, run:"
            echo -e "  ${YELLOW}docker compose up -d${NC}"
            log_message "Bootstrapped Docker Compose sample configuration" "SUCCESS"

            if command -v docker &>/dev/null; then
                echo -e ""
                read -p "Would you like to run 'docker compose up -d' now? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_message "Applying bootstrapped Docker Compose sample" "INFO"
                    docker compose up -d
                    log_message "Applied Docker Compose sample" "SUCCESS"
                fi
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown sample type '$type'. Supported: terraform, kubernetes, docker.${NC}" >&2
            exit 1
            ;;
    esac
}

# ==============================================================================
# DEVOPS LEARNING AUTOMATION
# ==============================================================================

LEARNING_MODULES=(
    linux
    git
    shell
    docker
    kubernetes
    terraform
    ansible
    cicd
    observability
    security
    cloud
    capstone
)

learning_usage() {
    echo "DevMan Learning Automation"
    echo "Usage: devman learn <command> [args]"
    echo ""
    echo "Commands:"
    echo "  roadmap                  Show the full DevOps learning path"
    echo "  start [module]           Start a module, or the next unfinished module"
    echo "  next                     Continue with the next unfinished module"
    echo "  complete <module>        Mark a module as complete"
    echo "  progress                 Show learning progress"
    echo "  plan [days]              Generate a day-by-day study plan"
    echo "  init [directory]         Create a full learning workspace"
    echo "  lab <module> [directory] Create a runnable practice lab"
    echo "  check [module]           Check local tool readiness"
    echo "  tools                    Show tools used across the roadmap"
    echo "  quiz [module]            Run a short interactive quiz"
    echo "  reset [--yes]            Reset saved learning progress"
    echo ""
    echo "Modules:"
    echo "  ${LEARNING_MODULES[*]}"
}

learning_module_title() {
    case "$1" in
        linux) echo "Linux and networking fundamentals" ;;
        git) echo "Git workflows and collaboration" ;;
        shell) echo "Shell scripting and automation" ;;
        docker) echo "Containers with Docker and Compose" ;;
        kubernetes) echo "Kubernetes application operations" ;;
        terraform) echo "Infrastructure as Code with Terraform" ;;
        ansible) echo "Configuration automation with Ansible" ;;
        cicd) echo "CI/CD pipelines and release automation" ;;
        observability) echo "Logs, metrics, tracing, and alerts" ;;
        security) echo "DevSecOps supply chain and runtime security" ;;
        cloud) echo "Cloud architecture and platform operations" ;;
        capstone) echo "End-to-end DevOps platform capstone" ;;
        *) echo "" ;;
    esac
}

learning_module_goal() {
    case "$1" in
        linux) echo "Navigate Linux systems, inspect processes, understand ports, permissions, DNS, and basic troubleshooting." ;;
        git) echo "Build safe branching, pull request, rollback, tagging, and release habits." ;;
        shell) echo "Automate repeatable checks with portable Bash scripts and clear exit codes." ;;
        docker) echo "Package an app into an image, run it locally, wire services with Compose, and debug containers." ;;
        kubernetes) echo "Deploy, expose, inspect, scale, and troubleshoot workloads in a local cluster." ;;
        terraform) echo "Model infrastructure declaratively, review plans, manage state, and structure reusable modules." ;;
        ansible) echo "Write idempotent playbooks, manage inventories, template files, and apply configuration safely." ;;
        cicd) echo "Create pipelines that test, scan, build, package, and publish changes with repeatable gates." ;;
        observability) echo "Collect useful signals, query them, and connect alerts to action-oriented runbooks." ;;
        security) echo "Add security checks to images, IaC, dependencies, secrets, and cluster policy." ;;
        cloud) echo "Map DevOps practices to cloud networking, identity, compute, storage, and managed platforms." ;;
        capstone) echo "Combine tools into a portfolio-grade workflow from source code to monitored deployment." ;;
        *) echo "" ;;
    esac
}

learning_module_tools() {
    case "$1" in
        linux) echo "bash curl jq" ;;
        git) echo "git" ;;
        shell) echo "bash curl jq" ;;
        docker) echo "docker docker-compose" ;;
        kubernetes) echo "kubectl minikube helm k9s yq" ;;
        terraform) echo "terraform tflint yq jq" ;;
        ansible) echo "ansible" ;;
        cicd) echo "git docker" ;;
        observability) echo "docker docker-compose kubectl stern" ;;
        security) echo "docker kubectl terraform tflint" ;;
        cloud) echo "terraform kubectl helm" ;;
        capstone) echo "git docker docker-compose kubectl minikube helm terraform yq jq" ;;
        *) echo "" ;;
    esac
}

learning_module_challenge() {
    case "$1" in
        linux) echo "Use ps, ss/netstat, dig/nslookup, chmod, system logs, and curl to explain why a service is or is not reachable." ;;
        git) echo "Create a feature branch, rebase or merge it cleanly, tag a release, and demonstrate a rollback path." ;;
        shell) echo "Write a health-check script that validates tools, ports, files, and JSON output with useful failures." ;;
        docker) echo "Build a small web image, run it with Compose, inspect logs, exec into it, and rebuild after a change." ;;
        kubernetes) echo "Deploy an app, expose it, scale it, inspect events, roll out a change, and roll it back." ;;
        terraform) echo "Create local infrastructure, run fmt/validate/plan/apply, inspect state, and destroy safely." ;;
        ansible) echo "Apply a playbook to localhost, prove idempotency, and template a config file from variables." ;;
        cicd) echo "Create a pipeline that runs lint, tests, image build, IaC validation, and artifact publishing steps." ;;
        observability) echo "Collect metrics and logs for a sample app, build a minimal dashboard query, and write an alert runbook." ;;
        security) echo "Find and fix one insecure Dockerfile pattern, one IaC issue, and one secret-handling problem." ;;
        cloud) echo "Design a small cloud landing zone with network, identity, compute, storage, and operational guardrails." ;;
        capstone) echo "Ship a complete sample service with CI, image build, IaC, Kubernetes deployment, and observability notes." ;;
        *) echo "" ;;
    esac
}

learning_module_valid() {
    local module=$1
    local known
    for known in "${LEARNING_MODULES[@]}"; do
        if [[ "$known" == "$module" ]]; then
            return 0
        fi
    done
    return 1
}

learning_ensure_progress() {
    check_jq_prereq

    if [[ ! -f "$LEARNING_PROGRESS_FILE" ]]; then
        local now
        now=$(date '+%Y-%m-%d %H:%M:%S')
        mkdir -p "$(dirname "$LEARNING_PROGRESS_FILE")"
        cat << EOF > "$LEARNING_PROGRESS_FILE"
{
  "started_at": "$now",
  "current": "",
  "completed": [],
  "completed_at": {},
  "lab_root": ""
}
EOF
    fi
}

learning_is_completed() {
    local module=$1
    [[ -f "$LEARNING_PROGRESS_FILE" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    jq -e --arg module "$module" '(.completed // []) | index($module)' "$LEARNING_PROGRESS_FILE" >/dev/null 2>&1
}

learning_next_module() {
    local module
    for module in "${LEARNING_MODULES[@]}"; do
        if ! learning_is_completed "$module"; then
            echo "$module"
            return 0
        fi
    done
    echo ""
}

learning_roadmap() {
    local tracking_enabled=0
    if command -v jq >/dev/null 2>&1; then
        learning_ensure_progress
        tracking_enabled=1
    fi

    echo -e "${GREEN}DevOps learning roadmap${NC}"
    if [[ "$tracking_enabled" -eq 1 ]]; then
        echo "Progress file: $LEARNING_PROGRESS_FILE"
    else
        echo -e "${YELLOW}Progress tracking disabled until jq is installed.${NC}"
    fi
    echo "--------------------------------------------------------------------------------"
    printf "%-3s %-15s %-10s %s\n" "#" "MODULE" "STATUS" "GOAL"
    echo "--------------------------------------------------------------------------------"

    local idx=1
    local module
    for module in "${LEARNING_MODULES[@]}"; do
        local status="todo"
        if [[ "$tracking_enabled" -eq 0 ]]; then
            status="unknown"
        elif learning_is_completed "$module"; then
            status="done"
        fi
        printf "%-3s %-15s %-10s %s\n" "$idx" "$module" "$status" "$(learning_module_title "$module")"
        idx=$((idx + 1))
    done
    echo "--------------------------------------------------------------------------------"
    echo "Run: devman learn start        # begin the next unfinished module"
    echo "Run: devman learn lab docker   # create a focused practice lab"
}

learning_progress() {
    learning_ensure_progress
    local completed_count
    completed_count=$(jq -r '(.completed // []) | length' "$LEARNING_PROGRESS_FILE")
    local total=${#LEARNING_MODULES[@]}
    local current
    current=$(jq -r '.current // ""' "$LEARNING_PROGRESS_FILE")
    local next
    next=$(learning_next_module)

    echo -e "${GREEN}Learning progress${NC}"
    echo "Completed: $completed_count / $total"
    if [[ -n "$current" ]]; then
        echo "Current:   $current - $(learning_module_title "$current")"
    else
        echo "Current:   none"
    fi
    if [[ -n "$next" ]]; then
        echo "Next:      $next - $(learning_module_title "$next")"
    else
        echo "Next:      all modules complete"
    fi
    echo ""
    echo "Completed modules:"
    if [[ "$completed_count" -eq 0 ]]; then
        echo "  none yet"
    else
        jq -r '.completed[] | "  " + .' "$LEARNING_PROGRESS_FILE"
    fi
}

learning_start() {
    local module=${1:-}
    learning_ensure_progress

    if [[ -z "$module" || "$module" == "next" ]]; then
        module=$(learning_next_module)
    fi

    if [[ -z "$module" ]]; then
        echo -e "${GREEN}All learning modules are complete. Time for the capstone polish pass.${NC}"
        return 0
    fi

    if ! learning_module_valid "$module"; then
        echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
        learning_usage
        exit 1
    fi

    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    local temp_file
    temp_file=$(mktemp)
    jq --arg module "$module" --arg ts "$now" \
        '.current = $module | .last_started_at = $ts' \
        "$LEARNING_PROGRESS_FILE" > "$temp_file"
    mv "$temp_file" "$LEARNING_PROGRESS_FILE"

    echo -e "${GREEN}Starting: $module - $(learning_module_title "$module")${NC}"
    echo ""
    echo "Goal:"
    echo "  $(learning_module_goal "$module")"
    echo ""
    echo "Practice challenge:"
    echo "  $(learning_module_challenge "$module")"
    echo ""
    echo "Recommended tools:"
    echo "  $(learning_module_tools "$module")"
    echo ""
    echo "Suggested next commands:"
    echo "  devman learn check $module"
    echo "  devman learn lab $module"
    echo "  devman learn quiz $module"
    echo "  devman learn complete $module"
}

learning_complete() {
    local module=$1
    if [[ -z "$module" ]]; then
        echo -e "${RED}Usage: devman learn complete <module>${NC}" >&2
        exit 1
    fi
    if ! learning_module_valid "$module"; then
        echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
        exit 1
    fi

    learning_ensure_progress
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    local temp_file
    temp_file=$(mktemp)
    jq --arg module "$module" --arg ts "$now" \
        '.completed = (((.completed // []) + [$module]) | unique)
         | .completed_at = ((.completed_at // {}) + {($module): $ts})
         | if .current == $module then .current = "" else . end' \
        "$LEARNING_PROGRESS_FILE" > "$temp_file"
    mv "$temp_file" "$LEARNING_PROGRESS_FILE"

    echo -e "${GREEN}Marked '$module' complete.${NC}"
    log_message "Learning module completed: $module" "SUCCESS"
    local next
    next=$(learning_next_module)
    if [[ -n "$next" ]]; then
        echo "Next module: $next - $(learning_module_title "$next")"
    else
        echo "All modules complete. Nice work."
    fi
}

learning_reset() {
    local force=${1:-}
    if [[ "$force" != "--yes" ]]; then
        read -p "Reset DevMan learning progress? This only removes $LEARNING_PROGRESS_FILE. (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Reset cancelled."
            return 0
        fi
    fi

    rm -f "$LEARNING_PROGRESS_FILE"
    echo -e "${GREEN}Learning progress reset.${NC}"
    log_message "Learning progress reset" "SUCCESS"
}

learning_plan() {
    local days=${1:-30}
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 1 ]]; then
        echo -e "${RED}Usage: devman learn plan [positive_days]${NC}" >&2
        exit 1
    fi

    local total=${#LEARNING_MODULES[@]}
    local module

    echo -e "${GREEN}$days-day DevOps learning plan${NC}"
    echo "--------------------------------------------------------------------------------"
    printf "%-12s %-28s %s\n" "DAYS" "MODULE" "FOCUS"
    echo "--------------------------------------------------------------------------------"

    if [[ "$days" -lt "$total" ]]; then
        local module_index=0
        local day
        for ((day = 1; day <= days; day++)); do
            local remaining_modules=$((total - module_index))
            local remaining_days=$((days - day + 1))
            local group_size=$(( (remaining_modules + remaining_days - 1) / remaining_days ))
            local group=""
            local focus=""
            local i

            for ((i = 0; i < group_size && module_index < total; i++)); do
                module="${LEARNING_MODULES[module_index]}"
                if [[ -z "$group" ]]; then
                    group="$module"
                    focus="$(learning_module_title "$module")"
                else
                    group="$group,$module"
                    focus="$focus; $(learning_module_title "$module")"
                fi
                module_index=$((module_index + 1))
            done
            printf "%-12s %-28s %s\n" "$day" "$group" "$focus"
        done
    else
        local span=$(( (days + total - 1) / total ))
        local start_day=1
        local idx=1
        for module in "${LEARNING_MODULES[@]}"; do
            local end_day=$((start_day + span - 1))
            if [[ "$end_day" -gt "$days" || "$idx" -eq "$total" ]]; then
                end_day=$days
            fi
            printf "%-12s %-28s %s\n" "$start_day-$end_day" "$module" "$(learning_module_title "$module")"
            start_day=$((end_day + 1))
            idx=$((idx + 1))
            if [[ "$start_day" -gt "$days" ]]; then
                break
            fi
        done
    fi
    echo "--------------------------------------------------------------------------------"
    echo "Daily rhythm: read 20m, build 60m, troubleshoot 20m, write notes 10m."
    echo "Weekly rhythm: redo one lab from memory and explain it in your notes."
}

learning_write_file_allowed() {
    local file=$1
    mkdir -p "$(dirname "$file")"
    if [[ -e "$file" ]]; then
        echo -e "${YELLOW}Keeping existing file: $file${NC}"
        return 1
    fi
    return 0
}

learning_init_workspace() {
    local root=${1:-devops-learning-lab}
    mkdir -p "$root/labs" "$root/notes" "$root/scripts"

    local module
    for module in "${LEARNING_MODULES[@]}"; do
        mkdir -p "$root/labs/$module"
    done

    if learning_write_file_allowed "$root/README.md"; then
        cat << 'LABEOF' > "$root/README.md"
# DevOps Learning Lab

This workspace was generated by DevMan.

## Flow

1. Run `devman learn roadmap`.
2. Run `devman learn start`.
3. Generate the current module lab with `devman learn lab <module> labs/<module>`.
4. Capture notes in `notes/`.
5. Run `devman learn quiz <module>`.
6. Mark completion with `devman learn complete <module>`.

## Portfolio rule

Every module should leave behind a small artifact: a script, manifest, pipeline,
runbook, diagram, or README explaining what you built and how you debugged it.
LABEOF
    fi

    if learning_write_file_allowed "$root/notes/learning-journal.md"; then
        cat << 'LABEOF' > "$root/notes/learning-journal.md"
# Learning Journal

## Today

- Module:
- What I built:
- What failed:
- How I fixed it:
- Command I want to remember:
- Next improvement:
LABEOF
    fi

    if learning_write_file_allowed "$root/Makefile"; then
        cat << 'LABEOF' > "$root/Makefile"
.PHONY: roadmap progress check next

roadmap:
	devman learn roadmap

progress:
	devman learn progress

check:
	devman learn check

next:
	devman learn start
LABEOF
    fi

    if command -v jq >/dev/null 2>&1; then
        learning_ensure_progress
        local temp_file
        temp_file=$(mktemp)
        jq --arg root "$root" '.lab_root = $root' "$LEARNING_PROGRESS_FILE" > "$temp_file"
        mv "$temp_file" "$LEARNING_PROGRESS_FILE"
    else
        echo -e "${YELLOW}Progress file not updated because jq is not installed.${NC}"
    fi

    echo -e "${GREEN}Created DevOps learning workspace at: $root${NC}"
    echo "Next: cd $root && devman learn start"
    log_message "Initialized learning workspace at $root" "SUCCESS"
}

learning_create_lab() {
    local module=$1
    local lab_dir=${2:-}

    if [[ -z "$module" ]]; then
        echo -e "${RED}Usage: devman learn lab <module> [directory]${NC}" >&2
        exit 1
    fi
    if ! learning_module_valid "$module"; then
        echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
        exit 1
    fi

    if [[ -z "$lab_dir" ]]; then
        lab_dir="devman-lab-$module"
    fi
    mkdir -p "$lab_dir"

    case "$module" in
        linux)
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# Linux and Networking Lab

## Tasks

- Print OS, kernel, current shell, disk usage, and memory usage.
- Find the process using a port.
- Resolve a domain name and curl a health endpoint.
- Create a file, change permissions, and explain the permission bits.
- Write a short troubleshooting note for a failed service.

## Useful commands

`uname -a`, `df -h`, `free -m`, `ps aux`, `ss -tulpn`, `curl -I`, `chmod`, `journalctl`
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/system-check.sh"; then
                cat << 'LABEOF' > "$lab_dir/system-check.sh"
#!/usr/bin/env bash
set -euo pipefail

echo "OS: $(uname -s)"
echo "Kernel: $(uname -r)"
echo "Shell: ${SHELL:-unknown}"
echo "Disk:"
df -h .
echo "Network:"
curl -I -L --max-time 10 https://example.com
LABEOF
                chmod +x "$lab_dir/system-check.sh"
            fi
            ;;
        git)
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# Git Workflow Lab

## Tasks

- Initialize a repository.
- Create a feature branch and make two commits.
- Rebase or merge back to the main branch.
- Create an annotated tag.
- Practice a safe rollback with `git revert`.

## Evidence to capture

- `git log --oneline --graph --decorate --all`
- A short note explaining merge vs rebase.
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/.gitignore"; then
                cat << 'LABEOF' > "$lab_dir/.gitignore"
.env
*.log
tmp/
LABEOF
            fi
            ;;
        shell)
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# Shell Automation Lab

## Tasks

- Validate that required commands exist.
- Parse JSON with jq.
- Return non-zero when a check fails.
- Log useful status messages.
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/devops-health.sh"; then
                cat << 'LABEOF' > "$lab_dir/devops-health.sh"
#!/usr/bin/env bash
set -euo pipefail

required=(git curl jq)
missing=0

for cmd in "${required[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "ok: $cmd"
    else
        echo "missing: $cmd" >&2
        missing=1
    fi
done

echo '{"status":"ok","source":"devman"}' | jq -r '.status'
exit "$missing"
LABEOF
                chmod +x "$lab_dir/devops-health.sh"
            fi
            ;;
        docker)
            mkdir -p "$lab_dir/app"
            if learning_write_file_allowed "$lab_dir/app/index.html"; then
                cat << 'LABEOF' > "$lab_dir/app/index.html"
<h1>Hello from the DevMan Docker lab</h1>
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/Dockerfile"; then
                cat << 'LABEOF' > "$lab_dir/Dockerfile"
FROM nginx:alpine
COPY app/ /usr/share/nginx/html/
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost/ || exit 1
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/compose.yaml"; then
                cat << 'LABEOF' > "$lab_dir/compose.yaml"
services:
  web:
    build: .
    ports:
      - "8080:80"
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# Docker Lab

Run:

```bash
docker build -t devman-web:learn .
docker run --rm -p 8080:80 devman-web:learn
docker compose up --build
```

Practice: inspect logs, exec into the container, rebuild after changing `app/index.html`.
LABEOF
            fi
            ;;
        kubernetes)
            mkdir -p "$lab_dir/k8s"
            if learning_write_file_allowed "$lab_dir/k8s/deployment.yaml"; then
                cat << 'LABEOF' > "$lab_dir/k8s/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devman-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: devman-web
  template:
    metadata:
      labels:
        app: devman-web
    spec:
      containers:
        - name: web
          image: nginx:alpine
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/k8s/service.yaml"; then
                cat << 'LABEOF' > "$lab_dir/k8s/service.yaml"
apiVersion: v1
kind: Service
metadata:
  name: devman-web
spec:
  selector:
    app: devman-web
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# Kubernetes Lab

Run:

```bash
minikube start
kubectl apply -f k8s/
kubectl get deploy,svc,pods
kubectl rollout restart deployment/devman-web
kubectl rollout status deployment/devman-web
kubectl port-forward service/devman-web 8080:80
```

Practice: scale replicas, inspect events, break the image tag, and recover.
LABEOF
            fi
            ;;
        terraform)
            if learning_write_file_allowed "$lab_dir/main.tf"; then
                cat << 'LABEOF' > "$lab_dir/main.tf"
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

variable "environment" {
  type    = string
  default = "learning"
}

resource "local_file" "runbook" {
  filename = "${path.module}/runbook-${var.environment}.md"
  content  = "# ${var.environment} runbook\n\nGenerated by Terraform.\n"
}

output "runbook_path" {
  value = local_file.runbook.filename
}
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# Terraform Lab

Run:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform state list
terraform destroy
```

Practice: change the variable, review the plan, apply, and inspect state.
LABEOF
            fi
            ;;
        ansible)
            if learning_write_file_allowed "$lab_dir/inventory.ini"; then
                cat << 'LABEOF' > "$lab_dir/inventory.ini"
[local]
localhost ansible_connection=local
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/playbook.yml"; then
                cat << 'LABEOF' > "$lab_dir/playbook.yml"
---
- name: DevMan Ansible learning lab
  hosts: local
  gather_facts: true
  vars:
    lab_message: "Configured by Ansible"
  tasks:
    - name: Write a local config artifact
      copy:
        dest: ./ansible-lab-output.txt
        content: "{{ lab_message }} on {{ ansible_date_time.date }}\n"
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# Ansible Lab

Run:

```bash
ansible-playbook -i inventory.ini playbook.yml
ansible-playbook -i inventory.ini playbook.yml
```

Practice: prove the second run is idempotent and add a templated file.
LABEOF
            fi
            ;;
        cicd)
            mkdir -p "$lab_dir/.github/workflows"
            if learning_write_file_allowed "$lab_dir/.github/workflows/devops-ci.yml"; then
                cat << 'LABEOF' > "$lab_dir/.github/workflows/devops-ci.yml"
name: DevOps CI

on:
  push:
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Shell syntax check
        run: |
          find . -name "*.sh" -print0 | xargs -0 -r bash -n
      - name: Dockerfile lint placeholder
        run: |
          test -f Dockerfile && echo "Add hadolint here" || echo "No Dockerfile yet"
      - name: Terraform validation placeholder
        run: |
          test -f main.tf && echo "Add terraform init/validate here" || echo "No Terraform yet"
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# CI/CD Lab

Tasks:

- Add unit/lint/test stages for your project.
- Add Docker image build steps.
- Add Terraform validation.
- Add branch protection notes.
- Explain what must pass before deployment.
LABEOF
            fi
            ;;
        observability)
            if learning_write_file_allowed "$lab_dir/prometheus.yml"; then
                cat << 'LABEOF' > "$lab_dir/prometheus.yml"
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["prometheus:9090"]
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/compose.yaml"; then
                cat << 'LABEOF' > "$lab_dir/compose.yaml"
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/runbook.md"; then
                cat << 'LABEOF' > "$lab_dir/runbook.md"
# Alert Runbook Template

## Symptom

## User impact

## First checks

## Likely causes

## Recovery steps

## Prevention
LABEOF
            fi
            ;;
        security)
            if learning_write_file_allowed "$lab_dir/Dockerfile.insecure"; then
                cat << 'LABEOF' > "$lab_dir/Dockerfile.insecure"
FROM ubuntu:latest
USER root
COPY . /app
RUN chmod -R 777 /app
CMD ["bash"]
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/security-review.md"; then
                cat << 'LABEOF' > "$lab_dir/security-review.md"
# Security Review

Find and fix:

- Floating base image tag.
- Root runtime user.
- Over-broad permissions.
- Missing dependency scan.
- Missing secret handling rules.

Write the corrected Dockerfile and explain each change.
LABEOF
            fi
            ;;
        cloud)
            if learning_write_file_allowed "$lab_dir/cloud-design.md"; then
                cat << 'LABEOF' > "$lab_dir/cloud-design.md"
# Cloud DevOps Design Lab

Design a small production-like environment.

## Include

- Network boundaries and subnets.
- Identity and access model.
- Compute/runtime choice.
- Storage and backup strategy.
- Deployment path.
- Monitoring and incident response.
- Cost controls.

Keep it cloud-agnostic first, then map it to AWS, Azure, or GCP.
LABEOF
            fi
            ;;
        capstone)
            mkdir -p "$lab_dir/app" "$lab_dir/k8s" "$lab_dir/.github/workflows" "$lab_dir/docs"
            if learning_write_file_allowed "$lab_dir/app/index.html"; then
                cat << 'LABEOF' > "$lab_dir/app/index.html"
<h1>DevMan Capstone Service</h1>
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/Dockerfile"; then
                cat << 'LABEOF' > "$lab_dir/Dockerfile"
FROM nginx:alpine
COPY app/ /usr/share/nginx/html/
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/k8s/deployment.yaml"; then
                cat << 'LABEOF' > "$lab_dir/k8s/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: capstone-web
  template:
    metadata:
      labels:
        app: capstone-web
    spec:
      containers:
        - name: web
          image: capstone-web:local
          imagePullPolicy: Never
          ports:
            - containerPort: 80
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/docs/runbook.md"; then
                cat << 'LABEOF' > "$lab_dir/docs/runbook.md"
# Capstone Runbook

## Deploy

## Verify

## Roll back

## Troubleshoot

## Improve
LABEOF
            fi
            if learning_write_file_allowed "$lab_dir/README.md"; then
                cat << 'LABEOF' > "$lab_dir/README.md"
# DevOps Capstone

Build the image, run it locally, deploy it to Kubernetes, add CI validation,
write a runbook, and document the architecture.
LABEOF
            fi
            ;;
    esac

    echo -e "${GREEN}Created $module lab at: $lab_dir${NC}"
    echo "Open the README or generated files there, then run: devman learn start $module"
    log_message "Created learning lab '$module' at $lab_dir" "SUCCESS"
}

learning_check() {
    local module=${1:-all}
    local tools=""

    if [[ "$module" == "all" ]]; then
        local seen=" "
        local known
        for known in "${LEARNING_MODULES[@]}"; do
            local cmd
            for cmd in $(learning_module_tools "$known"); do
                if [[ "$seen" != *" $cmd "* ]]; then
                    seen="$seen$cmd "
                    tools="$tools $cmd"
                fi
            done
        done
    else
        if ! learning_module_valid "$module"; then
            echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
            exit 1
        fi
        tools=$(learning_module_tools "$module")
    fi

    echo -e "${GREEN}Tool readiness check: $module${NC}"
    echo "------------------------------------------------------------"
    printf "%-18s %-12s %s\n" "TOOL" "STATUS" "NEXT STEP"
    echo "------------------------------------------------------------"

    local missing=0
    local cmd
    for cmd in $tools; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "%-18s %-12s %s\n" "$cmd" "ok" "$(command -v "$cmd")"
        else
            missing=$((missing + 1))
            local hint="install externally"
            if command -v jq >/dev/null 2>&1 && tool_exists "$cmd"; then
                hint="devman install $cmd latest"
            fi
            printf "%-18s %-12s %s\n" "$cmd" "missing" "$hint"
        fi
    done
    echo "------------------------------------------------------------"
    if [[ "$missing" -eq 0 ]]; then
        echo -e "${GREEN}All checked tools are available.${NC}"
    else
        echo -e "${YELLOW}$missing tool(s) missing. Install only what you need for the current module.${NC}"
    fi
}

learning_tools() {
    echo -e "${GREEN}DevOps learning tool map${NC}"
    echo "--------------------------------------------------------------------------------"
    printf "%-15s %s\n" "MODULE" "TOOLS"
    echo "--------------------------------------------------------------------------------"
    local module
    for module in "${LEARNING_MODULES[@]}"; do
        printf "%-15s %s\n" "$module" "$(learning_module_tools "$module")"
    done
    echo "--------------------------------------------------------------------------------"
    echo "DevMan can install registry tools with: devman install <tool> latest"
    echo "External tools such as git, docker, ansible, and cloud CLIs may need OS-specific setup."
}

learning_quiz() {
    local module=${1:-}
    if [[ -z "$module" ]]; then
        module=$(learning_next_module)
    fi
    if [[ -z "$module" ]]; then
        module="capstone"
    fi
    if ! learning_module_valid "$module"; then
        echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
        exit 1
    fi

    local q1 q2 q3 a1 a2 a3
    case "$module" in
        linux)
            q1="Which command is best for checking listening TCP ports? a) chmod b) ss c) mkdir"; a1="b"
            q2="What does exit code 0 usually mean? a) success b) warning c) failure"; a2="a"
            q3="Which record type maps a name to an IPv4 address? a) MX b) A c) TXT"; a3="b"
            ;;
        git)
            q1="Which command creates an annotated release marker? a) git tag -a b) git stash c) git fetch"; a1="a"
            q2="Which command safely undoes a committed change by adding a new commit? a) git revert b) git reset --hard c) git clean"; a2="a"
            q3="What is a pull request mainly for? a) code review and merge discussion b) deleting branches c) installing packages"; a3="a"
            ;;
        shell)
            q1="What does 'set -euo pipefail' improve? a) script safety b) color output c) network speed"; a1="a"
            q2="Which tool is best for JSON parsing in shell scripts? a) jq b) tar c) ssh-keygen"; a2="a"
            q3="Where should error messages usually go? a) stderr b) /dev/null always c) only README files"; a3="a"
            ;;
        docker)
            q1="Which file usually defines image build steps? a) Dockerfile b) deployment.yaml c) main.tf"; a1="a"
            q2="What does a container image contain? a) packaged filesystem and metadata b) only source code c) only logs"; a2="a"
            q3="Which command shows container logs? a) docker logs b) git log c) terraform show"; a3="a"
            ;;
        kubernetes)
            q1="Which object keeps pods running at a desired replica count? a) Deployment b) Secret c) Namespace"; a1="a"
            q2="Which command shows recent cluster scheduling issues? a) kubectl get events b) docker build c) git tag"; a2="a"
            q3="Which Service type is commonly used for internal-only access? a) ClusterIP b) NodeName c) Dockerfile"; a3="a"
            ;;
        terraform)
            q1="Which command previews infrastructure changes? a) terraform plan b) terraform fmt c) terraform output"; a1="a"
            q2="What does Terraform state track? a) managed resource mappings b) shell aliases c) Git branches"; a2="a"
            q3="Which file commonly stores reusable input definitions? a) variables.tf b) Dockerfile c) inventory.ini"; a3="a"
            ;;
        ansible)
            q1="What does idempotent mean? a) repeated runs converge safely b) every run must fail once c) no variables allowed"; a1="a"
            q2="Which file lists target hosts? a) inventory b) Dockerfile c) state file"; a2="a"
            q3="Which format are playbooks usually written in? a) YAML b) PNG c) ZIP"; a3="a"
            ;;
        cicd)
            q1="What is a pipeline gate? a) required check before promotion b) a Kubernetes pod c) a shell prompt"; a1="a"
            q2="Which event often triggers CI? a) push or pull request b) disk mount c) DNS lookup"; a2="a"
            q3="What should a deployment pipeline be? a) repeatable and auditable b) manual only c) hidden from logs"; a3="a"
            ;;
        observability)
            q1="What are the three common signals? a) logs metrics traces b) tags branches commits c) images layers ports"; a1="a"
            q2="What should an alert include? a) action and impact b) only a vague title c) no owner"; a2="a"
            q3="What is a runbook for? a) repeatable incident response b) package installation only c) hiding errors"; a3="a"
            ;;
        security)
            q1="Why avoid running containers as root? a) reduces blast radius b) makes images larger c) disables logs"; a1="a"
            q2="Where should secrets not be committed? a) source control b) a secret manager c) environment-specific vault"; a2="a"
            q3="What is supply chain scanning for? a) dependency and image risk b) changing DNS records c) creating branches"; a3="a"
            ;;
        cloud)
            q1="What is least privilege? a) only needed access b) admin for everyone c) public buckets by default"; a1="a"
            q2="What should be tagged for cost control? a) cloud resources b) shell variables only c) Git commits only"; a2="a"
            q3="What belongs in a landing zone? a) network identity guardrails b) laptop wallpaper c) only app code"; a3="a"
            ;;
        capstone)
            q1="What makes a capstone strong? a) integrated working workflow b) screenshots only c) no README"; a1="a"
            q2="What should rollback notes describe? a) how to return to a known good version b) how to delete history c) how to ignore alerts"; a2="a"
            q3="What should the portfolio README explain? a) architecture, commands, tradeoffs b) private secrets c) unrelated tasks"; a3="a"
            ;;
    esac

    echo -e "${GREEN}Quiz: $module - $(learning_module_title "$module")${NC}"
    local score=0
    local answer

    echo "1) $q1"
    if ! read -r -p "Answer: " answer; then answer=""; fi
    if [[ "${answer,,}" == "$a1" ]]; then score=$((score + 1)); fi

    echo "2) $q2"
    if ! read -r -p "Answer: " answer; then answer=""; fi
    if [[ "${answer,,}" == "$a2" ]]; then score=$((score + 1)); fi

    echo "3) $q3"
    if ! read -r -p "Answer: " answer; then answer=""; fi
    if [[ "${answer,,}" == "$a3" ]]; then score=$((score + 1)); fi

    echo "Score: $score / 3"
    if [[ "$score" -eq 3 ]]; then
        echo -e "${GREEN}Passed. You can mark it complete with: devman learn complete $module${NC}"
    else
        echo -e "${YELLOW}Review the module goal and redo the lab before marking it complete.${NC}"
        echo "Answer key: 1=$a1 2=$a2 3=$a3"
    fi
}

learning_dispatch() {
    local command=${1:-help}
    shift || true

    case "$command" in
        roadmap|list)
            learning_roadmap
            ;;
        start)
            learning_start "${1:-}"
            ;;
        next)
            learning_start "next"
            ;;
        complete|done)
            learning_complete "${1:-}"
            ;;
        progress|status)
            learning_progress
            ;;
        plan)
            learning_plan "${1:-30}"
            ;;
        init)
            learning_init_workspace "${1:-devops-learning-lab}"
            ;;
        lab|scaffold)
            learning_create_lab "${1:-}" "${2:-}"
            ;;
        check|doctor)
            learning_check "${1:-all}"
            ;;
        tools)
            learning_tools
            ;;
        quiz)
            learning_quiz "${1:-}"
            ;;
        reset)
            learning_reset "${1:-}"
            ;;
        help|-h|--help)
            learning_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown learn command '$command'.${NC}" >&2
            learning_usage
            exit 1
            ;;
    esac
}

# ==============================================================================
# KEYBOARD-DRIVEN TUI DASHBOARD
# ==============================================================================

tui_show_cursor() {
    tput cnorm 2>/dev/null || echo -ne "\033[?25h"
}

tui_hide_cursor() {
    tput civis 2>/dev/null || echo -ne "\033[?25l"
}

tui_restore_terminal() {
    tui_show_cursor
}

tui_pause() {
    echo ""
    echo -n "Press any key to continue..."
    local _
    IFS= read -rsn1 _ || true
    echo ""
}

tui_header() {
    local title=$1
    local subtitle=${2:-}

    clear
    echo -e "${GREEN}============================================================${NC}"
    printf "%b%*s%b\n" "${GREEN}" $(( (${#title} + 60) / 2 )) "$title" "${NC}"
    echo -e "${GREEN}============================================================${NC}"
    if [[ -n "$subtitle" ]]; then
        echo "$subtitle"
        echo "------------------------------------------------------------"
    fi
}

tui_read_key() {
    local key=""
    local key2=""
    TUI_KEY=""

    if ! IFS= read -rsn1 key; then
        TUI_KEY="quit"
        return 0
    fi

    if [[ "$key" == $'\e' ]]; then
        IFS= read -rsn2 -t 0.1 key2 || true
        case "$key2" in
            "[A") TUI_KEY="up" ;;
            "[B") TUI_KEY="down" ;;
            *) TUI_KEY="escape" ;;
        esac
    elif [[ -z "$key" || "$key" == $'\r' || "$key" == $'\n' ]]; then
        TUI_KEY="enter"
    else
        TUI_KEY="$key"
    fi
}

tui_tool_status() {
    local tool=$1
    local active_ver=""
    local installed_count=0
    local type=""
    local dir

    type=$(get_tool_field "$tool" "type")
    if [[ -f "$DEVMAN_DIR/versions/$tool/.active" ]]; then
        active_ver=$(cat "$DEVMAN_DIR/versions/$tool/.active")
    fi

    if [[ -d "$DEVMAN_DIR/versions/$tool" ]]; then
        for dir in "$DEVMAN_DIR/versions/$tool"/*; do
            [[ -d "$dir" ]] && installed_count=$((installed_count + 1))
        done
    fi

    if [[ -n "$active_ver" ]]; then
        echo "active: $active_ver | installed: $installed_count | source: ${type:-unknown}"
    elif [[ "$installed_count" -gt 0 ]]; then
        echo "installed: $installed_count | not linked | source: ${type:-unknown}"
    else
        echo "not installed | source: ${type:-unknown}"
    fi
}

tui_status_summary() {
    local total_tools=0
    local active_tools=0
    local installed_versions=0
    local path_status="missing"
    local tool
    local dir

    total_tools=$(jq -r 'keys | length' "$REGISTRY_PATH" 2>/dev/null || echo "0")
    while IFS= read -r tool; do
        [[ -f "$DEVMAN_DIR/versions/$tool/.active" ]] && active_tools=$((active_tools + 1))
        if [[ -d "$DEVMAN_DIR/versions/$tool" ]]; then
            for dir in "$DEVMAN_DIR/versions/$tool"/*; do
                [[ -d "$dir" ]] && installed_versions=$((installed_versions + 1))
            done
        fi
    done < <(jq -r 'keys[]' "$REGISTRY_PATH" 2>/dev/null || true)

    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        path_status="ok"
    fi

    printf "Registry tools: %s | Active tools: %s | Installed versions: %s | PATH: %s\n" \
        "$total_tools" "$active_tools" "$installed_versions" "$path_status"

    if command -v jq >/dev/null 2>&1 && [[ -f "$LEARNING_PROGRESS_FILE" ]]; then
        local completed_count
        local next_module
        completed_count=$(jq -r '(.completed // []) | length' "$LEARNING_PROGRESS_FILE" 2>/dev/null || echo "0")
        next_module=$(learning_next_module)
        [[ -z "$next_module" ]] && next_module="complete"
        printf "Learning: %s/%s complete | Next: %s\n" "$completed_count" "${#LEARNING_MODULES[@]}" "$next_module"
    else
        echo "Learning: progress starts with 'Learning hub -> Start next module'"
    fi
    echo "------------------------------------------------------------"
}

tui_select() {
    local title=$1
    local subtitle=$2
    local options_name=$3
    local descriptions_name=$4
    local show_status=${5:-yes}
    local -n options_ref="$options_name"
    local -n descriptions_ref="$descriptions_name"
    local selected=0
    local count=${#options_ref[@]}

    if [[ "$count" -eq 0 ]]; then
        TUI_SELECTED=-1
        return 1
    fi

    while true; do
        tui_header "$title" "$subtitle"
        if [[ "$show_status" == "yes" ]]; then
            tui_status_summary
        fi
        echo "Use Up/Down or j/k to move, Enter to select, 1-9 for shortcuts, q to go back."
        echo "------------------------------------------------------------"

        local i
        for ((i = 0; i < count; i++)); do
            local shortcut=""
            local desc="${descriptions_ref[i]:-}"
            if [[ "$i" -lt 9 ]]; then
                shortcut="$((i + 1))."
            else
                shortcut="  "
            fi

            if [[ "$i" -eq "$selected" ]]; then
                printf "%b> %-3s %-26s%b %s\n" "$BLUE" "$shortcut" "${options_ref[i]}" "$NC" "$desc"
            else
                printf "  %-3s %-26s %s\n" "$shortcut" "${options_ref[i]}" "$desc"
            fi
        done
        echo "------------------------------------------------------------"

        tui_read_key
        case "$TUI_KEY" in
            up|k|K)
                selected=$(( (selected - 1 + count) % count ))
                ;;
            down|j|J)
                selected=$(( (selected + 1) % count ))
                ;;
            enter)
                TUI_SELECTED=$selected
                return 0
                ;;
            q|Q|escape|quit)
                TUI_SELECTED=-1
                return 1
                ;;
            [1-9])
                local shortcut_index=$((TUI_KEY - 1))
                if [[ "$shortcut_index" -lt "$count" ]]; then
                    TUI_SELECTED=$shortcut_index
                    return 0
                fi
                ;;
        esac
    done
}

tui_prompt() {
    local title=$1
    local prompt=$2
    local default=${3:-}

    tui_show_cursor
    tui_header "$title"
    if [[ -n "$default" ]]; then
        echo "Default: $default"
        echo ""
    fi
    if ! read -r -p "$prompt" TUI_INPUT; then
        TUI_INPUT=""
    fi
    [[ -z "$TUI_INPUT" && -n "$default" ]] && TUI_INPUT="$default"
    tui_hide_cursor
}

tui_confirm() {
    local title=$1
    local prompt=$2

    tui_show_cursor
    tui_header "$title"
    local answer=""
    if ! read -r -p "$prompt (y/N): " answer; then
        answer=""
    fi
    tui_hide_cursor

    [[ "$answer" =~ ^[Yy]$ ]]
}

tui_run_action() {
    local title=$1
    shift

    tui_show_cursor
    tui_header "$title"
    set +e
    "$@"
    local status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        echo ""
        echo -e "${YELLOW}Action exited with status $status.${NC}"
    fi
    tui_pause
    tui_hide_cursor
    return 0
}

tui_choose_tool() {
    local title=${1:-"Select Tool"}
    local tools=()
    local descriptions=()
    local tool

    while IFS= read -r tool; do
        tools+=("$tool")
        descriptions+=("$(tui_tool_status "$tool")")
    done < <(jq -r 'keys[]' "$REGISTRY_PATH")

    tools+=("Back")
    descriptions+=("Return to the previous menu")

    if ! tui_select "$title" "Choose a registry tool to manage." tools descriptions "yes"; then
        return 1
    fi
    if [[ "${tools[TUI_SELECTED]}" == "Back" ]]; then
        return 1
    fi

    TUI_TOOL="${tools[TUI_SELECTED]}"
    return 0
}

tui_choose_learning_module() {
    local title=${1:-"Select Learning Module"}
    local modules=()
    local descriptions=()
    local module

    for module in "${LEARNING_MODULES[@]}"; do
        modules+=("$module")
        descriptions+=("$(learning_module_title "$module")")
    done
    modules+=("Back")
    descriptions+=("Return to the previous menu")

    if ! tui_select "$title" "Choose a DevOps learning module." modules descriptions "yes"; then
        return 1
    fi
    if [[ "${modules[TUI_SELECTED]}" == "Back" ]]; then
        return 1
    fi

    TUI_MODULE="${modules[TUI_SELECTED]}"
    return 0
}

tui_choose_installed_version() {
    local tool=$1
    local title=${2:-"Select Installed Version"}
    local versions=()
    local descriptions=()
    local active_ver=""
    local dir

    if [[ -f "$DEVMAN_DIR/versions/$tool/.active" ]]; then
        active_ver=$(cat "$DEVMAN_DIR/versions/$tool/.active")
    fi

    if [[ -d "$DEVMAN_DIR/versions/$tool" ]]; then
        for dir in "$DEVMAN_DIR/versions/$tool"/*; do
            if [[ -d "$dir" ]]; then
                local version="${dir##*/}"
                versions+=("$version")
                if [[ "$version" == "$active_ver" ]]; then
                    descriptions+=("active")
                else
                    descriptions+=("installed")
                fi
            fi
        done
    fi

    if [[ "${#versions[@]}" -eq 0 ]]; then
        tui_run_action "$title" list_versions "$tool"
        return 1
    fi

    versions+=("Back")
    descriptions+=("Return to the previous menu")

    if ! tui_select "$title" "Tool: $tool" versions descriptions "yes"; then
        return 1
    fi
    if [[ "${versions[TUI_SELECTED]}" == "Back" ]]; then
        return 1
    fi

    TUI_VERSION="${versions[TUI_SELECTED]}"
    return 0
}

tui_show_status_details() {
    tui_show_cursor
    tui_header "DevMan Status"

    echo "Paths"
    echo "  DevMan dir:  $DEVMAN_DIR"
    echo "  Install dir: $INSTALL_DIR"
    echo "  Registry:    $REGISTRY_PATH"
    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        echo "  PATH:        ok"
    else
        echo "  PATH:        missing $INSTALL_DIR"
    fi

    echo ""
    echo "Prerequisites"
    local dep
    for dep in curl jq unzip tar gpg git docker kubectl terraform; do
        if command -v "$dep" >/dev/null 2>&1; then
            printf "  %-10s ok (%s)\n" "$dep" "$(command -v "$dep")"
        else
            printf "  %-10s missing\n" "$dep"
        fi
    done

    echo ""
    tui_status_summary
    tui_pause
    tui_hide_cursor
}

tui_view_logs() {
    tui_show_cursor
    tui_header "DevMan Logs" "Showing the latest 40 log lines."
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 40 "$LOG_FILE"
    else
        echo "No logs found at $LOG_FILE"
    fi
    tui_pause
    tui_hide_cursor
}

tui_tools_menu() {
    while true; do
        if ! tui_choose_tool "Tool Manager"; then
            return 0
        fi
        manage_tool_interactive "$TUI_TOOL"
    done
}

manage_tool_interactive() {
    local tool=$1

    while true; do
        local options=(
            "Install latest"
            "Install specific"
            "Switch active version"
            "Show installed versions"
            "Uninstall version"
            "Uninstall all versions"
            "Back"
        )
        local descriptions=(
            "Download, verify, install, and activate latest"
            "Prompt for an exact version or tag"
            "Choose from installed versions"
            "$(tui_tool_status "$tool")"
            "Remove one installed version"
            "Remove every cached version for this tool"
            "Return to tool list"
        )

        if ! tui_select "Manage Tool: $tool" "$(tui_tool_status "$tool")" options descriptions "yes"; then
            return 0
        fi

        case "${options[TUI_SELECTED]}" in
            "Install latest")
                tui_run_action "Install latest $tool" install_tool "$tool" "latest"
                ;;
            "Install specific")
                tui_prompt "Install $tool" "Version/tag to install: "
                if [[ -n "$TUI_INPUT" ]]; then
                    tui_run_action "Install $tool $TUI_INPUT" install_tool "$tool" "$TUI_INPUT"
                fi
                ;;
            "Switch active version")
                if tui_choose_installed_version "$tool" "Switch $tool"; then
                    tui_run_action "Activate $tool $TUI_VERSION" set_active_version "$tool" "$TUI_VERSION"
                fi
                ;;
            "Show installed versions")
                tui_run_action "Installed versions for $tool" list_versions "$tool"
                ;;
            "Uninstall version")
                if tui_choose_installed_version "$tool" "Uninstall $tool"; then
                    if tui_confirm "Uninstall $tool $TUI_VERSION" "Remove this version"; then
                        tui_run_action "Uninstall $tool $TUI_VERSION" uninstall_tool "$tool" "$TUI_VERSION"
                    fi
                fi
                ;;
            "Uninstall all versions")
                if tui_confirm "Uninstall all $tool versions" "Remove every installed version of $tool"; then
                    tui_run_action "Uninstall all $tool versions" uninstall_tool "$tool" "all"
                fi
                ;;
            "Back")
                return 0
                ;;
        esac
    done
}

tui_learning_menu() {
    while true; do
        local options=(
            "Roadmap"
            "Progress"
            "Start next module"
            "Start selected module"
            "Create lab"
            "Check module tools"
            "Quiz"
            "Study plan"
            "Init workspace"
            "Reset progress"
            "Back"
        )
        local descriptions=(
            "View the complete DevOps path"
            "Show completed and next modules"
            "Continue from saved progress"
            "Pick a module from the roadmap"
            "Generate practice files"
            "Check local tool readiness"
            "Answer a short interactive quiz"
            "Generate a day-by-day plan"
            "Create notes, labs, and Makefile"
            "Clear local learning-progress.json"
            "Return to dashboard"
        )

        if ! tui_select "Learning Hub" "Roadmap, labs, checks, quizzes, and progress." options descriptions "yes"; then
            return 0
        fi

        case "${options[TUI_SELECTED]}" in
            "Roadmap")
                tui_run_action "Learning Roadmap" learning_roadmap
                ;;
            "Progress")
                tui_run_action "Learning Progress" learning_progress
                ;;
            "Start next module")
                tui_run_action "Start Next Module" learning_start "next"
                ;;
            "Start selected module")
                if tui_choose_learning_module "Start Module"; then
                    tui_run_action "Start $TUI_MODULE" learning_start "$TUI_MODULE"
                fi
                ;;
            "Create lab")
                if tui_choose_learning_module "Create Lab"; then
                    tui_prompt "Create $TUI_MODULE Lab" "Lab directory (blank for default): "
                    if [[ -n "$TUI_INPUT" ]]; then
                        tui_run_action "Create $TUI_MODULE Lab" learning_create_lab "$TUI_MODULE" "$TUI_INPUT"
                    else
                        tui_run_action "Create $TUI_MODULE Lab" learning_create_lab "$TUI_MODULE"
                    fi
                fi
                ;;
            "Check module tools")
                if tui_choose_learning_module "Check Tools"; then
                    tui_run_action "Check $TUI_MODULE Tools" learning_check "$TUI_MODULE"
                fi
                ;;
            "Quiz")
                if tui_choose_learning_module "Run Quiz"; then
                    tui_show_cursor
                    tui_header "Quiz: $TUI_MODULE"
                    learning_quiz "$TUI_MODULE"
                    tui_pause
                    tui_hide_cursor
                fi
                ;;
            "Study plan")
                tui_prompt "Study Plan" "Number of days: " "30"
                tui_run_action "$TUI_INPUT-Day Study Plan" learning_plan "$TUI_INPUT"
                ;;
            "Init workspace")
                tui_prompt "Initialize Learning Workspace" "Workspace directory: " "devops-learning-lab"
                tui_run_action "Initialize Learning Workspace" learning_init_workspace "$TUI_INPUT"
                ;;
            "Reset progress")
                if tui_confirm "Reset Learning Progress" "Reset saved learning progress"; then
                    tui_run_action "Reset Learning Progress" learning_reset "--yes"
                fi
                ;;
            "Back")
                return 0
                ;;
        esac
    done
}

tui_bootstrap_menu() {
    while true; do
        local options=("Terraform" "Kubernetes" "Docker Compose" "Back")
        local descriptions=(
            "Create a local Terraform starter"
            "Create a Deployment and Service manifest"
            "Create a two-service compose file"
            "Return to dashboard"
        )

        if ! tui_select "Bootstrap Samples" "Create starter files in the current directory." options descriptions "yes"; then
            return 0
        fi

        case "${options[TUI_SELECTED]}" in
            "Terraform")
                tui_run_action "Bootstrap Terraform" bootstrap_sample "terraform"
                ;;
            "Kubernetes")
                tui_run_action "Bootstrap Kubernetes" bootstrap_sample "kubernetes"
                ;;
            "Docker Compose")
                tui_run_action "Bootstrap Docker Compose" bootstrap_sample "docker"
                ;;
            "Back")
                return 0
                ;;
        esac
    done
}

tui_registry_menu() {
    while true; do
        local options=("Add tool" "Remove tool" "Sync registry" "Back")
        local descriptions=(
            "Add a GitHub or direct download entry"
            "Remove a registry entry"
            "Replace registry from a remote JSON URL"
            "Return to maintenance"
        )

        if ! tui_select "Registry Manager" "Manage registry.json entries." options descriptions "yes"; then
            return 0
        fi

        case "${options[TUI_SELECTED]}" in
            "Add tool")
                tui_prompt "Add Registry Tool" "Tool name: "
                local name="$TUI_INPUT"
                tui_prompt "Add Registry Tool" "Type (github/direct): " "github"
                local type="$TUI_INPUT"
                tui_prompt "Add Registry Tool" "Repo owner/name or direct URL: "
                local repo_or_url="$TUI_INPUT"
                tui_prompt "Add Registry Tool" "Asset pattern (optional): "
                local pattern="$TUI_INPUT"
                tui_prompt "Add Registry Tool" "Latest version URL (optional): "
                local latest_url="$TUI_INPUT"
                if [[ -n "$name" && -n "$type" && -n "$repo_or_url" ]]; then
                    tui_run_action "Add Registry Tool" registry_add "$name" "$type" "$repo_or_url" "$pattern" "$latest_url"
                fi
                ;;
            "Remove tool")
                if tui_choose_tool "Remove Registry Tool"; then
                    if tui_confirm "Remove $TUI_TOOL" "Remove $TUI_TOOL from the registry"; then
                        tui_run_action "Remove $TUI_TOOL" registry_remove "$TUI_TOOL"
                    fi
                fi
                ;;
            "Sync registry")
                tui_prompt "Sync Registry" "Registry JSON URL: "
                if [[ -n "$TUI_INPUT" ]]; then
                    tui_run_action "Sync Registry" registry_sync "$TUI_INPUT"
                fi
                ;;
            "Back")
                return 0
                ;;
        esac
    done
}

tui_maintenance_menu() {
    while true; do
        local options=(
            "List tools"
            "Check updates"
            "Upgrade all active tools"
            "Upgrade selected tool"
            "Export lockfile"
            "Import lockfile"
            "Prune cache"
            "Registry manager"
            "View logs"
            "Back"
        )
        local descriptions=(
            "Show registry status and installed versions"
            "Fetch latest versions and compare"
            "Install latest for every active tool"
            "Pick one tool to upgrade"
            "Write active versions to JSON"
            "Install and activate versions from JSON"
            "Remove inactive cached versions"
            "Add, remove, or sync registry entries"
            "Show recent DevMan audit logs"
            "Return to dashboard"
        )

        if ! tui_select "Maintenance" "Updates, lockfiles, registry, cleanup, and logs." options descriptions "yes"; then
            return 0
        fi

        case "${options[TUI_SELECTED]}" in
            "List tools")
                tui_run_action "Tool List" list_tools
                ;;
            "Check updates")
                tui_run_action "Check Updates" check_updates
                ;;
            "Upgrade all active tools")
                if tui_confirm "Upgrade All Active Tools" "Install latest for every active tool"; then
                    tui_run_action "Upgrade All Active Tools" upgrade_tools "all"
                fi
                ;;
            "Upgrade selected tool")
                if tui_choose_tool "Upgrade Tool"; then
                    tui_run_action "Upgrade $TUI_TOOL" upgrade_tools "$TUI_TOOL"
                fi
                ;;
            "Export lockfile")
                tui_prompt "Export Lockfile" "Lockfile path: " "devman.lock"
                tui_run_action "Export Lockfile" export_lockfile "$TUI_INPUT"
                ;;
            "Import lockfile")
                tui_prompt "Import Lockfile" "Lockfile path: " "devman.lock"
                tui_run_action "Import Lockfile" import_lockfile "$TUI_INPUT"
                ;;
            "Prune cache")
                if tui_confirm "Prune Cache" "Remove inactive cached versions"; then
                    tui_run_action "Prune Cache" prune_cache
                fi
                ;;
            "Registry manager")
                tui_registry_menu
                ;;
            "View logs")
                tui_view_logs
                ;;
            "Back")
                return 0
                ;;
        esac
    done
}

interactive_tui() {
    if [[ ! -t 0 || ! -t 1 ]]; then
        echo "Error: TUI must be run in an interactive terminal." >&2
        exit 1
    fi

    tui_hide_cursor
    trap 'tui_restore_terminal; exit' INT TERM EXIT

    while true; do
        local options=(
            "Tool manager"
            "Learning hub"
            "Bootstrap samples"
            "Maintenance"
            "System status"
            "Quit"
        )
        local descriptions=(
            "Install, switch, inspect, or uninstall tools"
            "Roadmap, labs, progress, quizzes, and study plans"
            "Generate Terraform, Kubernetes, or Docker starters"
            "Updates, lockfiles, registry, cleanup, and logs"
            "Paths, prerequisites, and current summary"
            "Exit DevMan"
        )

        if ! tui_select "DEVMAN DASHBOARD" "Run devman with no arguments to open this dashboard." options descriptions "yes"; then
            break
        fi

        case "${options[TUI_SELECTED]}" in
            "Tool manager")
                tui_tools_menu
                ;;
            "Learning hub")
                tui_learning_menu
                ;;
            "Bootstrap samples")
                tui_bootstrap_menu
                ;;
            "Maintenance")
                tui_maintenance_menu
                ;;
            "System status")
                tui_show_status_details
                ;;
            "Quit")
                break
                ;;
        esac
    done

    trap - INT TERM EXIT
    tui_restore_terminal
    clear
}

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
            COMPREPLY=( $(compgen -W "roadmap start next complete progress plan init lab check tools quiz reset help" -- ${cur}) )
            return 0
            ;;
        start|complete|done|lab|scaffold|check|doctor|quiz)
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
            echo "  $0 check-updates                # Lists tools with pending updates"
            echo "  $0 upgrade                      # Upgrades all installed tools"
            echo "  $0 export devman.lock           # Locks environment version settings"
            echo "  $0 import devman.lock           # Installs and matches lockfile settings"
        fi
        ;;
esac
