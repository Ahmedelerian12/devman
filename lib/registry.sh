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
        echo -e "${GREEN}âœ“ Added '$name' to registry.${NC}"
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
        echo -e "${GREEN}âœ“ Removed '$name' from registry.${NC}"
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
            echo -e "${GREEN}âœ“ Registry successfully synchronized!${NC}"
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
