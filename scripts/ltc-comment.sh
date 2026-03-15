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
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN 未設定}"
REPO="$1"
NUM="$2"
BODY="$3"
PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"body":sys.argv[1]}))' "$BODY")
curl -sk -X POST "${FORGEJO_API_BASE}/repos/${FORGEJO_ORG}/${REPO}/issues/${NUM}/comments" \
  -H "Authorization: token ${FORGEJO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
