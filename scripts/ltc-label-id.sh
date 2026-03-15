#!/bin/bash
# ltc-label-id.sh <repo> <label-name>
# 依名稱查詢 label 的數字 ID，找不到時輸出錯誤並 exit 1
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
export LTC_LABEL_NAME="$2"
curl -sk "${FORGEJO_API_BASE}/repos/${FORGEJO_ORG}/${REPO}/labels" \
  -H "Authorization: token ${FORGEJO_TOKEN}" | python3 -c '
import json, sys, os
labels = json.load(sys.stdin)
target = os.environ["LTC_LABEL_NAME"]
for l in labels:
    if l["name"] == target:
        print(l["id"])
        sys.exit(0)
sys.stderr.write(f"Label not found: {target}\n")
sys.exit(1)
'
