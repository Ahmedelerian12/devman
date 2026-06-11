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
                    echo -e "${GREEN}âœ“ Checksum verified successfully!${NC}"

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
            echo -e "${GREEN}âœ“ Post-installation hook completed successfully.${NC}"
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
