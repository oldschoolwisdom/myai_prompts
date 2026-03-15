#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_DIR="$(cd "$AI_DIR/.." && pwd)"
ROLE="${1:-}"
MODE="${2:-}"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/ltc-common.sh"
ltc_source_env "$AI_DIR/.env"
ltc_init_project_env
API="$FORGEJO_API_BASE"

usage() {
  echo "用法: $0 <role> [chat]"
  echo "角色: spec | app | server | data | qa | docs | i18n | ux | ops | release | services | dispatcher"
  exit 1
}

case "$ROLE" in
  spec)       HAS_SPEC=false ;;
  app)        HAS_SPEC=true  ;;
  server)     HAS_SPEC=true  ;;
  data)       HAS_SPEC=true  ;;
  qa)         HAS_SPEC=true  ;;
  docs)       HAS_SPEC=true  ;;
  i18n)       HAS_SPEC=false ;;
  ux)         HAS_SPEC=true  ;;
  release)    HAS_SPEC=true  ;;
  ops)        HAS_SPEC=true  ;;
  services)   HAS_SPEC=false ;;
  dispatcher) HAS_SPEC=false ;;
  *) usage ;;
esac

if [ "$ROLE" = "dispatcher" ]; then
  ENV_FILE="$RUN_DIR/.env"
else
  ENV_FILE="$RUN_DIR/$ROLE/.env"
fi
if [ ! -f "$ENV_FILE" ]; then
  echo "找不到 ${ENV_FILE}，請先執行 setup.sh"
  exit 1
fi
ltc_source_env "$ENV_FILE"
ltc_init_project_env
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN 未設定}"
TOKEN="$FORGEJO_TOKEN"

if [ "$ROLE" = "dispatcher" ]; then
  ROLE_LABEL="dispatcher"
else
  ROLE_LABEL="$(ltc_account_for_role "$ROLE")"
fi

LOCK="/tmp/${PROJECT_SLUG}-${ROLE}.lock"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
  echo "${ROLE_LABEL} 已在執行中 (PID $(cat "$LOCK"))"
  exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

if [ "$ROLE" = "dispatcher" ]; then
  cd "$RUN_DIR"
else
  cd "$RUN_DIR/$ROLE"
  [ -d "code/.git" ] && ltc_git_pull_if_ready "code"
  $HAS_SPEC && [ -d "spec/.git" ] && ltc_git_pull_if_ready "spec"
  [ "$ROLE" = "services" ] && [ -d "docs/.git" ] && ltc_git_pull_if_ready "docs"
  [ "$ROLE" = "ux" ] && [ -d "app/.git" ] && ltc_git_pull_if_ready "app"
fi

RAW="${API}/repos/${FORGEJO_ORG}/${AI_REPO}/raw/prompts"
_fetch() { curl -sf -H "Authorization: token $TOKEN" "${RAW}/${1}?ref=main" 2>/dev/null; }
CONVENTIONS=$(_fetch conventions.md || cat "$AI_DIR/prompts/conventions.md")
PROMPT_FILE="$(ltc_prompt_for_role "$ROLE")"
if [ "$ROLE" = "dispatcher" ]; then
  ROLE_PROMPT="${CONVENTIONS}
$(_fetch dispatcher.md || cat "$AI_DIR/prompts/dispatcher.md")"
else
  ROLE_PROMPT="${CONVENTIONS}
$(_fetch "$PROMPT_FILE" || cat "$AI_DIR/prompts/${PROMPT_FILE}")"
fi

SUMMARY=""
if [ "$ROLE" = "dispatcher" ]; then
  REPOS=("$SPEC_REPO" "$APP_REPO" "$SERVER_REPO" "$DATA_REPO" "$QA_REPO" "$DOCS_REPO" "$I18N_REPO" "$UX_REPO" "$OPS_REPO" "$RELEASE_REPO" "$SERVICES_REPO")
  for repo in "${REPOS[@]}"; do
    [ -z "$repo" ] && continue
    ISSUES=$(curl -sfk "$API/repos/$FORGEJO_ORG/$repo/issues?state=open&limit=50" \
      -H "Authorization: token $TOKEN" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(0)
for i in data:
    labels = ",".join(l["name"] for l in i.get("labels", []))
    assignee = i.get("assignee", {})
    who = assignee.get("login", "未指派") if assignee else "未指派"
    print(f"  #{i['"'"'number'"'"']} {i['"'"'title'"'"']} [{labels}] @{who}")
' 2>/dev/null || true)
    [ -n "$ISSUES" ] && SUMMARY="${SUMMARY}[$repo]\n${ISSUES}\n"
  done
else
  NOTIF=$(curl -sfk "$API/notifications?status-types=unread" \
    -H "Authorization: token $TOKEN" 2>/dev/null || true)
  SUMMARY=$(echo "$NOTIF" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(0)
items = []
for n in data:
    s = n.get("subject", {})
    if s.get("state") != "closed":
        repo = n.get("repository", {}).get("name", "")
        items.append(f"[{repo}] {s.get('"'"'type'"'"','"'"''"'"')}: {s.get('"'"'title'"'"','"'"''"'"')}")
if items:
    print("\\n".join(items))
' 2>/dev/null || true)
fi

if [ "$MODE" != "chat" ] && [ -z "$SUMMARY" ]; then
  [ "$ROLE" = "dispatcher" ] && echo "dispatcher: 所有 repo 無 open issues" || echo "${ROLE_LABEL}: 無新任務"
  exit 0
fi

if [ -n "$SUMMARY" ]; then
  if [ "$ROLE" = "dispatcher" ]; then
    echo -e "dispatcher: 發現 open issues，啟動 AI..."
    INIT_PROMPT="${ROLE_PROMPT}

以下是各 repo open issues 狀態，請分析並建議下一步：
$(echo -e "$SUMMARY")"
  else
    COUNT=$(echo "$SUMMARY" | wc -l | tr -d ' ')
    echo "${ROLE_LABEL}: 發現 ${COUNT} 個待處理通知，啟動 AI..."
    INIT_PROMPT="${ROLE_PROMPT}

以下是未讀通知摘要，請處理：
${SUMMARY}"
  fi
else
  INIT_PROMPT="$ROLE_PROMPT"
fi

if [ "$ROLE" = "services" ] || [ "$ROLE" = "docs" ] || [ "$ROLE" = "i18n" ]; then
  MODEL="claude-haiku-4.5"
else
  MODEL="claude-sonnet-4.6"
fi

copilot --model "$MODEL" --allow-all-tools -i "$INIT_PROMPT"
