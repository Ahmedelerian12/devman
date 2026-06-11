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

    if command -v jq >/dev/null 2>&1; then
        local completed_count
        local next_module
        local current_module
        local xp
        local streak
        completed_count=$(jq -r '(.completed // []) | length' "$LEARNING_PROGRESS_FILE" 2>/dev/null || echo "0")
        current_module=$(jq -r '.current // ""' "$LEARNING_PROGRESS_FILE" 2>/dev/null || echo "")
        xp=$(jq -r '.xp // 0' "$LEARNING_PROGRESS_FILE" 2>/dev/null || echo "0")
        streak=$(jq -r '.streak // 0' "$LEARNING_PROGRESS_FILE" 2>/dev/null || echo "0")
        next_module=$(learning_next_module)
        [[ -z "$next_module" ]] && next_module="complete"
        printf "Learning: %s | XP: %s | Streak: %s | Current: %s | Next: %s\n" \
            "$(learning_progress_bar)" "$xp" "$streak" "${current_module:-none}" "$next_module"
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
            "Resume current mission"
            "Start next module"
            "Start selected module"
            "Create lab"
            "Validate lab"
            "Check module tools"
            "Quiz"
            "Study plan"
            "Init workspace"
            "Create capstone project"
            "Recent activity"
            "Reset progress"
            "Back"
        )
        local descriptions=(
            "View the complete DevOps path"
            "Show XP, streaks, badges, and modules"
            "Open the saved current module"
            "Continue from saved progress"
            "Pick a module from the roadmap"
            "Generate practice files"
            "Check tools and required lab files"
            "Check local tool readiness"
            "Answer a randomized interactive quiz"
            "Generate a day-by-day plan"
            "Create notes, labs, and Makefile"
            "Create Docker + Kubernetes + Terraform + CI starter"
            "Show recent learning events"
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
            "Resume current mission")
                tui_run_action "Resume Mission" learning_start "next"
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
            "Validate lab")
                if tui_choose_learning_module "Validate Lab"; then
                    tui_prompt "Validate $TUI_MODULE Lab" "Lab directory (blank for default): "
                    if [[ -n "$TUI_INPUT" ]]; then
                        tui_run_action "Validate $TUI_MODULE Lab" learning_validate_lab "$TUI_MODULE" "$TUI_INPUT"
                    else
                        tui_run_action "Validate $TUI_MODULE Lab" learning_validate_lab "$TUI_MODULE"
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
                    learning_quiz "$TUI_MODULE" "5"
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
            "Create capstone project")
                tui_prompt "Create Capstone Project" "Project directory: " "devops-capstone-platform"
                tui_run_action "Create Capstone Project" learning_create_project "$TUI_INPUT"
                ;;
            "Recent activity")
                tui_run_action "Recent Learning Activity" learning_recent_activity
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
            "Resume last mission"
            "Learning hub"
            "Bootstrap samples"
            "Maintenance"
            "System status"
            "Quit"
        )
        local descriptions=(
            "Install, switch, inspect, or uninstall tools"
            "Continue the current or next learning mission"
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
            "Resume last mission")
                tui_run_action "Resume Last Mission" learning_start "next"
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
