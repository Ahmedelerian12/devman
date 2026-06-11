# ==============================================================================
# DEVOPS LEARNING AUTOMATION
# ==============================================================================

LEARNING_CONTENT_DIR="${DEVMAN_CONTENT_DIR:-$DEVMAN_SCRIPT_DIR/content}"
LEARNING_DATA_FILE="$LEARNING_CONTENT_DIR/learning.json"

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

if command -v jq >/dev/null 2>&1 && [[ -f "$LEARNING_DATA_FILE" ]]; then
    mapfile -t LEARNING_MODULES < <(jq -r '.modules[].id' "$LEARNING_DATA_FILE" 2>/dev/null)
fi

learning_usage() {
    echo "DevMan Learning Automation"
    echo "Usage: devman learn <command> [args]"
    echo ""
    echo "Commands:"
    echo "  roadmap                    Show the full DevOps learning path"
    echo "  start [module]             Start a guided module mission"
    echo "  next                       Continue with the next unfinished module"
    echo "  complete <module>          Mark a module as complete"
    echo "  progress                   Show XP, streaks, badges, and module progress"
    echo "  plan [days]                Generate a day-by-day study plan"
    echo "  init [directory]           Create a full learning workspace"
    echo "  lab <module> [directory]   Create a runnable practice lab"
    echo "  validate <module> [dir]    Validate tools and lab files"
    echo "  cheatsheet [module]        Show the module cheat sheet"
    echo "  project [directory]        Create the full capstone project template"
    echo "  check [module]             Check local tool readiness"
    echo "  tools                      Show tools used across the roadmap"
    echo "  quiz [module] [count]      Run a randomized interactive quiz"
    echo "  activity                   Show recent learning activity"
    echo "  reset [--yes]              Reset saved learning progress"
    echo ""
    echo "Modules:"
    echo "  ${LEARNING_MODULES[*]}"
}

learning_require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}Error: 'jq' is required for data-driven learning commands.${NC}" >&2
        echo "Install jq, then try again." >&2
        exit 1
    fi
}

learning_require_content() {
    learning_require_jq
    if [[ ! -f "$LEARNING_DATA_FILE" ]]; then
        echo -e "${RED}Error: learning content not found at $LEARNING_DATA_FILE.${NC}" >&2
        exit 1
    fi
}

learning_module_json() {
    local module=$1
    learning_require_content
    jq -c --arg module "$module" '.modules[] | select(.id == $module)' "$LEARNING_DATA_FILE"
}

learning_module_field() {
    local module=$1
    local field=$2
    learning_require_content
    jq -r --arg module "$module" --arg field "$field" \
        '.modules[] | select(.id == $module) | .[$field] // ""' "$LEARNING_DATA_FILE"
}

learning_module_array() {
    local module=$1
    local field=$2
    learning_require_content
    jq -r --arg module "$module" --arg field "$field" \
        '.modules[] | select(.id == $module) | (.[$field] // [])[]' "$LEARNING_DATA_FILE"
}

learning_module_title() {
    learning_module_field "$1" "title"
}

learning_module_level() {
    learning_module_field "$1" "level"
}

learning_module_goal() {
    learning_module_field "$1" "goal"
}

learning_module_tools() {
    local module=$1
    learning_require_content
    jq -r --arg module "$module" \
        '.modules[] | select(.id == $module) | (.tools // []) | join(" ")' "$LEARNING_DATA_FILE"
}

learning_module_challenge() {
    learning_module_field "$1" "challenge"
}

learning_module_steps() {
    learning_module_array "$1" "steps"
}

learning_module_checkpoint() {
    learning_module_field "$1" "checkpoint"
}

learning_module_xp() {
    local module=$1
    local action=$2
    learning_require_content
    jq -r --arg module "$module" --arg action "$action" \
        '.modules[] | select(.id == $module) | (.xp[$action] // 0)' "$LEARNING_DATA_FILE"
}

learning_module_badge() {
    local module=$1
    local action=$2
    learning_require_content
    jq -r --arg module "$module" --arg action "$action" \
        '.modules[] | select(.id == $module) | (.badges[$action] // "")' "$LEARNING_DATA_FILE"
}

learning_module_valid() {
    local module=$1
    local known
    for known in "${LEARNING_MODULES[@]}"; do
        [[ "$known" == "$module" ]] && return 0
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
  "lab_root": "",
  "xp": 0,
  "streak": 0,
  "last_activity_date": "",
  "badges": [],
  "module_stats": {},
  "events": []
}
EOF
    fi

    local temp_file
    temp_file=$(mktemp)
    jq '
      .completed = (.completed // []) |
      .completed_at = (.completed_at // {}) |
      .current = (.current // "") |
      .lab_root = (.lab_root // "") |
      .xp = (.xp // 0) |
      .streak = (.streak // 0) |
      .last_activity_date = (.last_activity_date // "") |
      .badges = (.badges // []) |
      .module_stats = (.module_stats // {}) |
      .events = (.events // [])
    ' "$LEARNING_PROGRESS_FILE" > "$temp_file"
    mv "$temp_file" "$LEARNING_PROGRESS_FILE"
}

learning_has_badge() {
    local badge=$1
    [[ -z "$badge" ]] && return 1
    learning_ensure_progress
    jq -e --arg badge "$badge" '(.badges // []) | index($badge)' "$LEARNING_PROGRESS_FILE" >/dev/null 2>&1
}

learning_record_activity() {
    local module=$1
    local action=$2
    local xp=${3:-0}
    local badge=${4:-}

    learning_ensure_progress

    if [[ -n "$badge" ]] && learning_has_badge "$badge"; then
        xp=0
    fi

    local now
    local today
    now=$(date '+%Y-%m-%d %H:%M:%S')
    today=$(date '+%Y-%m-%d')

    local temp_file
    temp_file=$(mktemp)
    jq \
        --arg module "$module" \
        --arg action "$action" \
        --arg now "$now" \
        --arg today "$today" \
        --arg badge "$badge" \
        --argjson xp "$xp" '
        .xp = ((.xp // 0) + $xp) |
        .streak = (
            if (.last_activity_date // "") == $today then (.streak // 0)
            elif (.last_activity_date // "") == "" then 1
            else ((.streak // 0) + 1)
            end
        ) |
        .last_activity_date = $today |
        .badges = (
            if $badge == "" then (.badges // [])
            else (((.badges // []) + [$badge]) | unique)
            end
        ) |
        .module_stats = (.module_stats // {}) |
        .module_stats[$module] = ((.module_stats[$module] // {}) + {
            "last_action": $action,
            "last_seen": $now
        }) |
        .events = ([{
            "time": $now,
            "module": $module,
            "action": $action,
            "xp": $xp,
            "badge": $badge
        }] + (.events // []))[:25]
    ' "$LEARNING_PROGRESS_FILE" > "$temp_file"
    mv "$temp_file" "$LEARNING_PROGRESS_FILE"
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

learning_current_module() {
    if [[ -f "$LEARNING_PROGRESS_FILE" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '.current // ""' "$LEARNING_PROGRESS_FILE"
    fi
}

learning_progress_count() {
    if [[ -f "$LEARNING_PROGRESS_FILE" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '(.completed // []) | length' "$LEARNING_PROGRESS_FILE"
    else
        echo "0"
    fi
}

learning_progress_bar() {
    local completed
    local total
    local width=20
    local filled
    local empty
    completed=$(learning_progress_count)
    total=${#LEARNING_MODULES[@]}
    [[ "$total" -eq 0 ]] && total=1
    filled=$((completed * width / total))
    empty=$((width - filled))
    printf "[%s%s] %s/%s" "$(printf '%*s' "$filled" '' | tr ' ' '#')" "$(printf '%*s' "$empty" '' | tr ' ' '-')" "$completed" "$total"
}

learning_roadmap() {
    learning_require_content
    learning_ensure_progress

    echo -e "${GREEN}DevOps learning roadmap${NC}"
    echo "Progress: $(learning_progress_bar)"
    echo "Progress file: $LEARNING_PROGRESS_FILE"
    echo "--------------------------------------------------------------------------------"
    printf "%-3s %-15s %-13s %-10s %s\n" "#" "MODULE" "LEVEL" "STATUS" "GOAL"
    echo "--------------------------------------------------------------------------------"

    local idx=1
    local module
    for module in "${LEARNING_MODULES[@]}"; do
        local status="todo"
        learning_is_completed "$module" && status="done"
        printf "%-3s %-15s %-13s %-10s %s\n" "$idx" "$module" "$(learning_module_level "$module")" "$status" "$(learning_module_title "$module")"
        idx=$((idx + 1))
    done
    echo "--------------------------------------------------------------------------------"
    echo "Run: devman learn start        # resume the next unfinished mission"
    echo "Run: devman learn validate docker"
}

learning_progress() {
    learning_ensure_progress
    local completed_count
    local total=${#LEARNING_MODULES[@]}
    local current
    local next
    local xp
    local streak
    completed_count=$(learning_progress_count)
    current=$(jq -r '.current // ""' "$LEARNING_PROGRESS_FILE")
    next=$(learning_next_module)
    xp=$(jq -r '.xp // 0' "$LEARNING_PROGRESS_FILE")
    streak=$(jq -r '.streak // 0' "$LEARNING_PROGRESS_FILE")

    echo -e "${GREEN}Learning progress${NC}"
    echo "Progress:  $(learning_progress_bar)"
    echo "XP:        $xp"
    echo "Streak:    $streak day(s)"
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
    echo "Badges:"
    if jq -e '(.badges // []) | length > 0' "$LEARNING_PROGRESS_FILE" >/dev/null; then
        jq -r '.badges[] | "  " + .' "$LEARNING_PROGRESS_FILE"
    else
        echo "  none yet"
    fi
    echo ""
    echo "Completed modules:"
    if [[ "$completed_count" -eq 0 ]]; then
        echo "  none yet"
    else
        jq -r '.completed[] | "  " + .' "$LEARNING_PROGRESS_FILE"
    fi
}

learning_recent_activity() {
    learning_ensure_progress
    echo -e "${GREEN}Recent learning activity${NC}"
    if jq -e '(.events // []) | length > 0' "$LEARNING_PROGRESS_FILE" >/dev/null; then
        jq -r '.events[] | "  " + .time + " | " + .module + " | " + .action + " | +" + (.xp|tostring) + " XP" + (if .badge == "" then "" else " | " + .badge end)' "$LEARNING_PROGRESS_FILE"
    else
        echo "  No activity yet."
    fi
}

learning_start() {
    local module=${1:-}
    learning_require_content
    learning_ensure_progress

    if [[ -z "$module" || "$module" == "next" ]]; then
        module=$(learning_current_module)
        [[ -z "$module" ]] && module=$(learning_next_module)
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
    local temp_file
    now=$(date '+%Y-%m-%d %H:%M:%S')
    temp_file=$(mktemp)
    jq --arg module "$module" --arg ts "$now" \
        '.current = $module | .last_started_at = $ts' \
        "$LEARNING_PROGRESS_FILE" > "$temp_file"
    mv "$temp_file" "$LEARNING_PROGRESS_FILE"

    learning_record_activity "$module" "started mission" "$(learning_module_xp "$module" "start")" "started-$module"

    echo -e "${GREEN}Mission unlocked: $module - $(learning_module_title "$module")${NC}"
    echo "Level: $(learning_module_level "$module")"
    echo ""
    echo "Goal"
    echo "  $(learning_module_goal "$module")"
    echo ""
    echo "Challenge"
    echo "  $(learning_module_challenge "$module")"
    echo ""
    echo "Recommended tools"
    echo "  $(learning_module_tools "$module")"
    echo ""
    echo "Mission steps"
    local step_index=1
    while IFS= read -r step; do
        echo "  $step_index. $step"
        step_index=$((step_index + 1))
    done < <(learning_module_steps "$module")
    echo ""
    echo "Checkpoint"
    echo "  $(learning_module_checkpoint "$module")"
    echo ""
    echo "Suggested next commands"
    echo "  devman learn check $module"
    echo "  devman learn cheatsheet $module"
    echo "  devman learn lab $module"
    echo "  devman learn validate $module"
    echo "  devman learn quiz $module 5"
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
    local temp_file
    now=$(date '+%Y-%m-%d %H:%M:%S')
    temp_file=$(mktemp)
    jq --arg module "$module" --arg ts "$now" \
        '.completed = (((.completed // []) + [$module]) | unique)
         | .completed_at = ((.completed_at // {}) + {($module): $ts})
         | if .current == $module then .current = "" else . end' \
        "$LEARNING_PROGRESS_FILE" > "$temp_file"
    mv "$temp_file" "$LEARNING_PROGRESS_FILE"

    learning_record_activity "$module" "completed module" "$(learning_module_xp "$module" "complete")" "$(learning_module_badge "$module" "complete")"

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
    learning_require_content
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
            [[ "$start_day" -gt "$days" ]] && break
        done
    fi
    echo "--------------------------------------------------------------------------------"
    echo "Daily rhythm: read 20m, build 60m, troubleshoot 20m, write notes 10m."
    echo "Weekly rhythm: validate one lab and explain the tradeoffs in your notes."
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

learning_copy_tree() {
    local src=$1
    local dest=$2
    local file
    local rel
    local target

    mkdir -p "$dest"
    while IFS= read -r -d '' file; do
        rel="${file#$src/}"
        target="$dest/$rel"
        if learning_write_file_allowed "$target"; then
            cp "$file" "$target"
            [[ "$target" == *.sh ]] && chmod +x "$target"
        fi
    done < <(find "$src" -type f -print0)
    return 0
}

learning_print_lab_next_steps() {
    local module=$1
    local lab_dir=$2
    local lab_arg
    local lab_abs="$lab_dir"
    local lab_abs_arg

    printf -v lab_arg '%q' "$lab_dir"
    if [[ -d "$lab_dir" ]]; then
        lab_abs=$(cd "$lab_dir" && pwd -P)
    fi
    printf -v lab_abs_arg '%q' "$lab_abs"

    echo ""
    echo "Lab map"
    echo "  Folder: $lab_abs"
    echo "  Read:   $lab_arg/README.md"
    echo ""

    if jq -e --arg module "$module" \
        '.modules[] | select(.id == $module) | (.lab_next // []) | length > 0' \
        "$LEARNING_DATA_FILE" >/dev/null; then
        echo "Suggested path"
        local step
        local step_index=1
        while IFS= read -r step; do
            step="${step//\{dir\}/$lab_arg}"
            step="${step//\{abs_dir\}/$lab_abs_arg}"
            printf "  %s. %s\n" "$step_index" "$step"
            step_index=$((step_index + 1))
        done < <(jq -r --arg module "$module" \
            '.modules[] | select(.id == $module) | (.lab_next // [])[]' \
            "$LEARNING_DATA_FILE")
    else
        echo "Suggested path"
        echo "  1. cd $lab_arg"
        echo "  2. cat README.md"
        echo "  3. devman learn validate $module ."
    fi

    echo ""
    echo "Cheat sheet"
    echo "  devman learn cheatsheet $module"
    echo ""
    echo "Validation"
    echo "  From this directory: devman learn validate $module $lab_arg"
    echo "  From inside the lab: devman learn validate $module ."
    echo ""
    echo "Note: If you saw 'Keeping existing file', DevMan protected files you already edited."
}

learning_cheatsheet() {
    local module=${1:-}
    local file

    learning_require_content
    learning_ensure_progress

    if [[ -z "$module" || "$module" == "current" ]]; then
        module=$(learning_current_module)
        [[ -z "$module" ]] && module=$(learning_next_module)
    fi
    [[ -z "$module" ]] && module="flow"

    if [[ "$module" == "flow" || "$module" == "help" ]]; then
        file="$LEARNING_CONTENT_DIR/cheatsheets/learning-flow.md"
    elif [[ "$module" == "all" || "$module" == "list" ]]; then
        echo -e "${GREEN}Available cheat sheets${NC}"
        echo "  flow"
        local known
        for known in "${LEARNING_MODULES[@]}"; do
            echo "  $known"
        done
        echo ""
        echo "Run: devman learn cheatsheet docker"
        return 0
    else
        if ! learning_module_valid "$module"; then
            echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
            exit 1
        fi
        file="$LEARNING_CONTENT_DIR/cheatsheets/$module.md"
    fi

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: cheat sheet not found at $file.${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Cheat sheet: $module${NC}"
    echo "--------------------------------------------------------------------------------"
    cat "$file"
    echo ""
    echo "--------------------------------------------------------------------------------"
    if [[ "$module" != "flow" && "$module" != "help" ]]; then
        echo "Next commands:"
        echo "  devman learn lab $module"
        echo "  devman learn validate $module ."
        echo "  devman learn quiz $module 5"
    else
        echo "Next command: devman learn start"
    fi
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
4. Validate the lab with `devman learn validate <module> labs/<module>`.
5. Capture notes in `notes/`.
6. Run `devman learn quiz <module>`.
7. Mark completion with `devman learn complete <module>`.

## Portfolio Rule

Every module should leave behind a small artifact: a script, manifest, pipeline,
runbook, diagram, or README explaining what you built and how you debugged it.
LABEOF
    fi

    if learning_write_file_allowed "$root/notes/learning-journal.md"; then
        cat << 'LABEOF' > "$root/notes/learning-journal.md"
# Learning Journal

## Today

- Module:
- XP gained:
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

    learning_ensure_progress
    local temp_file
    temp_file=$(mktemp)
    jq --arg root "$root" '.lab_root = $root' "$LEARNING_PROGRESS_FILE" > "$temp_file"
    mv "$temp_file" "$LEARNING_PROGRESS_FILE"

    echo -e "${GREEN}Created DevOps learning workspace at: $root${NC}"
    echo "Next: cd $root && devman learn start"
    log_message "Initialized learning workspace at $root" "SUCCESS"
}

learning_create_lab() {
    local module=$1
    local lab_dir=${2:-}

    learning_require_content
    if [[ -z "$module" ]]; then
        echo -e "${RED}Usage: devman learn lab <module> [directory]${NC}" >&2
        exit 1
    fi
    if ! learning_module_valid "$module"; then
        echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
        exit 1
    fi

    [[ -z "$lab_dir" ]] && lab_dir="devman-lab-$module"

    local template_dir="$LEARNING_CONTENT_DIR/labs/$module"
    if [[ -d "$template_dir" ]]; then
        learning_copy_tree "$template_dir" "$lab_dir"
    else
        mkdir -p "$lab_dir"
        if learning_write_file_allowed "$lab_dir/README.md"; then
            {
                echo "# $(learning_module_title "$module")"
                echo ""
                echo "$(learning_module_challenge "$module")"
                echo ""
                echo "## Steps"
                local step_index=1
                while IFS= read -r step; do
                    echo "$step_index. $step"
                    step_index=$((step_index + 1))
                done < <(learning_module_steps "$module")
            } > "$lab_dir/README.md"
        fi
    fi

    learning_record_activity "$module" "created lab" 0 ""
    echo -e "${GREEN}Created $module lab at: $lab_dir${NC}"
    learning_print_lab_next_steps "$module" "$lab_dir"
    log_message "Created learning lab '$module' at $lab_dir" "SUCCESS"
}

learning_create_project() {
    local target=${1:-devops-capstone-platform}
    local template_dir="$LEARNING_CONTENT_DIR/templates/capstone-platform"

    if [[ ! -d "$template_dir" ]]; then
        echo -e "${RED}Error: capstone project template not found at $template_dir.${NC}" >&2
        exit 1
    fi

    learning_copy_tree "$template_dir" "$target"
    learning_record_activity "capstone" "created capstone project" 10 "project-capstone"
    echo -e "${GREEN}Created capstone project at: $target${NC}"
    echo "Next: cd $target && docker build -t capstone-web:local ."
}

learning_validate_lab() {
    local module=$1
    local lab_dir=${2:-}
    local missing=0
    local warnings=0

    learning_require_content
    if [[ -z "$module" ]]; then
        echo -e "${RED}Usage: devman learn validate <module> [directory]${NC}" >&2
        exit 1
    fi
    if ! learning_module_valid "$module"; then
        echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
        exit 1
    fi

    [[ -z "$lab_dir" ]] && lab_dir="devman-lab-$module"

    echo -e "${GREEN}Validating $module lab${NC}"
    echo "Lab directory: $lab_dir"
    echo "------------------------------------------------------------"

    if [[ ! -d "$lab_dir" ]]; then
        echo -e "${RED}Missing lab directory: $lab_dir${NC}"
        echo "Create it with: devman learn lab $module $lab_dir"
        return 1
    fi

    echo "Tools:"
    while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        if command -v "$tool" >/dev/null 2>&1; then
            printf "  %-18s %s\n" "$tool" "ok"
        else
            printf "  %-18s %s\n" "$tool" "missing"
            missing=$((missing + 1))
        fi
    done < <(jq -r --arg module "$module" '.modules[] | select(.id == $module) | (.validation.required_tools // [])[]' "$LEARNING_DATA_FILE")

    echo ""
    echo "Required files:"
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ -f "$lab_dir/$file" ]]; then
            printf "  %-35s %s\n" "$file" "ok"
        else
            printf "  %-35s %s\n" "$file" "missing"
            missing=$((missing + 1))
        fi
    done < <(jq -r --arg module "$module" '.modules[] | select(.id == $module) | (.validation.required_files // [])[]' "$LEARNING_DATA_FILE")

    echo ""
    echo "Optional evidence:"
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ -f "$lab_dir/$file" ]]; then
            printf "  %-35s %s\n" "$file" "found"
        else
            printf "  %-35s %s\n" "$file" "not yet"
            warnings=$((warnings + 1))
        fi
    done < <(jq -r --arg module "$module" '.modules[] | select(.id == $module) | (.validation.optional_files // [])[]' "$LEARNING_DATA_FILE")

    echo "------------------------------------------------------------"
    if [[ "$missing" -eq 0 ]]; then
        echo -e "${GREEN}Validation passed. Required tools and files are ready.${NC}"
        [[ "$warnings" -gt 0 ]] && echo -e "${YELLOW}Optional evidence still has $warnings item(s) to fill in.${NC}"
        learning_record_activity "$module" "validated lab" "$(learning_module_xp "$module" "validate")" "$(learning_module_badge "$module" "validate")"
    else
        echo -e "${YELLOW}Validation found $missing missing required item(s).${NC}"
        echo "Fix those, then rerun: devman learn validate $module $lab_dir"
        return 1
    fi
}

learning_check() {
    local module=${1:-all}
    local tools=""

    learning_require_content
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
    learning_require_content
    echo -e "${GREEN}DevOps learning tool map${NC}"
    echo "--------------------------------------------------------------------------------"
    printf "%-15s %-13s %s\n" "MODULE" "LEVEL" "TOOLS"
    echo "--------------------------------------------------------------------------------"
    local module
    for module in "${LEARNING_MODULES[@]}"; do
        printf "%-15s %-13s %s\n" "$module" "$(learning_module_level "$module")" "$(learning_module_tools "$module")"
    done
    echo "--------------------------------------------------------------------------------"
    echo "DevMan can install registry tools with: devman install <tool> latest"
    echo "External tools such as git, docker, ansible, and cloud CLIs may need OS-specific setup."
}

learning_quiz() {
    local module=${1:-}
    local requested_count=${2:-5}
    if [[ -z "$module" ]]; then
        module=$(learning_next_module)
    fi
    [[ -z "$module" ]] && module="capstone"
    if ! learning_module_valid "$module"; then
        echo -e "${RED}Error: Unknown learning module '$module'.${NC}" >&2
        exit 1
    fi
    if ! [[ "$requested_count" =~ ^[0-9]+$ ]] || [[ "$requested_count" -lt 1 ]]; then
        echo -e "${RED}Usage: devman learn quiz [module] [positive_count]${NC}" >&2
        exit 1
    fi

    learning_require_content
    local quiz_rows=()
    mapfile -t quiz_rows < <(jq -c --arg module "$module" '.modules[] | select(.id == $module) | (.quiz // [])[]' "$LEARNING_DATA_FILE")
    local total=${#quiz_rows[@]}
    if [[ "$total" -eq 0 ]]; then
        echo -e "${RED}Error: No quiz questions found for '$module'.${NC}" >&2
        exit 1
    fi

    local question_count=$requested_count
    [[ "$question_count" -gt "$total" ]] && question_count=$total

    local indices=()
    local i
    for ((i = 0; i < total; i++)); do
        indices+=("$i")
    done
    for ((i = total - 1; i > 0; i--)); do
        local j=$((RANDOM % (i + 1)))
        local tmp="${indices[i]}"
        indices[i]="${indices[j]}"
        indices[j]="$tmp"
    done

    echo -e "${GREEN}Quiz: $module - $(learning_module_title "$module")${NC}"
    echo "Answer with a, b, or c. Each run pulls a random set from $total questions."
    echo ""

    local score=0
    local answer
    local answer_key=()
    local row
    local question
    local correct
    local explanation

    for ((i = 0; i < question_count; i++)); do
        row="${quiz_rows[indices[i]]}"
        question=$(jq -r '.question' <<< "$row")
        correct=$(jq -r '.answer' <<< "$row")
        explanation=$(jq -r '.explanation' <<< "$row")
        correct="${correct,,}"

        echo "$((i + 1))) $question"
        if ! read -r -p "Answer: " answer; then answer=""; fi
        answer="${answer,,}"
        answer="${answer:0:1}"

        if [[ "$answer" == "$correct" ]]; then
            score=$((score + 1))
            echo -e "${GREEN}Correct.${NC} $explanation"
        else
            echo -e "${YELLOW}Not quite.${NC} Correct answer: $correct. $explanation"
        fi
        answer_key+=("$((i + 1))=$correct")
        echo ""
    done

    echo "Score: $score / $question_count"
    if [[ "$score" -eq "$question_count" ]]; then
        learning_record_activity "$module" "passed quiz" "$(learning_module_xp "$module" "quiz")" "$(learning_module_badge "$module" "quiz")"
        echo -e "${GREEN}Passed. XP and badge updated. You can mark it complete with: devman learn complete $module${NC}"
    else
        echo -e "${YELLOW}Keep going: redo one lab step, then run the quiz again for a fresh set.${NC}"
        echo "Answer key: ${answer_key[*]}"
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
        activity|events)
            learning_recent_activity
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
        validate)
            learning_validate_lab "${1:-}" "${2:-}"
            ;;
        cheatsheet|cheat|cs)
            learning_cheatsheet "${1:-}"
            ;;
        project|template|capstone-project)
            learning_create_project "${1:-devops-capstone-platform}"
            ;;
        check|doctor)
            learning_check "${1:-all}"
            ;;
        tools)
            learning_tools
            ;;
        quiz)
            learning_quiz "${1:-}" "${2:-5}"
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
