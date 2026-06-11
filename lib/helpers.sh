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
        echo -e "${GREEN}âœ“ GPG Signature verified successfully! (Authentic release)${NC}"
        return 0
    else
        echo -e "${RED}Security Error: GPG Signature verification failed! The checksum file is untrusted.${NC}" >&2
        return 1
    fi
}
