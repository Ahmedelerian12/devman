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
