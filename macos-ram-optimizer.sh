#!/usr/bin/env bash
set -euo pipefail

# ─── Config (overridable via env) ───────────────────────────────────────────
WORKSPACE="${WORKSPACE:-$HOME/agent-work}"
DRYRUN="${DRYRUN:-1}"

# ─── Colors (optional; disable if not a TTY) ───────────────────────────────
if [[ -t 1 ]]; then
  cyan="\033[36m"
  green="\033[32m"
  yellow="\033[33m"
  dim="\033[2m"
  bold="\033[1m"
  rev="\033[7m"
  reset="\033[0m"
else
  cyan="" green="" yellow="" dim="" bold="" rev="" reset=""
fi

# ─── Block-style ASCII banner (rectangle/block letters like get-shit-done) ──
draw_banner() {
  printf "\n"
  printf "${cyan}"
  # macOS (block font with █ ╔ ╗ ╚ ╝ ═ ║); O is hollow so it doesn’t look like S
  printf "  %b███╗   ███╗ █████╗  ██████╗  █████═╗███████╗%b\n" "$cyan" "$reset"
  printf "  %b██╔████╔██║██╔══██╗██╔════╝ ██║  ██║██╔════╝%b\n" "$cyan" "$reset"
  printf "  %b██║╚██╔╝██║███████║██║      ██║  ██║███████╗%b\n" "$cyan" "$reset"
  printf "  %b██║ ╚═╝ ██║██╔══██║██║      ██║  ██║╚════██║%b\n" "$cyan" "$reset"
  printf "  %b██║     ██║██║  ██║╚██████╗ ██║  ██║███████║%b\n" "$cyan" "$reset"
  printf "  %b╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚█████═╝╚══════╝%b\n" "$cyan" "$reset"
  printf "\n"
  # RAM (block style)
  printf "  %b██████╗  █████╗ ███╗   ███╗%b\n" "$cyan" "$reset"
  printf "  %b██╔══██╗██╔══██╗████╗ ████║%b\n" "$cyan" "$reset"
  printf "  %b██████╔╝███████║██╔████╔██║%b\n" "$cyan" "$reset"
  printf "  %b██╔══██╗██╔══██║██║╚██╔╝██║%b\n" "$cyan" "$reset"
  printf "  %b██║  ██║██║  ██║██║ ╚═╝ ██║%b\n" "$cyan" "$reset"
  printf "  %b╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝%b\n" "$cyan" "$reset"
  printf "\n  ${yellow}Optimizer${reset}\n"
  printf "${reset}\n"
}

# ─── Core logic (same as before) ───────────────────────────────────────────
say() { printf "\n==> %s\n" "$*"; }

mem_status() {
  say "Memory snapshot"
  if command -v memory_pressure >/dev/null 2>&1; then
    memory_pressure || true
  fi
  vm_stat | grep -E "Pages (free|active|inactive|speculative|wired|purgeable)|Swap" || true
  say "Top memory processes (RSS in MB)"
  ps -axo pid,rss,command | awk 'NR==1{print;next}{printf "%-7s %-10.1f %s\n",$1,$2/1024,$3}' \
    | sort -k2 -nr | head -n 20
}

unload_third_party_launch_items() {
  say "Looking for third-party LaunchAgents/Daemons"
  local plist base
  local candidates=()
  for plist in \
    "$HOME/Library/LaunchAgents/"*.plist \
    "/Library/LaunchAgents/"*.plist \
    "/Library/LaunchDaemons/"*.plist
  do
    [[ -e "$plist" ]] || continue
    base="$(basename "$plist")"
    [[ "$base" == com.apple.* ]] && continue
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
  osascript -e 'tell application "Docker" to if it is running then quit' >/dev/null 2>&1 || true
  if command -v colima >/dev/null 2>&1; then
    colima stop >/dev/null 2>&1 || true
  fi
}

run_action() {
  case "$1" in
    status)   mem_status ;;
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
    quit)     exit 0 ;;
    *)       echo "Unknown action: $1" ; exit 1 ;;
  esac
}

# ─── TUI: arrow-key menu ───────────────────────────────────────────────────
# Menu entries: label | action
MENU_LABELS=(
  "Memory status"
  "Enter (optimize: unload agents, disable Spotlight for workspace)"
  "Leave (re-enable Spotlight for workspace)"
  "Stop containers (Docker / Colima)"
  "Quit"
)
MENU_ACTIONS=( status enter leave stop-containers quit )

draw_menu() {
  local selected="$1"
  local i
  for i in "${!MENU_LABELS[@]}"; do
    if [[ "$i" -eq "$selected" ]]; then
      printf "  ${rev}  %s  ${reset}\n" "${MENU_LABELS[$i]}"
    else
      printf "  ${dim}  %s  ${reset}\n" "${MENU_LABELS[$i]}"
    fi
  done
  printf "\n  ${dim}↑/↓ move  Enter select${reset}\n"
}

# Read one key; output: up | down | enter | other
read_key() {
  local key key2
  read -rsn1 key
  if [[ "$key" == $'\x1b' ]]; then
    read -rsn2 key2
    case "$key2" in
      '[A') echo up   ;;
      '[B') echo down ;;
      *)    echo other ;;
    esac
  elif [[ "$key" == "" ]]; then
    echo enter
  else
    echo other
  fi
}

tui_main() {
  local selected=0
  local n=${#MENU_ACTIONS[@]}
  local k

  while true; do
    clear
    draw_banner
    printf "  ${bold}Select an option:${reset}\n\n"
    draw_menu "$selected"

    case "$(read_key)" in
      up)
        selected=$(( (selected - 1 + n) % n ))
        ;;
      down)
        selected=$(( (selected + 1) % n ))
        ;;
      enter)
        clear
        draw_banner
        printf "\n${green}Running: %s${reset}\n" "${MENU_LABELS[$selected]}"
        run_action "${MENU_ACTIONS[$selected]}"
        printf "\n${dim}Press any key to return to menu...${reset}"
        read -rsn1
        ;;
      *) ;;
    esac
  done
}

# ─── Entrypoint ─────────────────────────────────────────────────────────────
# If args given, run in CLI mode (original behavior). Otherwise run TUI.
if [[ $# -gt 0 ]]; then
  ACTION="${1:-status}"
  WORKSPACE="${2:-$WORKSPACE}"
  case "$ACTION" in
    status|enter|leave|stop-containers)
      run_action "$ACTION"
      ;;
    *)
      echo "Usage:"
      echo "  $0                    # TUI (interactive menu)"
      echo "  DRYRUN=1  $0 status"
      echo "  DRYRUN=0  $0 enter  /path/to/workspace"
      echo "            $0 leave  /path/to/workspace"
      echo "            $0 stop-containers"
      exit 1
      ;;
  esac
else
  if [[ ! -t 0 ]]; then
    echo "Stdin is not a TTY. Run with an action: $0 status"
    exit 1
  fi
  tui_main
fi
