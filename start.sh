#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROLE="${1:-}"

usage() {
  echo "用法: $0 <role> [chat]"
  echo "角色: all | app | data | dispatcher | docs | i18n | ops | qa | release | server | services | spec | ux"
  exit 1
}

[ -n "$ROLE" ] || usage
shift || true

TARGET="$SCRIPT_DIR/roles/${ROLE}.sh"
[ -x "$TARGET" ] || usage
exec "$TARGET" "$@"
