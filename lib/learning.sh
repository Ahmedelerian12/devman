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
    echo "  quiz [module] [count]    Run a randomized interactive quiz"
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

learning_module_steps() {
    case "$1" in
        linux)
            cat << 'EOF'
1. Map the system: print OS, kernel, disk, memory, PATH, and current user.
2. Investigate a port: list listening sockets and identify the owning process.
3. Trace a request: resolve a hostname, curl it, and explain each failure mode.
4. Practice permissions: create a file, change modes, and explain owner/group/other.
5. Write a mini incident note: symptom, checks, cause, fix, and prevention.
EOF
            ;;
        git)
            cat << 'EOF'
1. Create a repo map: branches, remotes, recent commits, and tags.
2. Run a feature branch mission: two commits, one review-ready diff, one clean merge.
3. Practice recovery: revert a commit and explain why it is safer than rewriting shared history.
4. Tag a release and write a tiny changelog.
5. Draw your team workflow: branch names, PR checks, merge rules, and rollback path.
EOF
            ;;
        shell)
            cat << 'EOF'
1. Write a script with strict mode and readable logging.
2. Validate required commands before doing work.
3. Parse JSON with jq and fail clearly when data is missing.
4. Add command-line arguments and a help message.
5. Test success and failure paths, then capture the expected exit codes.
EOF
            ;;
        docker)
            cat << 'EOF'
1. Build a tiny web image and tag it with a learning version.
2. Run it locally, inspect logs, exec into the container, and find the served files.
3. Add Compose so the app starts with one command.
4. Break one thing on purpose, read the error, and fix it.
5. Record build, run, debug, and cleanup commands in the lab README.
EOF
            ;;
        kubernetes)
            cat << 'EOF'
1. Start a local cluster and confirm kubectl context.
2. Apply Deployment and Service manifests.
3. Inspect pods, events, rollout status, and logs.
4. Scale replicas, restart the rollout, then roll back a bad image tag.
5. Port-forward the service and write a troubleshooting runbook.
EOF
            ;;
        terraform)
            cat << 'EOF'
1. Run init, fmt, validate, and plan before applying anything.
2. Apply a small local resource and inspect outputs.
3. Inspect state and explain what Terraform is tracking.
4. Change an input variable and compare the new plan.
5. Destroy cleanly and write down the safe workflow order.
EOF
            ;;
        ansible)
            cat << 'EOF'
1. Create a localhost inventory and run a simple playbook.
2. Add variables and template or copy a config artifact.
3. Run the playbook twice and prove idempotency.
4. Add a handler or conditional task.
5. Document what changed, what stayed unchanged, and why.
EOF
            ;;
        cicd)
            cat << 'EOF'
1. Define pipeline stages: lint, test, build, scan, package, deploy.
2. Add a minimal workflow file for pull requests and pushes.
3. Make one check fail, read the log, and fix the cause.
4. Add an artifact or image build placeholder.
5. Write promotion rules: what must pass before release.
EOF
            ;;
        observability)
            cat << 'EOF'
1. List the signals your sample app should emit: logs, metrics, traces.
2. Start a local metrics stack or inspect Kubernetes/container logs.
3. Write three useful queries or log filters.
4. Draft one alert with impact, owner, and first checks.
5. Turn the alert into a runbook with recovery and prevention steps.
EOF
            ;;
        security)
            cat << 'EOF'
1. Review a Dockerfile for root user, broad permissions, and floating tags.
2. Scan IaC for risky defaults and missing constraints.
3. Write a secrets rule: where secrets live and where they never go.
4. Add one security check to a CI/CD pipeline.
5. Explain the risk, fix, and verification for each issue you find.
EOF
            ;;
        cloud)
            cat << 'EOF'
1. Sketch a small environment: network, identity, runtime, storage, monitoring.
2. Choose one cloud provider and map each component to a managed service.
3. Define least-privilege roles and tagging rules.
4. Add backup, cost, and incident-response notes.
5. Convert the design into an IaC-ready checklist.
EOF
            ;;
        capstone)
            cat << 'EOF'
1. Pick a tiny service and make it run locally.
2. Containerize it and document build/run/debug commands.
3. Deploy it to Kubernetes with health checks.
4. Add CI validation and release notes.
5. Finish with architecture notes, runbook, rollback, and next improvements.
EOF
            ;;
    esac
}

learning_module_checkpoint() {
    case "$1" in
        linux) echo "You can explain what is running, what is listening, and why a request succeeds or fails." ;;
        git) echo "You can move from change to reviewed commit to release tag to safe rollback." ;;
        shell) echo "Your script fails loudly, exits correctly, and helps the next human debug it." ;;
        docker) echo "You can build, run, inspect, break, fix, and clean up a containerized app." ;;
        kubernetes) echo "You can deploy, observe, scale, roll out, and recover a local workload." ;;
        terraform) echo "You can predict changes with a plan, apply safely, inspect state, and destroy cleanly." ;;
        ansible) echo "You can run a repeatable playbook and prove the second run is stable." ;;
        cicd) echo "You can explain every pipeline gate and what evidence it produces." ;;
        observability) echo "Your alert points to action, and your runbook helps someone recover calmly." ;;
        security) echo "You can name the risk, apply the fix, and verify the control." ;;
        cloud) echo "Your cloud design has identity, network, cost, backup, and operations guardrails." ;;
        capstone) echo "Your project tells a complete story from code to deployment to operations." ;;
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
    local tracking_enabled=0
    if command -v jq >/dev/null 2>&1; then
        learning_ensure_progress
        tracking_enabled=1
    fi

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

    if [[ "$tracking_enabled" -eq 1 ]]; then
        local now
        now=$(date '+%Y-%m-%d %H:%M:%S')
        local temp_file
        temp_file=$(mktemp)
        jq --arg module "$module" --arg ts "$now" \
            '.current = $module | .last_started_at = $ts' \
            "$LEARNING_PROGRESS_FILE" > "$temp_file"
        mv "$temp_file" "$LEARNING_PROGRESS_FILE"
    else
        echo -e "${YELLOW}Progress tracking disabled until jq is installed. Showing the guide anyway.${NC}"
        echo ""
    fi

    echo -e "${GREEN}Mission unlocked: $module - $(learning_module_title "$module")${NC}"
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
    learning_module_steps "$module" | sed 's/^/  /'
    echo ""
    echo "Checkpoint"
    echo "  $(learning_module_checkpoint "$module")"
    echo ""
    echo "How to move through this module"
    echo "  1. Check tools before building anything."
    echo "  2. Generate the lab and read its README."
    echo "  3. Run one command at a time and write down what changed."
    echo "  4. Break one safe thing on purpose, then fix it from logs or output."
    echo "  5. Take the randomized quiz. If it stings a little, that is the useful part."
    echo ""
    echo "Suggested next commands"
    echo "  devman learn check $module"
    echo "  devman learn lab $module"
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

learning_quiz_bank() {
    local module=$1
    case "$module" in
        linux)
            cat << 'EOF'
Which command is best for checking listening TCP ports? a) chmod b) ss c) mkdir|b|ss shows sockets and listening ports; netstat can work on older systems.
What does exit code 0 usually mean? a) success b) warning c) failure|a|A zero exit code conventionally means the command succeeded.
Which DNS record maps a name to an IPv4 address? a) MX b) A c) TXT|b|A records map names to IPv4 addresses; AAAA records map names to IPv6 addresses.
Which command changes file permissions? a) chmod b) dig c) ps|a|chmod changes permission bits such as read, write, and execute.
Which command shows running processes? a) ps b) tar c) jq|a|ps lists processes; top and htop are interactive alternatives.
What does curl -I request? a) headers only b) file permissions c) process tree|a|curl -I sends a HEAD request and shows response headers.
Where are many systemd service logs viewed? a) journalctl b) git log c) docker build|a|journalctl reads systemd journal logs.
Which command helps inspect disk usage by filesystem? a) df -h b) chmod c) ssh-keygen|a|df -h summarizes mounted filesystem usage in human-readable units.
EOF
            ;;
        git)
            cat << 'EOF'
Which command creates an annotated release marker? a) git tag -a b) git stash c) git fetch|a|Annotated tags are useful for releases because they carry metadata and a message.
Which command safely undoes a committed change by adding a new commit? a) git revert b) git reset --hard c) git clean|a|git revert preserves shared history by creating a new reversing commit.
What is a pull request mainly for? a) code review and merge discussion b) deleting branches c) installing packages|a|Pull requests organize review, discussion, checks, and merging.
Which command shows a compact branch graph? a) git log --oneline --graph --decorate --all b) git init --bare c) git rm -r .|a|That log view is a quick map of branches, tags, and commits.
Which command downloads remote refs without merging them? a) git fetch b) git commit c) git tag|a|git fetch updates remote-tracking refs while leaving your branch untouched.
What should you avoid on shared branches? a) rewriting published history casually b) opening pull requests c) reading diffs|a|Force rewriting shared history can disrupt teammates unless coordinated.
Which command shows unstaged and staged file changes? a) git status b) git clone c) git remote add|a|git status is the first quick safety check before committing.
What does .gitignore help with? a) keeping generated or secret files out of commits b) speeding up DNS c) running containers|a|.gitignore prevents matching untracked files from being suggested for commits.
EOF
            ;;
        shell)
            cat << 'EOF'
What does set -euo pipefail improve? a) script safety b) color output c) network speed|a|It catches failed commands, unset variables, and pipeline failures earlier.
Which tool is best for JSON parsing in shell scripts? a) jq b) tar c) ssh-keygen|a|jq parses JSON structurally instead of relying on fragile text matching.
Where should error messages usually go? a) stderr b) /dev/null always c) only README files|a|stderr separates errors from normal command output.
Which line makes a script executable as Bash when run directly? a) #!/usr/bin/env bash b) FROM alpine c) apiVersion: v1|a|The shebang tells the OS which interpreter to use.
Why quote variables like "$file"? a) preserve spaces and avoid glob surprises b) make output green c) install dependencies|a|Quoting prevents word splitting and unintended wildcard expansion.
Which construct checks whether a command exists? a) command -v tool b) chmod +x tool c) git tag tool|a|command -v reports how a command would be resolved.
What is a good script failure message? a) specific action and cause b) empty output c) only "no"|a|Useful failures tell the user what failed and what to check next.
Which variable stores the previous command status? a) $? b) $HOME c) $PATH|a|$? contains the exit status of the most recent command.
EOF
            ;;
        docker)
            cat << 'EOF'
Which file usually defines image build steps? a) Dockerfile b) deployment.yaml c) main.tf|a|Dockerfile instructions describe how to build a container image.
What does a container image contain? a) packaged filesystem and metadata b) only source code c) only logs|a|Images bundle filesystem layers plus metadata such as command and environment.
Which command shows container logs? a) docker logs b) git log c) terraform show|a|docker logs reads stdout and stderr captured for a container.
Which command builds an image from the current directory? a) docker build -t name . b) docker ps -a c) docker volume ls|a|docker build reads the Dockerfile and build context.
What does docker compose up do? a) starts services from a Compose file b) creates a Git branch c) applies Terraform state|a|Compose starts multi-container applications from compose.yaml.
Why prefer specific image tags over latest? a) repeatability b) prettier output c) fewer commands|a|Specific tags make builds and deployments easier to reproduce.
Which command opens a shell inside a running container? a) docker exec -it name sh b) docker tag c) docker login|a|docker exec runs a command inside an existing container.
What should docker compose down do? a) stop and remove the Compose app resources b) rebase commits c) validate YAML only|a|compose down cleans up containers and default networks for the project.
EOF
            ;;
        kubernetes)
            cat << 'EOF'
Which object keeps pods running at a desired replica count? a) Deployment b) Secret c) Namespace|a|Deployments manage ReplicaSets, which keep the desired number of pods running.
Which command shows recent cluster scheduling issues? a) kubectl get events b) docker build c) git tag|a|Events often explain scheduling, image pull, and probe failures.
Which Service type is commonly used for internal-only access? a) ClusterIP b) NodeName c) Dockerfile|a|ClusterIP exposes a service inside the cluster.
Which command follows logs from a pod? a) kubectl logs -f b) terraform plan c) git fetch|a|kubectl logs -f streams container logs.
What does a readiness probe control? a) whether a pod receives traffic b) Git tag signing c) Docker layer caching|a|Readiness probes tell Kubernetes if the container is ready for service traffic.
Which command checks rollout progress? a) kubectl rollout status b) kubectl config delete-context only c) helm repo add|a|rollout status reports Deployment rollout progress.
What happens when imagePullPolicy is Never? a) Kubernetes uses only local images b) Kubernetes always pulls c) Kubernetes deletes pods|a|Never tells the node not to pull the image from a registry.
Which command temporarily forwards a service to localhost? a) kubectl port-forward b) docker compose build c) ansible-playbook|a|port-forward is useful for local testing cluster services.
EOF
            ;;
        terraform)
            cat << 'EOF'
Which command previews infrastructure changes? a) terraform plan b) terraform fmt c) terraform output|a|plan shows proposed changes before apply.
What does Terraform state track? a) managed resource mappings b) shell aliases c) Git branches|a|State maps configuration resources to real infrastructure objects.
Which file commonly stores reusable input definitions? a) variables.tf b) Dockerfile c) inventory.ini|a|variables.tf is a common place for input variable blocks.
Which command formats Terraform files? a) terraform fmt b) terraform destroy c) terraform state rm|a|fmt applies standard Terraform formatting.
Why review a plan before apply? a) catch unexpected changes b) install kubectl c) create a Git tag|a|Plan review is the safety gate before changing infrastructure.
Which command initializes providers and backend? a) terraform init b) terraform output c) terraform console only|a|init downloads providers and configures backend state.
What should you do before deleting real infrastructure? a) understand the plan and backups b) ignore state c) delete .git|a|Destroy operations need deliberate review and recovery planning.
What is a module useful for? a) reusable infrastructure structure b) container logs c) DNS lookup only|a|Modules package reusable Terraform configuration.
EOF
            ;;
        ansible)
            cat << 'EOF'
What does idempotent mean? a) repeated runs converge safely b) every run must fail once c) no variables allowed|a|Idempotent tasks can run repeatedly without unnecessary changes.
Which file lists target hosts? a) inventory b) Dockerfile c) state file|a|Inventories define hosts and groups Ansible should manage.
Which format are playbooks usually written in? a) YAML b) PNG c) ZIP|a|Ansible playbooks are YAML documents.
Which command runs a playbook? a) ansible-playbook b) docker run c) git merge|a|ansible-playbook executes plays and tasks.
What is a handler commonly used for? a) restart a service only when notified b) create a Git branch c) pull container images only|a|Handlers run when tasks notify them after changes.
Why run a playbook twice in a lab? a) prove idempotency b) erase logs c) change branches|a|The second run should usually report no changes for stable tasks.
What do Ansible variables help with? a) reusable environment-specific values b) binary compression c) TCP routing|a|Variables let one playbook adapt to environments and hosts.
Which connection is useful for localhost labs? a) ansible_connection=local b) imagePullPolicy=Never c) git remote add|a|The local connection runs tasks on the control machine.
EOF
            ;;
        cicd)
            cat << 'EOF'
What is a pipeline gate? a) required check before promotion b) a Kubernetes pod c) a shell prompt|a|Gates prevent bad changes from moving forward.
Which event often triggers CI? a) push or pull request b) disk mount c) DNS lookup|a|CI commonly runs on pushes and pull requests.
What should a deployment pipeline be? a) repeatable and auditable b) manual only c) hidden from logs|a|Repeatability and auditability make releases safer.
Which stage should usually happen before packaging? a) tests b) production deploy c) deleting branches|a|Tests should fail fast before producing release artifacts.
Why keep pipeline logs readable? a) faster debugging b) smaller Docker images c) more DNS records|a|Clear logs shorten the feedback loop when a check fails.
What is an artifact? a) saved output from a pipeline job b) a Git conflict marker c) a port number|a|Artifacts can include build outputs, reports, or packages.
Which CI practice protects main branches? a) required passing checks b) committing secrets c) skipping reviews|a|Required checks block merges until validations pass.
What should a release job know? a) exact version and source commit b) only laptop name c) terminal color|a|Traceability links releases back to code and checks.
EOF
            ;;
        observability)
            cat << 'EOF'
What are the three common signals? a) logs metrics traces b) tags branches commits c) images layers ports|a|Logs, metrics, and traces are the core observability signals.
What should an alert include? a) action and impact b) only a vague title c) no owner|a|Good alerts tell responders what is wrong and what to do first.
What is a runbook for? a) repeatable incident response b) package installation only c) hiding errors|a|Runbooks guide diagnosis, recovery, and prevention.
Which signal is best for trends and thresholds? a) metrics b) chmod bits c) Git tags|a|Metrics are numeric time series suitable for thresholds and trends.
Which signal is best for a detailed event message? a) logs b) Terraform providers c) Docker tags|a|Logs capture event details and application messages.
What makes an alert noisy? a) low-action or low-signal firing b) clear ownership c) useful threshold|a|Noisy alerts fire without requiring meaningful action.
Why include user impact in a runbook? a) prioritize response b) format YAML c) build images|a|Impact helps responders decide urgency and communication.
What should you do after resolving an incident? a) write prevention notes b) delete all logs c) ignore the timeline|a|Post-incident learning improves systems and response.
EOF
            ;;
        security)
            cat << 'EOF'
Why avoid running containers as root? a) reduces blast radius b) makes images larger c) disables logs|a|A non-root runtime user limits damage if a process is compromised.
Where should secrets not be committed? a) source control b) a secret manager c) environment-specific vault|a|Secrets in Git history are hard to remove and easy to leak.
What is supply chain scanning for? a) dependency and image risk b) changing DNS records c) creating branches|a|Scanning finds vulnerable packages, images, and dependencies.
Why avoid chmod -R 777? a) over-broad permissions b) faster builds c) better logs|a|World-writable permissions increase tampering risk.
What is least privilege? a) only needed access b) admin for everyone c) public buckets by default|a|Least privilege gives identities only the permissions they need.
Why pin base image versions? a) repeatability and reviewability b) bigger images c) fewer tests|a|Pinned versions make changes intentional and auditable.
What should CI do when a high severity scan fails? a) block or require review b) hide the report c) commit the secret|a|Security findings need a clear gate or exception process.
What is a good secret-handling rule? a) use a manager and rotate leaks b) paste tokens into README c) print secrets in logs|a|Secrets belong in managed stores and must be rotated if exposed.
EOF
            ;;
        cloud)
            cat << 'EOF'
What is least privilege? a) only needed access b) admin for everyone c) public buckets by default|a|Cloud identities should receive only required permissions.
What should be tagged for cost control? a) cloud resources b) shell variables only c) Git commits only|a|Tags help allocate, search, and control cloud costs.
What belongs in a landing zone? a) network identity guardrails b) laptop wallpaper c) only app code|a|Landing zones establish foundations such as networking, identity, and policy.
Why separate public and private subnets? a) limit exposure b) speed up Git c) improve font rendering|a|Subnet boundaries help control network access.
What is a managed service tradeoff? a) less ops work but provider-specific constraints b) no monitoring needed c) no costs|a|Managed services reduce operations but still need design and governance.
Why define backup requirements early? a) recovery goals shape architecture b) Terraform refuses variables c) Docker needs it|a|RPO/RTO expectations affect storage, replication, and cost.
What should production cloud changes use? a) reviewed IaC and controlled rollout b) random console clicks only c) untracked scripts|a|Reviewed IaC improves repeatability and auditability.
What helps prevent surprise bills? a) budgets alerts and tags b) bigger instances c) public access|a|Cost guardrails catch spending changes before they grow.
EOF
            ;;
        capstone)
            cat << 'EOF'
What makes a capstone strong? a) integrated working workflow b) screenshots only c) no README|a|A strong capstone shows a working path from code to operations.
What should rollback notes describe? a) how to return to a known good version b) how to delete history c) how to ignore alerts|a|Rollback notes should be practical during pressure.
What should the portfolio README explain? a) architecture, commands, tradeoffs b) private secrets c) unrelated tasks|a|A portfolio README should help reviewers understand design and operation.
Which capstone evidence is strongest? a) commands, configs, and runbooks b) vague claims c) hidden files only|a|Concrete artifacts prove what you built and how it works.
What should health checks prove? a) the app is ready and alive b) Git has tags c) Terraform is formatted only|a|Health checks help platforms route traffic and restart unhealthy workloads.
Why include observability in the capstone? a) operations need signals after deploy b) it makes YAML shorter c) it replaces tests|a|Deployment is not complete until you can observe and respond.
What belongs in release notes? a) version, changes, risk, rollback b) secrets c) local passwords|a|Release notes connect changes to operational decisions.
How should you finish the capstone? a) document next improvements b) delete the repo c) skip verification|a|Next improvements show judgment and awareness of tradeoffs.
EOF
            ;;
    esac
}

learning_quiz() {
    local module=${1:-}
    local requested_count=${2:-5}
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

    if ! [[ "$requested_count" =~ ^[0-9]+$ ]] || [[ "$requested_count" -lt 1 ]]; then
        echo -e "${RED}Usage: devman learn quiz [module] [positive_count]${NC}" >&2
        exit 1
    fi

    local quiz_rows=()
    mapfile -t quiz_rows < <(learning_quiz_bank "$module")
    local total=${#quiz_rows[@]}
    if [[ "$total" -eq 0 ]]; then
        echo -e "${RED}Error: No quiz questions found for '$module'.${NC}" >&2
        exit 1
    fi

    local question_count=$requested_count
    if [[ "$question_count" -gt "$total" ]]; then
        question_count=$total
    fi

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
    local explanation
    local correct
    local question

    for ((i = 0; i < question_count; i++)); do
        IFS='|' read -r question correct explanation <<< "${quiz_rows[indices[i]]}"
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
        echo -e "${GREEN}Passed. You can mark it complete with: devman learn complete $module${NC}"
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
