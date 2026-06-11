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
        echo -e "${GREEN}âœ“ Nothing to prune. Your cache is clean!${NC}"
    else
        echo -e "${GREEN}âœ“ Pruned $count unused version(s). Saved $((bytes_saved / 1024 / 1024)) MB.${NC}"
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
    echo -e "${GREEN}âœ“ Successfully exported lockfile to $lock_file.${NC}"
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
    echo -e "\n${GREEN}âœ“ Successfully imported all tools from $lock_file!${NC}"
    log_message "Imported lockfile from $lock_file" "SUCCESS"
}
