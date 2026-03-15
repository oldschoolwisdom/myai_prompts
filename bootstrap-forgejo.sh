#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/ltc-common.sh"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 找不到 .env，請先建立："
  echo "   cp $SCRIPT_DIR/.env.example $ENV_FILE"
  exit 1
fi

ltc_source_env "$ENV_FILE"
ROLE_NAMES=(spec app server data qa docs i18n ux ops release services)
LABEL_SPECS=(
  'status: pending-review|#fbca04|Waiting for review'
  'status: in-progress|#1d76db|Work in progress'
  'status: pending-qa|#5319e7|Waiting for QA validation'
  'status: pending-confirmation|#0e8a16|Waiting for requester confirmation'
  'status: rejected|#d73a4a|Rejected or invalid request'
  'status: done|#0e8a16|Completed work'
  'type: request|#0052cc|Specification request'
  'type: bug|#b60205|Bug report'
)

declare -A EXISTING_REPOS=()
declare -A EXISTING_USERS=()

fail() {
  echo "❌ $*" >&2
  exit 1
}

preflight_commands() {
  local command_name
  for command_name in curl python3; do
    ltc_require_command "$command_name" || exit 1
  done
}

validate_unique_values() {
  local label="$1"
  shift

  local value
  declare -A seen=()
  for value in "$@"; do
    [ -n "$value" ] || fail "${label} 不可空白"
    if [ -n "${seen[$value]+x}" ]; then
      fail "${label} 不可重複：${value}"
    fi
    seen["$value"]=1
  done
}

preflight_env() {
  [ -w "$ENV_FILE" ] || fail ".env 無法寫入，bootstrap 需要回寫角色 token"

  ltc_require_first_nonempty ADMIN_TOKEN ADMIN_TOKEN LTC_ADMIN_TOKEN LR_ADMIN_TOKEN LS_ADMIN_TOKEN || exit 1
  ltc_require_first_nonempty FORGEJO_API_BASE FORGEJO_API_BASE || exit 1
  ltc_require_first_nonempty FORGEJO_ORG FORGEJO_ORG || exit 1
  ltc_require_first_nonempty PROJECT_NAME PROJECT_NAME || exit 1
  ltc_require_first_nonempty ROLE_TEAM_NAME ROLE_TEAM_NAME || exit 1
  ltc_assign_first_nonempty PROJECT_SLUG PROJECT_SLUG FORGEJO_ORG PROJECT_NAME
  PROJECT_SLUG="$(ltc_normalize_identifier "$PROJECT_SLUG")"
  [ -n "$PROJECT_SLUG" ] || fail "PROJECT_SLUG / PROJECT_NAME 無法轉成有效識別字"
  : "${ROLE_ACCOUNT_PREFIX:=${PROJECT_SLUG}}"
  : "${ROLE_ACCOUNT_SEPARATOR:--}"
  ltc_require_first_nonempty ROLE_EMAIL_DOMAIN ROLE_EMAIL_DOMAIN || exit 1
  ltc_require_first_nonempty ROLE_TOKEN_NAME ROLE_TOKEN_NAME || exit 1
  ltc_require_first_nonempty ROLE_VISIBILITY ROLE_VISIBILITY || exit 1
  ltc_require_first_nonempty ROLE_PASSWORD_LENGTH ROLE_PASSWORD_LENGTH || exit 1

  ltc_require_first_nonempty AI_REPO AI_REPO LTC_AI_REPO LR_AI_REPO LS_AI_REPO || exit 1
  ltc_require_first_nonempty SPEC_REPO SPEC_REPO LTC_SPEC_REPO LR_SPEC_REPO LS_SPEC_REPO || exit 1
  ltc_require_first_nonempty APP_REPO APP_REPO LTC_APP_REPO LR_APP_REPO LS_APP_REPO || exit 1
  ltc_require_first_nonempty SERVER_REPO SERVER_REPO LTC_SERVER_REPO LR_SERVER_REPO LS_SERVER_REPO || exit 1
  ltc_require_first_nonempty DATA_REPO DATA_REPO LTC_DATA_REPO LR_DATA_REPO LS_DATA_REPO || exit 1
  ltc_require_first_nonempty QA_REPO QA_REPO LTC_QA_REPO LR_QA_REPO LS_QA_REPO || exit 1
  ltc_require_first_nonempty DOCS_REPO DOCS_REPO LTC_DOCS_REPO LR_DOCS_REPO LS_DOCS_REPO || exit 1
  ltc_require_first_nonempty I18N_REPO I18N_REPO LTC_I18N_REPO LR_I18N_REPO LS_I18N_REPO || exit 1
  ltc_require_first_nonempty UX_REPO UX_REPO LTC_UX_REPO LR_UX_REPO LS_UX_REPO || exit 1
  ltc_require_first_nonempty OPS_REPO OPS_REPO LTC_OPS_REPO LR_OPS_REPO LS_OPS_REPO || exit 1
  ltc_require_first_nonempty RELEASE_REPO RELEASE_REPO LTC_RELEASE_REPO LR_RELEASE_REPO LS_RELEASE_REPO || exit 1
  ltc_require_first_nonempty SERVICES_REPO SERVICES_REPO LTC_SERVICES_REPO LR_SERVICES_REPO LS_SERVICES_REPO || exit 1

  FORGEJO_API_BASE="${FORGEJO_API_BASE%/}"
  case "$ROLE_VISIBILITY" in
    public|limited|private) ;;
    *) fail "ROLE_VISIBILITY 必須是 public、limited 或 private" ;;
  esac
  [[ "$ROLE_PASSWORD_LENGTH" =~ ^[1-9][0-9]*$ ]] || fail "ROLE_PASSWORD_LENGTH 必須是正整數"

  REPO_NAMES=(
    "$AI_REPO"
    "$SPEC_REPO"
    "$APP_REPO"
    "$SERVER_REPO"
    "$DATA_REPO"
    "$QA_REPO"
    "$DOCS_REPO"
    "$I18N_REPO"
    "$UX_REPO"
    "$OPS_REPO"
    "$RELEASE_REPO"
    "$SERVICES_REPO"
  )
  ISSUE_REPOS=(
    "$SPEC_REPO"
    "$APP_REPO"
    "$SERVER_REPO"
    "$DATA_REPO"
    "$QA_REPO"
    "$DOCS_REPO"
    "$I18N_REPO"
    "$UX_REPO"
    "$OPS_REPO"
    "$RELEASE_REPO"
    "$SERVICES_REPO"
  )

  validate_unique_values "repo 名稱" "${REPO_NAMES[@]}"

  export ADMIN_TOKEN FORGEJO_API_BASE FORGEJO_ORG PROJECT_NAME PROJECT_SLUG
  export ROLE_ACCOUNT_PREFIX ROLE_ACCOUNT_SEPARATOR
  export ROLE_TEAM_NAME ROLE_EMAIL_DOMAIN ROLE_TOKEN_NAME ROLE_VISIBILITY ROLE_PASSWORD_LENGTH
  export AI_REPO SPEC_REPO APP_REPO SERVER_REPO DATA_REPO QA_REPO DOCS_REPO I18N_REPO UX_REPO OPS_REPO RELEASE_REPO SERVICES_REPO
}

preflight_api_access() {
  local tmp http_code
  tmp="$(mktemp)"

  http_code="$(api_status GET "${FORGEJO_API_BASE}/admin/users?limit=1" '' "$tmp")"
  if [ "$http_code" != '200' ]; then
    echo "❌ 預檢失敗：ADMIN_TOKEN 無法存取 admin/users (HTTP ${http_code})" >&2
    sed -n '1,20p' "$tmp" >&2
    rm -f "$tmp"
    exit 1
  fi

  http_code="$(api_status GET "${FORGEJO_API_BASE}/orgs/${FORGEJO_ORG}" '' "$tmp")"
  if [ "$http_code" = '404' ]; then
    echo "組織 ${FORGEJO_ORG} 不存在，自動建立..."
    local org_payload
    org_payload="$(python3 -c 'import json,sys; print(json.dumps({"username": sys.argv[1], "visibility": sys.argv[2]}))' "$FORGEJO_ORG" "$ROLE_VISIBILITY")"
    http_code="$(api_status POST "${FORGEJO_API_BASE}/orgs" "$org_payload" "$tmp")"
    if [ "$http_code" != '201' ]; then
      echo "❌ 建立組織失敗：${FORGEJO_ORG} (HTTP ${http_code})" >&2
      sed -n '1,20p' "$tmp" >&2
      rm -f "$tmp"
      exit 1
    fi
    echo "組織 ok: ${FORGEJO_ORG}"
  elif [ "$http_code" != '200' ]; then
    echo "❌ 預檢失敗：無法存取組織 ${FORGEJO_ORG} (HTTP ${http_code})" >&2
    sed -n '1,20p' "$tmp" >&2
    rm -f "$tmp"
    exit 1
  fi

  rm -f "$tmp"
}

bool_is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

repo_description() {
  case "$1" in
    "$AI_REPO") printf '%s\n' "AI automation environment for ${PROJECT_NAME}" ;;
    "$SPEC_REPO") printf '%s\n' "Specifications and architecture documents for ${PROJECT_NAME}" ;;
    "$APP_REPO") printf '%s\n' "Application development repository for ${PROJECT_NAME}" ;;
    "$SERVER_REPO") printf '%s\n' "Backend server development repository for ${PROJECT_NAME}" ;;
    "$DATA_REPO") printf '%s\n' "Database schema and migration repository for ${PROJECT_NAME}" ;;
    "$QA_REPO") printf '%s\n' "Quality assurance and acceptance repository for ${PROJECT_NAME}" ;;
    "$DOCS_REPO") printf '%s\n' "Documentation repository for ${PROJECT_NAME}" ;;
    "$I18N_REPO") printf '%s\n' "Localization repository for ${PROJECT_NAME}" ;;
    "$UX_REPO") printf '%s\n' "UX guidelines and design decisions for ${PROJECT_NAME}" ;;
    "$OPS_REPO") printf '%s\n' "Operations and infrastructure repository for ${PROJECT_NAME}" ;;
    "$RELEASE_REPO") printf '%s\n' "Release management repository for ${PROJECT_NAME}" ;;
    "$SERVICES_REPO") printf '%s\n' "Service coordination repository for ${PROJECT_NAME}" ;;
    *) printf '%s\n' "Repository for ${PROJECT_NAME}" ;;
  esac
}

random_password() {
  python3 - <<'PY'
import secrets, string, os
length = int(os.environ['ROLE_PASSWORD_LENGTH'])
alphabet = string.ascii_letters + string.digits + '!@#%^*-_'
print(''.join(secrets.choice(alphabet) for _ in range(length)))
PY
}

api_json() {
  local method="$1"
  local url="$2"
  local data="${3:-}"
  if [ -n "$data" ]; then
    curl -sk -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}" \
      -H 'Content-Type: application/json' \
      -d "$data"
  else
    curl -sk -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}"
  fi
}

api_status() {
  local method="$1"
  local url="$2"
  local data="${3:-}"
  local outfile="$4"
  if [ -n "$data" ]; then
    curl -sk -o "$outfile" -w '%{http_code}' -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}" \
      -H 'Content-Type: application/json' \
      -d "$data"
  else
    curl -sk -o "$outfile" -w '%{http_code}' -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}"
  fi
}

refresh_existing_repos() {
  local repo
  EXISTING_REPOS=()
  while IFS= read -r repo; do
    [ -n "$repo" ] && EXISTING_REPOS["$repo"]=1
  done < <(
    api_json GET "${FORGEJO_API_BASE}/orgs/${FORGEJO_ORG}/repos?limit=100" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for item in data:
    name = item.get("name")
    if name:
        print(name)
'
  )
}

refresh_existing_users() {
  local user
  EXISTING_USERS=()
  while IFS= read -r user; do
    [ -n "$user" ] && EXISTING_USERS["$user"]=1
  done < <(
    api_json GET "${FORGEJO_API_BASE}/admin/users?limit=200" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for item in data:
    login = item.get("login")
    if login:
        print(login)
'
  )
}

_team_units='["repo.code","repo.issues","repo.ext_issues","repo.pulls","repo.releases","repo.wiki","repo.ext_wiki","repo.projects","repo.packages"]'

readers_team_payload() {
  python3 -c 'import json,sys; print(json.dumps({
    "name": sys.argv[1],
    "description": sys.argv[2],
    "includes_all_repositories": True,
    "permission": "read",
    "can_create_org_repo": False,
    "units": json.loads(sys.argv[3])
}))' "$ROLE_TEAM_NAME" "Read access for all ${PROJECT_NAME} automation roles" "$_team_units"
}

writer_team_payload() {
  local role="$1"
  python3 -c 'import json,sys; print(json.dumps({
    "name": sys.argv[1],
    "description": sys.argv[2],
    "includes_all_repositories": False,
    "permission": "write",
    "can_create_org_repo": False,
    "units": json.loads(sys.argv[3])
}))' "${PROJECT_SLUG}-${role}" "Write access for ${role} role in ${PROJECT_NAME}" "$_team_units"
}

ensure_repo() {
  local repo="$1"
  local payload tmp http_code
  [ -n "${EXISTING_REPOS[$repo]+x}" ] && return 0

  payload="$(python3 -c 'import json,sys; print(json.dumps({"name": sys.argv[1], "description": sys.argv[2], "private": True, "auto_init": False}))' "$repo" "$(repo_description "$repo")")"
  tmp="$(mktemp)"
  http_code="$(api_status POST "${FORGEJO_API_BASE}/orgs/${FORGEJO_ORG}/repos" "$payload" "$tmp")"
  if [ "$http_code" != '201' ] && [ "$http_code" != '202' ] && [ "$http_code" != '409' ]; then
    echo "❌ 建立 repo 失敗: ${FORGEJO_ORG}/${repo} (HTTP ${http_code})"
    sed -n '1,20p' "$tmp"
    rm -f "$tmp"
    exit 1
  fi
  rm -f "$tmp"
  EXISTING_REPOS["$repo"]=1
  echo "repo ok: ${FORGEJO_ORG}/${repo}"
}

_lookup_team_id() {
  local team_name="$1"
  api_json GET "${FORGEJO_API_BASE}/orgs/${FORGEJO_ORG}/teams" | \
    python3 -c 'import json,sys; data=json.load(sys.stdin); target=sys.argv[1]; print(next((str(i["id"]) for i in data if i.get("name")==target), ""))' "$team_name"
}

ensure_named_team() {
  local team_name="$1"
  local payload="$2"
  local team_id tmp http_code

  team_id="$(_lookup_team_id "$team_name")"
  if [ -z "$team_id" ]; then
    tmp="$(mktemp)"
    http_code="$(api_status POST "${FORGEJO_API_BASE}/orgs/${FORGEJO_ORG}/teams" "$payload" "$tmp")"
    if [ "$http_code" != '201' ] && [ "$http_code" != '200' ]; then
      echo "❌ 建立 team 失敗: ${team_name} (HTTP ${http_code})"
      sed -n '1,20p' "$tmp"
      rm -f "$tmp"
      exit 1
    fi
    rm -f "$tmp"
    team_id="$(_lookup_team_id "$team_name")"
  else
    api_json PATCH "${FORGEJO_API_BASE}/teams/${team_id}" "$payload" >/dev/null
  fi

  if [ -z "$team_id" ]; then
    echo "❌ 找不到 team: ${team_name}"
    exit 1
  fi
  printf '%s\n' "$team_id"
}

ensure_user() {
  local username="$1"
  local password="$2"
  local email="$3"
  local payload tmp http_code

  tmp="$(mktemp)"
  if [ -n "${EXISTING_USERS[$username]+x}" ]; then
    payload="$(python3 -c 'import json,sys; print(json.dumps({"login_name":"","source_id":0,"password":sys.argv[2],"email":sys.argv[3],"must_change_password":False,"restricted":False,"visibility":sys.argv[4]}))' "$username" "$password" "$email" "$ROLE_VISIBILITY")"
    http_code="$(api_status PATCH "${FORGEJO_API_BASE}/admin/users/${username}" "$payload" "$tmp")"
    if [ "$http_code" != '200' ]; then
      echo "❌ 更新使用者失敗: ${username} (HTTP ${http_code})"
      sed -n '1,20p' "$tmp"
      rm -f "$tmp"
      exit 1
    fi
    echo "user ok: ${username} (updated)"
  else
    payload="$(python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[2],"password":sys.argv[3],"username":sys.argv[1],"must_change_password":False,"send_notify":False,"visibility":sys.argv[4]}))' "$username" "$email" "$password" "$ROLE_VISIBILITY")"
    http_code="$(api_status POST "${FORGEJO_API_BASE}/admin/users" "$payload" "$tmp")"
    if [ "$http_code" != '201' ]; then
      echo "❌ 建立使用者失敗: ${username} (HTTP ${http_code})"
      sed -n '1,20p' "$tmp"
      rm -f "$tmp"
      exit 1
    fi
    EXISTING_USERS["$username"]=1
    echo "user ok: ${username} (created)"
  fi
  rm -f "$tmp"
}

ensure_team_member() {
  local team_id="$1"
  local username="$2"
  local team_name="${3:-team#${team_id}}"
  local tmp http_code
  tmp="$(mktemp)"
  http_code="$(api_status PUT "${FORGEJO_API_BASE}/teams/${team_id}/members/${username}" '' "$tmp")"
  rm -f "$tmp"
  if [ "$http_code" != '204' ]; then
    echo "❌ 加入 team 失敗: ${username} -> ${team_name} (HTTP ${http_code})"
    exit 1
  fi
}

ensure_team_repo() {
  local team_id="$1"
  local repo="$2"
  local tmp http_code
  tmp="$(mktemp)"
  http_code="$(api_status PUT "${FORGEJO_API_BASE}/teams/${team_id}/repos/${FORGEJO_ORG}/${repo}" '' "$tmp")"
  rm -f "$tmp"
  if [ "$http_code" != '204' ]; then
    echo "⚠️  加入 team repo 失敗 (可能已存在): ${repo} (HTTP ${http_code})"
  fi
}

create_user_token() {
  local username="$1"
  local password="$2"
  curl -sk -u "${username}:${password}" -X DELETE \
    "${FORGEJO_API_BASE}/users/${username}/tokens/${ROLE_TOKEN_NAME}" >/dev/null || true
  curl -sk -u "${username}:${password}" -X POST \
    "${FORGEJO_API_BASE}/users/${username}/tokens" \
    -H 'Content-Type: application/json' \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"name": sys.argv[1]}))' "$ROLE_TOKEN_NAME")" | \
    python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["sha1"])'
}

env_set_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  python3 - "$file" "$key" "$value" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
lines = path.read_text().splitlines() if path.exists() else []
out = []
found = False
for line in lines:
    if line.startswith(f'{key}='):
        out.append(f'{key}={value}')
        found = True
    else:
        out.append(line)
if not found:
    if out and out[-1] != '':
        out.append('')
    out.append(f'{key}={value}')
path.write_text('\n'.join(out) + '\n')
PY
}

template_url_for_repo() {
  case "$1" in
    "$AI_REPO")       printf '%s\n' "${AI_TEMPLATE_REPO:-}" ;;
    "$SPEC_REPO")     printf '%s\n' "${SPEC_TEMPLATE_REPO:-}" ;;
    "$APP_REPO")      printf '%s\n' "${APP_TEMPLATE_REPO:-}" ;;
    "$SERVER_REPO")   printf '%s\n' "${SERVER_TEMPLATE_REPO:-}" ;;
    "$DATA_REPO")     printf '%s\n' "${DATA_TEMPLATE_REPO:-}" ;;
    "$QA_REPO")       printf '%s\n' "${QA_TEMPLATE_REPO:-}" ;;
    "$DOCS_REPO")     printf '%s\n' "${DOCS_TEMPLATE_REPO:-}" ;;
    "$I18N_REPO")     printf '%s\n' "${I18N_TEMPLATE_REPO:-}" ;;
    "$UX_REPO")       printf '%s\n' "${UX_TEMPLATE_REPO:-}" ;;
    "$OPS_REPO")      printf '%s\n' "${OPS_TEMPLATE_REPO:-}" ;;
    "$RELEASE_REPO")  printf '%s\n' "${RELEASE_TEMPLATE_REPO:-}" ;;
    "$SERVICES_REPO") printf '%s\n' "${SERVICES_TEMPLATE_REPO:-}" ;;
    *) printf '' ;;
  esac
}

seed_repo_from_template() {
  local repo="$1"
  local template_url="$2"
  local target_url="${FORGEJO_SSH_BASE}/${FORGEJO_ORG}/${repo}.git"
  local tmp_dir

  if [ -n "$(git ls-remote --heads --tags "$target_url" 2>/dev/null)" ]; then
    echo "  ${repo}: 跳過，遠端已有內容"
    return 0
  fi

  tmp_dir="$(mktemp -d)"
  echo "  ${repo}: clone ${template_url} ..."
  if git clone --bare "$template_url" "${tmp_dir}/tpl.git" 2>/dev/null; then
    git -C "${tmp_dir}/tpl.git" push --mirror "$target_url"
    echo "  ${repo}: seed 完成"
  else
    echo "  ⚠️  ${repo}: 無法 clone ${template_url}，跳過"
  fi
  rm -rf "$tmp_dir"
}

ensure_labels_for_repo() {
  local repo="$1"
  local existing label_spec name color description payload
  existing="$({ api_json GET "${FORGEJO_API_BASE}/repos/${FORGEJO_ORG}/${repo}/labels"; } | python3 -c 'import json,sys; data=json.load(sys.stdin); print("\n".join(i.get("name","") for i in data if i.get("name")))')"
  for label_spec in "${LABEL_SPECS[@]}"; do
    IFS='|' read -r name color description <<< "$label_spec"
    if printf '%s\n' "$existing" | grep -Fxq "$name"; then
      continue
    fi
    payload="$(python3 -c 'import json,sys; print(json.dumps({"name": sys.argv[1], "color": sys.argv[2], "description": sys.argv[3]}))' "$name" "$color" "$description")"
    api_json POST "${FORGEJO_API_BASE}/repos/${FORGEJO_ORG}/${repo}/labels" "$payload" >/dev/null
    echo "label ok: ${repo} -> ${name}"
  done
}

echo "=== Forgejo 遠端環境 bootstrap ==="
preflight_commands
preflight_env
preflight_api_access
echo "Org: ${FORGEJO_ORG}"

echo "-- ensuring repos --"
refresh_existing_repos
for repo in "${REPO_NAMES[@]}"; do
  [ -n "$repo" ] && ensure_repo "$repo"
done

refresh_existing_users

echo "-- ensuring readers team --"
READERS_TEAM_ID="$(ensure_named_team "$ROLE_TEAM_NAME" "$(readers_team_payload)")"
echo "team ok: ${ROLE_TEAM_NAME} (read-all, #${READERS_TEAM_ID})"

echo "-- ensuring role accounts, write teams, and tokens --"
for role in "${ROLE_NAMES[@]}"; do
  username="$(ltc_account_for_role "$role")"
  repo="$(ltc_repo_for_role "$role")"
  write_team="${PROJECT_SLUG}-${role}"
  email_local="$(printf '%s' "$username" | tr '[:upper:]' '[:lower:]')"
  email="${email_local}@${ROLE_EMAIL_DOMAIN}"
  password="$(random_password)"

  ensure_user "$username" "$password" "$email"

  ensure_team_member "$READERS_TEAM_ID" "$username" "$ROLE_TEAM_NAME"

  WRITE_TEAM_ID="$(ensure_named_team "$write_team" "$(writer_team_payload "$role")")"
  ensure_team_repo "$WRITE_TEAM_ID" "$repo"
  ensure_team_member "$WRITE_TEAM_ID" "$username" "$write_team"
  echo "team ok: ${write_team} (write -> ${repo})"

  token="$(create_user_token "$username" "$password")"
  env_set_key "$ENV_FILE" "$(ltc_token_var_for_role "$role")" "$token"
  echo "token ok: ${username} -> $(ltc_token_var_for_role "$role")"
done

echo "-- ensuring labels --"
for repo in "${ISSUE_REPOS[@]}"; do
  [ -n "$repo" ] && ensure_labels_for_repo "$repo"
done

echo "-- seeding repos from templates --"
_seed_count=0
for repo in "${REPO_NAMES[@]}"; do
  [ -n "$repo" ] || continue
  tpl_url="$(template_url_for_repo "$repo")"
  [ -n "$tpl_url" ] && _seed_count=$((_seed_count + 1))
done

if [ "$_seed_count" -gt 0 ]; then
  ltc_require_command git || exit 1
  [ -n "${FORGEJO_SSH_BASE:-}" ] || fail "FORGEJO_SSH_BASE 未設定，無法執行 template seed"
  for repo in "${REPO_NAMES[@]}"; do
    [ -n "$repo" ] || continue
    tpl_url="$(template_url_for_repo "$repo")"
    [ -n "$tpl_url" ] && seed_repo_from_template "$repo" "$tpl_url"
  done
else
  echo "  （未設定任何 *_TEMPLATE_REPO，跳過）"
fi

echo ""
echo "✅ Forgejo bootstrap 完成"
echo "- 已建立 / 確認 repos"
echo "- 已建立共享 read team: ${ROLE_TEAM_NAME}"
echo "- 已為每個 role 建立 write team: ${PROJECT_SLUG}-{role}"
echo "- 已為角色生成 access tokens 並寫入 .env"
echo "- 已建立標準 issue labels"
[ "$_seed_count" -gt 0 ] && echo "- 已從 template repos seed 初始內容（${_seed_count} 個 repo）"
