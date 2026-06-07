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
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
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
# KEYBOARD-DRIVEN TUI DASHBOARD
# ==============================================================================

interactive_tui() {
    if [[ ! -t 0 ]]; then
        echo "Error: TUI must be run in an interactive terminal." >&2
        exit 1
    fi

    # Read tools
    local tools=($(jq -r 'keys[]' "$REGISTRY_PATH"))
    local count=${#tools[@]}
    local selected=0

    # Hide cursor
    tput civis 2>/dev/null || echo -ne "\033[?25l"
    
    # Restore cursor on exit
    trap 'tput cnorm 2>/dev/null || echo -ne "\033[?25h"; exit' INT TERM EXIT

    while true; do
        clear
        echo -e "${GREEN}========================================================${NC}"
        echo -e "${GREEN}           DEVMAN - INTERACTIVE DASHBOARD TUI           ${NC}"
        echo -e "${GREEN}========================================================${NC}"
        echo -e "Use Arrow Keys (Up/Down) to navigate, Enter to choose tool."
        echo -e "Press 'q' or 'ESC' to exit."
        echo -e "--------------------------------------------------------"

        for ((i=0; i<count; i++)); do
            local tool="${tools[i]}"
            local active_ver="not installed"
            local link_bin="$INSTALL_DIR/$tool$EXE_EXT"
            if [[ -f "$link_bin" && -f "$DEVMAN_DIR/versions/$tool/.active" ]]; then
                active_ver=$(cat "$DEVMAN_DIR/versions/$tool/.active")
            fi

            if [[ $i -eq $selected ]]; then
                echo -e "  ${BLUE}* [ $tool ]${NC} (Active: ${GREEN}$active_ver${NC})  <--"
            else
                echo -e "    $tool   (Active: $active_ver)"
            fi
        done
        echo -e "--------------------------------------------------------"

        # Read single keypress
        read -s -n 1 key
        if [[ "$key" == $'\e' ]]; then
            read -s -n 2 -t 0.1 key2
            if [[ "$key2" == "[A" ]]; then # Up Arrow
                selected=$(( (selected - 1 + count) % count ))
            elif [[ "$key2" == "[B" ]]; then # Down Arrow
                selected=$(( (selected + 1) % count ))
            else
                break # ESC
            fi
        elif [[ "$key" == "" ]]; then # Enter key
            local chosen_tool="${tools[selected]}"
            tput cnorm 2>/dev/null || echo -ne "\033[?25h"
            manage_tool_interactive "$chosen_tool"
            tput civis 2>/dev/null || echo -ne "\033[?25l"
        elif [[ "$key" == "q" ]]; then
            break
        fi
    done

    tput cnorm 2>/dev/null || echo -ne "\033[?25h"
    clear
}

manage_tool_interactive() {
    local tool=$1
    clear
    echo -e "${GREEN}Managing Tool: $tool${NC}"
    echo -e "----------------------------------------"
    echo -e "1) Install Latest Version"
    echo -e "2) Install Specific Version"
    echo -e "3) Switch Active Version"
    echo -e "4) Uninstall Tool"
    echo -e "5) Back to Menu"
    echo -e "----------------------------------------"
    read -p "Select option (1-5): " -n 1 -r
    echo ""

    case "$REPLY" in
        1)
            echo ""
            install_tool "$tool" "latest"
            ;;
        2)
            echo ""
            read -p "Enter version to install (e.g. 1.5.7): " ver
            if [[ -n "$ver" ]]; then
                install_tool "$tool" "$ver"
            fi
            ;;
        3)
            echo ""
            list_versions "$tool"
            echo ""
            read -p "Enter version to activate: " ver
            if [[ -n "$ver" ]]; then
                set_active_version "$tool" "$ver"
            fi
            ;;
        4)
            echo ""
            read -p "Enter version to uninstall (Leave blank to remove ALL): " ver
            uninstall_tool "$tool" "$ver"
            ;;
        *)
            return
            ;;
    esac
    echo -e "\nPress any key to return..."
    read -n 1
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
    
    opts="list install install-all use uninstall versions bootstrap logs registry prune completion auto-switch run check-updates upgrade export import tui"
    
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
            echo "Usage: $0 {list|install <tool> [version]|install-all|use <tool> <version>|versions <tool>|uninstall <tool> [version]|bootstrap <type>|logs|prune|registry {add|remove|sync}|completion <bash|zsh>|auto-switch [--silent]|run <tool>@<version> <args>|check-updates|upgrade [tool]|export [file]|import [file]|tui}"
            echo ""
            echo "Examples:"
            echo "  $0                              # Launches interactive TUI dashboard"
            echo "  $0 run terraform@1.5.0 version  # Ad-hoc runner without linking version"
            echo "  $0 check-updates                # Lists tools with pending updates"
            echo "  $0 upgrade                      # Upgrades all installed tools"
            echo "  $0 export devman.lock           # Locks environment version settings"
            echo "  $0 import devman.lock           # Installs and matches lockfile settings"
        fi
        ;;
esac