# DevMan - Unified DevOps Tool Manager and Learning Automation

[![Platform Support](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20(GitBash)-blue)](https://github.com)
[![Release](https://img.shields.io/badge/Version-v4.1.0--Learning-green)](https://github.com)

**DevMan** is a lightweight shell utility designed to manage DevOps tools and automate DevOps learning from one unified location. It can download, verify, install, switch, and run versions of tools like **Terraform, kubectl, Helm, Stern, tflint, yq, k9s, minikube, and docker-compose** in user-space without requiring `sudo` privileges.

DevMan also includes a guided DevOps learning path with generated labs, progress tracking, readiness checks, quizzes, study plans, and a capstone workflow.

---

## Key Features

* **Interactive TUI Dashboard:** Run `devman` without arguments to launch a keyboard-driven terminal dashboard.
* **Version Switching and Pinning:** Install multiple versions of any tool side-by-side and activate them instantly.
* **Project-Level Environments:** Auto-switch tool versions when entering directories containing `.devman-version` or `.tool-versions`.
* **Release Verification:** Validate SHA256 checksums and optional vendor GPG signatures before execution.
* **Ad-Hoc Runner (`devman run`):** Run specific tool versions for single commands without changing the global active version.
* **Environment Lockfiles:** Export and import workspace setups using JSON lockfiles such as `devman.lock`.
* **Sample Bootstrapping:** Generate Terraform, Kubernetes, and Docker starter files.
* **DevOps Learning Automation:** Follow a built-in roadmap, generate hands-on labs, check local tools, run quizzes, and track progress.
* **Decoupled Registry:** Add, remove, or sync custom registry entries from the CLI.
* **Cache Pruning:** Remove unused tool versions to free disk space.

---

## Prerequisites

Make sure the following dependencies are installed on your host shell:

* `curl`
* `jq`
* `unzip` / `tar` for package extraction
* `gpg` for optional signature verification

---

## Installation

1. Clone this repository or copy the files to your local system.
2. Make the manager script executable:

   ```bash
   chmod +x devman.sh
   ```

3. Add the active binary directory (`~/.local/bin`) to your shell path:

   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

4. Enable shell auto-completion and directory change hooks:

   ```bash
   # Bash
   eval "$(path/to/devman.sh completion bash)"

   # Zsh
   eval "$(path/to/devman.sh completion zsh)"
   ```

### Clone and Run in WSL

Open your WSL terminal, then run:

```bash
sudo apt update
sudo apt install -y git curl jq unzip tar gpg

git clone https://github.com/Ahmedelerian12/devman.git
cd devman
chmod +x devman.sh

./devman.sh learn roadmap
```

To run DevMan as `devman` from any WSL directory:

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$PWD/devman.sh" "$HOME/.local/bin/devman"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"

devman learn roadmap
```

If WSL is not installed yet, run this from PowerShell first:

```powershell
wsl --install
```

Then restart your machine if Windows asks, open the new Linux terminal, and run the WSL commands above.

---

## Usage Guide

### 1. Interactive TUI Dashboard

Run DevMan with no arguments to open the upgraded terminal dashboard:

```bash
devman
```

The dashboard includes:

* **Tool manager** - install latest/specific versions, switch active versions, inspect installed versions, or uninstall cached versions.
* **Learning hub** - open the roadmap, start modules, create labs, run readiness checks, take quizzes, and generate study plans.
* **Bootstrap samples** - create Terraform, Kubernetes, or Docker Compose starter files.
* **Maintenance** - list tools, check updates, upgrade active tools, export/import lockfiles, prune cache, manage the registry, and view logs.
* **System status** - inspect DevMan paths, prerequisites, PATH setup, active tools, and learning progress.

Use `Up/Down` or `j/k` to move, `Enter` to select, number keys for shortcuts, and `q` or `Esc` to go back.

### 2. General CLI Commands

| Command | Description | Example |
| :--- | :--- | :--- |
| `list` | Show available registry tools and active versions | `devman list` |
| `install <tool> [version]` | Install a specific version, defaulting to latest | `devman install terraform 1.5.7` |
| `use <tool> <version>` | Manually switch the active version | `devman use terraform 1.5.7` |
| `run <tool>@<version> <args>` | Run an ad-hoc command using a cached version | `devman run terraform@1.5.0 plan` |
| `uninstall <tool> [version]` | Delete a version or the entire tool | `devman uninstall yq v4.34.1` |
| `prune` | Delete inactive tool versions | `devman prune` |
| `logs` | View the event execution audit trail | `devman logs` |

### 3. DevOps Learning Automation

Automate a complete DevOps learning path without leaving the terminal:

| Command | Description | Example |
| :--- | :--- | :--- |
| `learn roadmap` | Show the module roadmap and completion status | `devman learn roadmap` |
| `learn start [module]` | Start a module or the next unfinished module | `devman learn start docker` |
| `learn next` | Continue with the next unfinished module | `devman learn next` |
| `learn lab <module>` | Generate a hands-on practice lab | `devman learn lab kubernetes` |
| `learn check [module]` | Check required local tools and install hints | `devman learn check terraform` |
| `learn quiz [module]` | Run a short interactive knowledge check | `devman learn quiz docker` |
| `learn complete <module>` | Mark a module complete | `devman learn complete docker` |
| `learn progress` | Show current and completed modules | `devman learn progress` |
| `learn plan [days]` | Generate a paced study plan | `devman learn plan 45` |
| `learn init [dir]` | Create a full learning workspace | `devman learn init devops-learning-lab` |

The built-in roadmap is:

```text
linux -> git -> shell -> docker -> kubernetes -> terraform -> ansible
      -> cicd -> observability -> security -> cloud -> capstone
```

Progress is stored at `~/.devman/learning-progress.json`. Generated labs are starter templates; run the commands inside each lab only when your local tools are ready.

### 4. Workspace Lockfiles

Replicate development environments across your team:

```bash
devman export devman.lock
devman import devman.lock
```

### 5. Project Configuration

Create a `.devman-version` or `.tool-versions` file in your project directory:

```text
terraform 1.5.7
yq v4.34.1
```

When you enter the directory via `cd`, DevMan can automatically switch active tool links to those versions.

### 6. Registry CLI Management

```bash
devman registry add mytool github owner/repo
devman registry remove mytool
devman registry sync https://internal-api.corp/devman-registry.json
```

### 7. Interactive Bootstrap

Quickly bootstrap templates for new configurations:

```bash
devman bootstrap terraform   # Creates main.tf
devman bootstrap kubernetes  # Creates sample-k8s.yaml
devman bootstrap docker      # Creates docker-compose.yaml
```

---

## File Structure

* `devman.sh` - The core version manager and learning automation script.
* `registry.json` - Tool download patterns, checksum sources, and optional GPG verification rules.
* `~/.devman/versions/` - Tool version cache.
* `~/.devman/learning-progress.json` - Local DevOps learning progress state.
* `~/.devman/devman.log` - Text-file audit log.

---

## License

This project is licensed under the MIT License.
