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
curl -sk "${FORGEJO_API_BASE}/repos/${FORGEJO_ORG}/${REPO}/issues/${NUM}" \
  -H "Authorization: token ${FORGEJO_TOKEN}" | python3 -c '
import json, sys
i = json.load(sys.stdin)
labels = ", ".join(l["name"] for l in i.get("labels", []))
assignee = i.get("assignee", {})
who = assignee.get("login", "未指派") if assignee else "未指派"
user = i.get("user", {}).get("login", "")
print(f"#{i['"'"'number'"'"']} [{labels}] @{who} (發起人: {user})")
print(f"標題: {i['"'"'title'"'"']}")
print(f"狀態: {i['"'"'state'"'"']}")
print()
print(i.get("body", ""))
' 2>/dev/null
