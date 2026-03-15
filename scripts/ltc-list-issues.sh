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
curl -sk "${FORGEJO_API_BASE}/repos/${FORGEJO_ORG}/${REPO}/issues?state=open&type=issues&limit=50" \
  -H "Authorization: token ${FORGEJO_TOKEN}" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for i in data:
    labels = ",".join(l["name"] for l in i.get("labels", []))
    assignee = i.get("assignee", {})
    who = assignee.get("login", "未指派") if assignee else "未指派"
    print(f"#{i['"'"'number'"'"']} [{labels}] @{who} {i['"'"'title'"'"']}")
' 2>/dev/null
