#!/usr/bin/env bash
set -euo pipefail

LABEL="${LABEL:-com.okash1n.fwai.board}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
LOG_DIR="$ROOT_DIR/logs"
STDOUT_LOG="$LOG_DIR/board.launchd.out.log"
STDERR_LOG="$LOG_DIR/board.launchd.err.log"
DOMAIN="gui/$(id -u)"
BOARD_HOST="${BOARD_HOST:-127.0.0.1}"
BOARD_PORT="${BOARD_PORT:-8127}"

ensure_dirs() {
  mkdir -p "$PLIST_DIR" "$LOG_DIR"
}

write_plist() {
  ensure_dirs
  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ROOT_DIR/scripts/start_board.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OPEN_BROWSER</key>
    <string>0</string>
    <key>BOARD_HOST</key>
    <string>$BOARD_HOST</string>
    <key>BOARD_PORT</key>
    <string>$BOARD_PORT</string>
  </dict>
  <key>WorkingDirectory</key>
  <string>$ROOT_DIR</string>
  <key>RunAtLoad</key>
  <false/>
  <key>KeepAlive</key>
  <false/>
  <key>ProcessType</key>
  <string>Background</string>
  <key>StandardOutPath</key>
  <string>$STDOUT_LOG</string>
  <key>StandardErrorPath</key>
  <string>$STDERR_LOG</string>
</dict>
</plist>
EOF
}

is_loaded() {
  launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1
}

install_service() {
  write_plist
  if is_loaded; then
    launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
  fi
  launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
  echo "installed: $PLIST_PATH"
}

uninstall_service() {
  if is_loaded; then
    launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
  fi
  rm -f "$PLIST_PATH"
  echo "uninstalled: $LABEL"
}

start_service() {
  if [[ ! -f "$PLIST_PATH" ]] || ! is_loaded; then
    install_service
  fi
  launchctl kickstart -k "$DOMAIN/$LABEL"
  echo "started: $LABEL"
}

stop_service() {
  if is_loaded; then
    launchctl stop "$DOMAIN/$LABEL" || true
  fi
  echo "stopped: $LABEL"
}

status_service() {
  if is_loaded; then
    echo "loaded: yes ($DOMAIN/$LABEL)"
    launchctl print "$DOMAIN/$LABEL" | rg "state =|pid =|last exit code =|path =|program =" || true
  else
    echo "loaded: no ($DOMAIN/$LABEL)"
  fi
  echo "ports:"
  lsof -nP -iTCP:"$BOARD_PORT" -sTCP:LISTEN || true
}

show_logs() {
  local lines="${1:-120}"
  ensure_dirs
  echo "== $STDOUT_LOG =="
  if [[ -f "$STDOUT_LOG" ]]; then
    tail -n "$lines" "$STDOUT_LOG"
  else
    echo "(no stdout log yet)"
  fi
  echo "== $STDERR_LOG =="
  if [[ -f "$STDERR_LOG" ]]; then
    tail -n "$lines" "$STDERR_LOG"
  else
    echo "(no stderr log yet)"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./scripts/launchd_board.sh <command>

Commands:
  install     Write plist and bootstrap LaunchAgent
  uninstall   Stop and remove LaunchAgent plist
  start       Start board via launchd (installs if missing)
  stop        Stop running service
  restart     Stop then start
  status      Show launchd state and listening port
  logs [N]    Tail stdout/stderr logs (default 120 lines)
EOF
}

cmd="${1:-}"
case "$cmd" in
  install)
    install_service
    ;;
  uninstall)
    uninstall_service
    ;;
  start)
    start_service
    ;;
  stop)
    stop_service
    ;;
  restart)
    stop_service
    start_service
    ;;
  status)
    status_service
    ;;
  logs)
    show_logs "${2:-120}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
