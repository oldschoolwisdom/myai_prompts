#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="$(cd "$AI_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/ltc-common.sh"
ltc_source_env "$AI_DIR/.env"
ltc_source_env "$WORK_DIR/.env"
ltc_init_project_env

ROLE="${1:-}"
KIND="${2:-}"

if [ -z "$ROLE" ] || [ -z "$KIND" ]; then
  echo "用法: $0 <role> <repo|account|token-var|prompt>" >&2
  exit 1
fi

case "$KIND" in
  repo)
    ltc_repo_for_role "$ROLE"
    ;;
  account)
    ltc_account_for_role "$ROLE"
    ;;
  token-var)
    ltc_token_var_for_role "$ROLE"
    ;;
  prompt)
    ltc_prompt_for_role "$ROLE"
    ;;
  *)
    echo "❌ 不支援的種類：$KIND" >&2
    exit 1
    ;;
esac
