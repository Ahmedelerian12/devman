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
        echo -e "${GREEN}âœ“ Successfully symlinked $tool_name $version -> $link_bin${NC}"
        log_message "Activated version '$version' of '$tool_name' (symlink)" "SUCCESS"
    else
        # Fallback: Copy the binary
        echo -e "${YELLOW}Symlink failed. Falling back to copying the binary...${NC}"
        if cp "$target_bin" "$link_bin"; then
            echo -e "${GREEN}âœ“ Successfully copied $tool_name $version -> $link_bin${NC}"
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
            status_plain="âœ“ $active_ver"
            status_color="${GREEN}âœ“ $active_ver${NC}"
        else
            if [[ ${#installed_versions[@]} -gt 0 ]]; then
                status_plain="â—‹ unlinked"
                status_color="${YELLOW}â—‹ unlinked${NC}"
            else
                status_plain="â—‹ not installed"
                status_color="${NC}â—‹ not installed${NC}"
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
        echo -e "${GREEN}âœ“ Successfully uninstalled all versions of $tool_name.${NC}"
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
        echo -e "${GREEN}âœ“ Successfully uninstalled $tool_name version $version.${NC}"
        log_message "Uninstalled version '$version' of '$tool_name'" "SUCCESS"
    fi
}
