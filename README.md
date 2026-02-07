# macos-ram-optimizer

```text
  ███╗   ███╗ █████╗  ██████╗  █████═╗███████╗
  ██╔████╔██║██╔══██╗██╔════╝ ██║  ██║██╔════╝
  ██║╚██╔╝██║███████║██║      ██║  ██║███████╗
  ██║ ╚═╝ ██║██╔══██║██║      ██║  ██║╚════██║
  ██║     ██║██║  ██║╚██████╗ ██║  ██║███████║
  ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚█████═╝╚══════╝

  ██████╗  █████╗ ███╗   ███╗
  ██╔══██╗██╔══██╗████╗ ████║
  ██████╔╝███████║██╔████╔██║
  ██╔══██╗██╔══██║██║╚██╔╝██║
  ██║  ██║██║  ██║██║ ╚═╝ ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

              Optimizer
```

A lightweight **macOS RAM optimizer** script that helps free memory by unloading third-party launch agents/daemons, toggling Spotlight indexing for a workspace, and stopping containers (Docker / Colima). Includes an interactive TUI and a CLI mode.

---

## ✨ Features

- **Memory status** — View `memory_pressure`, `vm_stat`, and top memory-hungry processes
- **Enter optimization** — Unload third-party LaunchAgents/Daemons and disable Spotlight for a configurable workspace
- **Leave** — Re-enable Spotlight indexing for the workspace
- **Stop containers** — Quit Docker and stop Colima to reclaim RAM
- **Interactive TUI** — Arrow-key menu when run without arguments
- **Dry run by default** — No changes applied until you set `DRYRUN=0`

---

## 📋 Requirements

- **macOS** (uses `launchctl`, `mdutil`, `vm_stat`, etc.)
- **Bash** (script uses `set -euo pipefail` and arrays)
- **sudo** — Required for unloading system LaunchDaemons and toggling Spotlight

---

## 🚀 Usage

### Interactive menu (TUI)

Run the script with no arguments for the arrow-key menu:

```bash
./macos-ram-optimizer.sh
```

Use **↑/↓** to move, **Enter** to select an option.

### Command-line (CLI)

```bash
# Show memory status only (no changes)
./macos-ram-optimizer.sh status

# Enter optimization mode (unload agents, disable Spotlight for workspace)
# DRYRUN=1 (default): only shows what would be done
DRYRUN=1 ./macos-ram-optimizer.sh enter

# Actually apply changes (unload agents, disable Spotlight)
DRYRUN=0 ./macos-ram-optimizer.sh enter

# Optional: use a custom workspace path (default: ~/agent-work)
DRYRUN=0 ./macos-ram-optimizer.sh enter /path/to/your/workspace

# Leave: re-enable Spotlight for the workspace
./macos-ram-optimizer.sh leave
./macos-ram-optimizer.sh leave /path/to/workspace

# Stop Docker and Colima
./macos-ram-optimizer.sh stop-containers
```

### Environment variables

- **`WORKSPACE`** (default: `$HOME/agent-work`) — Directory for which Spotlight indexing is turned off in "enter" and back on in "leave".
- **`DRYRUN`** (default: `1`) — `1` = don't unload launch items (dry run). `0` = actually unload them.

---

## ⚠️ Notes

- **Third-party launch items** — Only items *outside* `com.apple.*` in `~/Library/LaunchAgents`, `/Library/LaunchAgents`, and `/Library/LaunchDaemons` are considered. They may be re-added by apps when you run them again.
- **Spotlight** — Disabling indexing for `WORKSPACE` can free memory and I/O; re-enable with `leave` when you’re done.
- **Containers** — "Stop containers" quits Docker (if running) and runs `colima stop` if Colima is installed.

---

## 📄 License

Use and modify as you like. No warranty.
