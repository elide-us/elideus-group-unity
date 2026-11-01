#!/usr/bin/env bash
# dev.sh: the macOS/Linux twin of dev.cmd. Same verbs, same steps, same host and port.
set -u
# Go to script root
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

CMD="${1:-}"

help() {
  echo "Usage: dev [start|fast|test|client]"
  echo
  echo "  start   - Install deps, run tests, start uvicorn"
  exit 1
}

install_deps() {
  echo "Installing Python dependencies..."
  python3 -m pip install -r requirements.txt || return 1
  echo "Installing Python developer dependencies..."
  python3 -m pip install -r requirements-dev.txt || return 1
  return 0
}

do_start() {
  install_deps || exit 1
  echo
  echo "Starting Uvicorn on http://localhost:8000 ..."
  echo
  python3 -m uvicorn main:app --reload --host localhost
  exit $?
}

case "$(printf '%s' "$CMD" | tr '[:upper:]' '[:lower:]')" in
  start) do_start ;;
  *) help ;;
esac
