#!/bin/bash
set -Eeuo pipefail

setup_on_error() {
  local exit_code="$?"
  local line_no="${1:-unknown}"
  echo "❌ setup.sh 執行失敗：第 ${line_no} 行（exit ${exit_code}）" >&2
  exit "$exit_code"
}

trap 'setup_on_error "$LINENO"' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/ltc-common.sh"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "❌ 找不到 .env，請先建立："
  echo "   cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env"
  echo "   然後填入各角色的 Forgejo API token"
  exit 1
fi

ltc_source_env "$SCRIPT_DIR/.env"
ltc_init_project_env

GIT_BASE="${FORGEJO_SSH_BASE}/${FORGEJO_ORG}"
ROLES=(spec app server data qa docs i18n ux ops release services)
declare -A AVAILABLE_REPOS=()
declare -A MISSING_REPO_INDEX=()
MISSING_REPOS=()
REPO_INDEX_LOADED=false
AUTO_CREATE_REPOS="${AUTO_CREATE_REPOS:-true}"

has_code_repo() {
  [ "$1" != "services" ]
}

bool_is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

load_repo_index() {
  local token repo
  token="$(ltc_metadata_token 2>/dev/null || true)"
  [ -z "$token" ] && return 0

  while IFS= read -r repo; do
    [ -n "$repo" ] && AVAILABLE_REPOS["$repo"]=1
  done < <(
    curl -sk -H "Authorization: token $token" \
      "${FORGEJO_API_BASE}/orgs/${FORGEJO_ORG}/repos?limit=100" | \
      python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
if isinstance(data, list):
    for item in data:
        name = item.get("name")
        if name:
            print(name)
'
  )

  REPO_INDEX_LOADED=true
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
    "$SERVICES_REPO") printf '%s\n' "Service coordination and issue tracking for ${PROJECT_NAME}" ;;
    *) printf '%s\n' "Repository for ${PROJECT_NAME}" ;;
  esac
}

create_remote_repo() {
  local repo="$1"
  local admin_token payload http_code response_file

  admin_token="${ADMIN_TOKEN:-}"
  [ -z "$admin_token" ] && return 1

  response_file="$(mktemp)"
  payload="$(python3 -c 'import json, sys; print(json.dumps({"name": sys.argv[1], "description": sys.argv[2], "private": True, "auto_init": False}))' "$repo" "$(repo_description "$repo")")"
  http_code="$(
    curl -sk -o "$response_file" -w '%{http_code}' \
      -X POST "${FORGEJO_API_BASE}/orgs/${FORGEJO_ORG}/repos" \
      -H "Authorization: token ${admin_token}" \
      -H "Content-Type: application/json" \
      -d "$payload"
  )"

  if [ "$http_code" = "201" ] || [ "$http_code" = "202" ] || [ "$http_code" = "409" ]; then
    rm -f "$response_file"
    return 0
  fi

  echo "  repo create failed (${FORGEJO_ORG}/${repo}, HTTP ${http_code})"
  sed -n '1,5p' "$response_file"
  rm -f "$response_file"
  return 1
}

create_missing_remote_repos() {
  local repo created_any=false
  local configured_repos=(
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

  if ! $REPO_INDEX_LOADED; then
    return 0
  fi
  if ! bool_is_true "$AUTO_CREATE_REPOS"; then
    return 0
  fi
  if [ -z "${ADMIN_TOKEN:-}" ]; then
    return 0
  fi

  for repo in "${configured_repos[@]}"; do
    [ -z "$repo" ] && continue
    if [ -z "${AVAILABLE_REPOS[$repo]+x}" ]; then
      echo "  repo/: create ${FORGEJO_ORG}/${repo}"
      if create_remote_repo "$repo"; then
        created_any=true
      fi
    fi
  done

  if $created_any; then
    AVAILABLE_REPOS=()
    load_repo_index
  fi
}

repo_configured_and_available() {
  local repo="$1"

  [ -z "$repo" ] && return 1
  if ! $REPO_INDEX_LOADED; then
    return 0
  fi
  [ -n "${AVAILABLE_REPOS[$repo]+x}" ]
}

note_missing_repo() {
  local repo="$1"
  local message="$2"
  local key="${repo}:${message}"

  if [ -z "${MISSING_REPO_INDEX[$key]+x}" ]; then
    MISSING_REPO_INDEX["$key"]=1
    MISSING_REPOS+=("${FORGEJO_ORG}/${repo}: ${message}")
  fi
}

clone_repo_if_available() {
  local repo="$1"
  local dest="$2"
  local label="$3"

  mkdir -p "$(dirname "$dest")"

  if [ -d "$dest/.git" ]; then
    echo "  ${label}: pull"
    ltc_git_pull_if_ready "$dest"
    return 0
  fi

  if ! repo_configured_and_available "$repo"; then
    echo "  ${label}: 跳過，找不到 ${FORGEJO_ORG}/${repo}"
    note_missing_repo "$repo" "repo not found"
    return 0
  fi

  echo "  ${label}: clone $repo"
  if ! git clone --quiet "$GIT_BASE/$repo.git" "$dest"; then
    echo "  ${label}: clone 失敗，已跳過 ${FORGEJO_ORG}/${repo}"
    rm -rf "$dest"
    note_missing_repo "$repo" "clone failed"
  fi
}

echo "=== ${PROJECT_NAME} 環境初始化 ==="
echo "Run 目錄: $RUN_DIR"
load_repo_index
create_missing_remote_repos
if $REPO_INDEX_LOADED && [ "${#AVAILABLE_REPOS[@]}" -eq 0 ]; then
  echo "⚠️  ${FORGEJO_ORG} 目前沒有可見 repos；setup 會先建立角色目錄與 AI 設定，略過 clone。"
fi

after_copy_role_prompt() {
  local role="$1"
  local role_dir="$2"
  local prompt_file
  prompt_file="$(ltc_prompt_for_role "$role")"
  cp "$SCRIPT_DIR/prompts/conventions.md" "$role_dir/ai/"
  cp "$SCRIPT_DIR/prompts/${prompt_file}" "$role_dir/ai/"
  cp "$SCRIPT_DIR/scripts/"*.sh "$role_dir/ai/scripts/"
  chmod +x "$role_dir/ai/scripts/"*.sh
  echo "  ai/: copied conventions.md + ${prompt_file} + scripts/"
}

for ROLE in "${ROLES[@]}"; do
  ROLE_DIR="$RUN_DIR/$ROLE"
  REPO="$(ltc_repo_for_role "$ROLE")"

  echo ""
  echo "--- $ROLE ---"
  mkdir -p "$ROLE_DIR"

  if has_code_repo "$ROLE"; then
    clone_repo_if_available "$REPO" "$ROLE_DIR/code" "code/"

    if [ "$ROLE" = "ux" ]; then
      clone_repo_if_available "$APP_REPO" "$ROLE_DIR/app" "app/"
      [ -d "$ROLE_DIR/app/.git" ] && echo "  app/: cloned $APP_REPO (visual reference)"
    fi

    if [ "$ROLE" = "app" ]; then
      if [ -d "$ROLE_DIR/code/.git" ] && ltc_git_has_commits "$ROLE_DIR/code" &&
         git -C "$ROLE_DIR/code" ls-tree -d --name-only HEAD lib/l10n | grep -qx 'lib/l10n'; then
        git -C "$ROLE_DIR/code" submodule update --init --quiet lib/l10n
        echo "  code/lib/l10n: submodule updated ($I18N_REPO)"
      fi
      clone_repo_if_available "$UX_REPO" "$ROLE_DIR/ux" "ux/"
      [ -d "$ROLE_DIR/ux/.git" ] && echo "  ux/: cloned $UX_REPO (design guidelines)"
    fi
  else
    echo "  code/: 跳過（此角色無 code repo）"
  fi

  if [ "$ROLE" != "spec" ]; then
    if [ "$ROLE" = "services" ]; then
      if [ -d "$ROLE_DIR/docs/.git" ]; then
        if ltc_git_has_commits "$ROLE_DIR/docs"; then
          git -C "$ROLE_DIR/docs" sparse-checkout set user/
          git -C "$ROLE_DIR/docs" pull --quiet
        fi
      elif ! repo_configured_and_available "$DOCS_REPO"; then
        echo "  docs/: 跳過，找不到 ${FORGEJO_ORG}/${DOCS_REPO}"
        note_missing_repo "$DOCS_REPO" "repo not found"
      else
        if git clone --quiet --no-checkout "$GIT_BASE/$DOCS_REPO.git" "$ROLE_DIR/docs"; then
          if ltc_git_has_commits "$ROLE_DIR/docs"; then
            git -C "$ROLE_DIR/docs" sparse-checkout set user/
            git -C "$ROLE_DIR/docs" checkout --quiet
          fi
        else
          echo "  docs/: clone 失敗，已跳過 ${FORGEJO_ORG}/${DOCS_REPO}"
          rm -rf "$ROLE_DIR/docs"
          note_missing_repo "$DOCS_REPO" "clone failed"
        fi
      fi
      [ -d "$ROLE_DIR/docs/.git" ] && echo "  docs/: sparse checkout (user/ only)"
      [ -d "$ROLE_DIR/spec" ] && rm -rf "$ROLE_DIR/spec" && echo "  spec/: 已移除（改用 docs/）"
    elif [ -d "$ROLE_DIR/spec/.git" ]; then
      echo "  spec/: pull"
      ltc_git_pull_if_ready "$ROLE_DIR/spec"
    elif ! repo_configured_and_available "$SPEC_REPO"; then
      echo "  spec/: 跳過，找不到 ${FORGEJO_ORG}/${SPEC_REPO}"
      note_missing_repo "$SPEC_REPO" "repo not found"
    else
      echo "  spec/: clone $SPEC_REPO"
      if ! git clone --quiet "$GIT_BASE/$SPEC_REPO.git" "$ROLE_DIR/spec"; then
        echo "  spec/: clone 失敗，已跳過 ${FORGEJO_ORG}/${SPEC_REPO}"
        rm -rf "$ROLE_DIR/spec"
        note_missing_repo "$SPEC_REPO" "clone failed"
      fi
    fi
  fi

  if [ -L "$ROLE_DIR/ai" ]; then
    rm "$ROLE_DIR/ai"
  fi
  mkdir -p "$ROLE_DIR/ai/scripts"
  after_copy_role_prompt "$ROLE" "$ROLE_DIR"

  TOKEN_VAR="$(ltc_token_var_for_role "$ROLE")"
  TOKEN_VAL="${!TOKEN_VAR-}"
  ltc_write_shared_env "$ROLE_DIR/.env"
  if [ -n "$TOKEN_VAL" ]; then
    printf 'FORGEJO_TOKEN=%s\n' "$TOKEN_VAL" >> "$ROLE_DIR/.env"
    if [ "$ROLE" = "data" ] || [ "$ROLE" = "qa" ]; then
      printf 'DATABASE_URL=%s\n' "${DATABASE_URL:-postgres://ltcts:ltcts@localhost:5432/ltcts}" >> "$ROLE_DIR/.env"
      echo "  .env: 已產生（FORGEJO_TOKEN + DATABASE_URL）"
    else
      echo "  .env: 已產生（含共享設定 + FORGEJO_TOKEN）"
    fi
  else
    echo "  ⚠️  ${TOKEN_VAR} 未在 master .env 中找到"
  fi
done

ltc_write_shared_env "$RUN_DIR/.env"
if [ -n "${ADMIN_TOKEN:-}" ]; then
  printf 'FORGEJO_TOKEN=%s\n' "$ADMIN_TOKEN" >> "$RUN_DIR/.env"
  echo ""
  echo "--- dispatcher ---"
  echo "  .env: 已產生於 $RUN_DIR/.env"
else
  echo ""
  echo "⚠️  ADMIN_TOKEN 未設定，dispatcher 啟動前請補上"
fi

echo ""
echo "✅ 環境初始化完成"
if [ "${#MISSING_REPOS[@]}" -gt 0 ]; then
  echo ""
  echo "⚠️  以下 repo 尚未成功取得："
  for item in "${MISSING_REPOS[@]}"; do
    echo "  - $item"
  done
  echo "  可在 .env 覆寫 FORGEJO_ORG 與 *_REPO，或先在 Forgejo 建立對應 repo 後再執行 setup.sh。"
fi
echo ""
echo "啟動方式（若你目前在 AI repo 目錄：$SCRIPT_DIR）："
echo "  ./start.sh <role>"
for f in "$SCRIPT_DIR"/roles/*.sh; do
  [ -f "$f" ] && echo "  ./roles/$(basename "$f")"
done
echo ""
echo "若你目前在 Run 目錄：$RUN_DIR："
echo "  bash $(basename "$SCRIPT_DIR")/start.sh <role>"
