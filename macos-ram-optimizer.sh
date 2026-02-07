#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"               # status | enter | leave | stop-containers
WORKSPACE="${2:-$HOME/agent-work}"  # workspace path
DRYRUN="${DRYRUN:-1}"               # DRYRUN=0 to actually unload launch items

say() { printf "\n==> %s\n" "$*"; }

mem_status() {
  say "Memory snapshot"
  if command -v memory_pressure >/dev/null 2>&1; then
    memory_pressure || true
  fi
  vm_stat | egrep "Pages (free|active|inactive|speculative|wired|purgeable)|Swap" || true

  say "Top memory processes (RSS in MB)"
  ps -axo pid,rss,command | awk 'NR==1{print;next}{printf "%-7s %-10.1f %s\n",$1,$2/1024,$3}' \
    | sort -k2 -nr | head -n 20
}

# Unload only *non-Apple* launch items to avoid breaking the system
unload_third_party_launch_items() {
  say "Looking for third-party LaunchAgents/Daemons"

  local plist
  local candidates=()

  for plist in \
    "$HOME/Library/LaunchAgents/"*.plist \
    "/Library/LaunchAgents/"*.plist \
    "/Library/LaunchDaemons/"*.plist
  do
    [[ -e "$plist" ]] || continue
    local base
    base="$(basename "$plist")"
    # Skip Apple/system ones
    if [[ "$base" == com.apple.* ]]; then
      continue
    fi
    candidates+=("$plist")
  done

  if [[ ${#candidates[@]} -eq 0 ]]; then
    say "No third-party launch items found in standard folders."
    return
  fi

  printf "%s\n" "${candidates[@]}" | sed 's/^/ - /'

  if [[ "$DRYRUN" == "1" ]]; then
    say "DRYRUN=1 → not unloading. Run with DRYRUN=0 to apply."
    return
  fi

  say "Unloading third-party launch items (they may respawn if apps reinstall them)"
  local uid
  uid="$(id -u)"

  for plist in "${candidates[@]}"; do
    if [[ "$plist" == "$HOME/Library/LaunchAgents/"* ]]; then
      launchctl bootout "gui/$uid" "$plist" >/dev/null 2>&1 || true
    else
      sudo launchctl bootout system "$plist" >/dev/null 2>&1 || true
    fi
  done
}

spotlight_off_for_workspace() {
  say "Disabling Spotlight indexing for workspace: $WORKSPACE"
  mkdir -p "$WORKSPACE"
  sudo mdutil -i off "$WORKSPACE" >/dev/null || true
  sudo mdutil -E "$WORKSPACE" >/dev/null || true
}

spotlight_on_for_workspace() {
  say "Re-enabling Spotlight indexing for workspace: $WORKSPACE"
  sudo mdutil -i on "$WORKSPACE" >/dev/null || true
}

stop_containers() {
  say "Stopping containers"
  # Docker Desktop (if present)
  osascript -e 'tell application "Docker" to if it is running then quit' >/dev/null 2>&1 || true
  # Colima (if used)
  if command -v colima >/dev/null 2>&1; then
    colima stop >/dev/null 2>&1 || true
  fi
}

case "$ACTION" in
  status)
    mem_status
    ;;
  enter)
    mem_status
    unload_third_party_launch_items
    spotlight_off_for_workspace
    mem_status
    ;;
  leave)
    spotlight_on_for_workspace
    mem_status
    ;;
  stop-containers)
    stop_containers
    mem_status
    ;;
  *)
    echo "Usage:"
    echo "  DRYRUN=1  $0 status"
    echo "  DRYRUN=0  $0 enter  /path/to/workspace"
    echo "           $0 leave  /path/to/workspace"
    echo "           $0 stop-containers"
    exit 1
    ;;
esac