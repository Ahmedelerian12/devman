# DevMan - Unified DevOps Tool Manager

[![Platform Support](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20(GitBash)-blue)](https://github.com)
[![Release](https://img.shields.io/badge/Version-v4.0.0--Premium-green)](https://github.com)

**DevMan** is a lightweight, zero-dependency (except `curl` and `jq`) shell utility designed to manage all your DevOps tools from one unified location. It allows you to download, cryptographically verify (SHA256 & GPG), install, switch between multiple versions, and bootstrap configurations for tools like **Terraform, kubectl, Helm, Stern, tflint, yq, k9s, minikube, and docker-compose** in user-space without requiring `sudo` privileges.

---

## Key Features

*   🖥️ **Interactive TUI Dashboard:** Run `devman` without arguments to launch a keyboard-driven terminal dashboard.
*   🔄 **Version Switching & Pinning:** Install multiple versions of any tool side-by-side and activate them instantly.
*   📂 **Project-Level Environments:** Auto-switches tool versions upon entering directories containing a `.devman-version` or `.tool-versions` file.
*   🔒 **Enterprise Security:** Cryptographically validates SHA256 checksums and verifies vendor GPG signatures (e.g. HashiCorp's keys) before execution.
*   ⚡ **Ad-Hoc Runner (`devman run`):** Run specific versions of tools for single commands without affecting your global active version.
*   📦 **Environment Lockfiles:** Export and import workspace setups using standard JSON lockfiles (`devman.lock`).
*   🚀 **Sample Bootstrapping:** Instantly deploy Nginx/Redis compose files, Kubernetes pods, or local Terraform templates.
*   🛠️ **Decoupled Registry:** Easily add, remove, or sync custom registries via CLI commands.
*   🧹 **Cache Pruning:** Clean up unused tool versions to free up disk space.

---

## Pre-requisites

Make sure the following dependencies are installed on your host shell:
*   `curl`
*   `jq`
*   `unzip` / `tar` (for packages extraction)
*   `gpg` (optional, for signature verification)

---

## Installation

1.  Clone this repository or copy the files to your local system.
2.  Make the manager script executable:
    ```bash
    chmod +x devman.sh
    ```
3.  Add the active binary directory (`~/.local/bin`) to your shell path. Add this to your `~/.bashrc` or `~/.zshrc`:
    ```bash
    export PATH="$HOME/.local/bin:$PATH"
    ```
4.  Enable shell auto-completion and directory change hooks by adding this to your profile:
    ```bash
    # For Bash
    eval "$(path/to/devman.sh completion bash)"

    # For Zsh
    eval "$(path/to/devman.sh completion zsh)"
    ```

---

## Usage Guide

### 1. General CLI Commands

| Command | Description | Example |
| :--- | :--- | :--- |
| `list` | Show available registry tools and active versions | `devman list` |
| `install <tool> [version]` | Install a specific version (defaults to latest) | `devman install terraform 1.5.7` |
| `use <tool> <version>` | Manually switch the active version | `devman use terraform 1.5.7` |
| `run <tool>@<version> <args>` | Run ad-hoc command using cached version | `devman run terraform@1.5.0 plan` |
| `uninstall <tool> [version]` | Delete a version or the entire tool | `devman uninstall yq v4.34.1` |
| `prune` | Delete all inactive tool versions to save disk space | `devman prune` |
| `logs` | View the event execution audit trail | `devman logs` |

### 2. Workspace Lockfiles
Replicate development environments across your team:
*   **Export:** Create a lockfile mapping active tool versions:
    ```bash
    devman export devman.lock
    ```
*   **Import:** Restore identical tool versions from a lockfile:
    ```bash
    devman import devman.lock
    ```

### 3. Project Configuration (.devman-version)
Create a `.devman-version` or `.tool-versions` (ASDF style) file in your project directory:
```
terraform 1.5.7
yq v4.34.1
```
Upon entering this directory via `cd`, DevMan will automatically switch your active path links to these versions in the background.

### 4. Registry CLI Management
*   **Add a custom tool:**
    ```bash
    devman registry add mytool github owner/repo
    ```
*   **Remove a tool:**
    ```bash
    devman registry remove mytool
    ```
*   **Sync a shared team registry:**
    ```bash
    devman registry sync https://internal-api.corp/devman-registry.json
    ```

### 5. Interactive Bootstrap
Quickly bootstrap templates for new configurations:
```bash
devman bootstrap terraform   # Creates main.tf template
devman bootstrap kubernetes  # Creates sample-k8s.yaml deployment
devman bootstrap docker      # Creates docker-compose.yaml
```

---

## File Structure

*   `devman.sh` — The core version manager shell script.
*   `registry.json` — The JSON database containing download url structures, SHA256 and GPG verification rules.
*   `~/.devman/versions/` — Directory containing the tool version caches.
*   `~/.devman/devman.log` — Text-file auditing command executions.

---

## License

This project is licensed under the MIT License.
