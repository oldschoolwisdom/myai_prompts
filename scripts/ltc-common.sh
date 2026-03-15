#!/bin/bash

ltc_normalize_identifier() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

ltc_assign_first_nonempty() {
  local target="$1"
  shift

  local candidate value
  for candidate in "$@"; do
    value="${!candidate-}"
    if [ -n "$value" ]; then
      printf -v "$target" '%s' "$value"
      export "$target"
      return 0
    fi
  done

  return 0
}

ltc_require_first_nonempty() {
  local target="$1"
  shift

  ltc_assign_first_nonempty "$target" "$@"
  if [ -n "${!target-}" ]; then
    return 0
  fi

  echo "❌ 必要設定缺失：${target}（可接受變數：$*）" >&2
  return 1
}

ltc_require_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  echo "❌ 缺少必要指令：${command_name}" >&2
  return 1
}

ltc_source_env() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

ltc_init_project_env() {
  ltc_assign_first_nonempty ADMIN_TOKEN ADMIN_TOKEN LTC_ADMIN_TOKEN LR_ADMIN_TOKEN LS_ADMIN_TOKEN
  ltc_assign_first_nonempty SPEC_TOKEN SPEC_TOKEN LTC_SPEC_TOKEN LR_SPEC_TOKEN LS_SPEC_TOKEN
  ltc_assign_first_nonempty APP_TOKEN APP_TOKEN LTC_APP_TOKEN LR_APP_TOKEN LS_APP_TOKEN
  ltc_assign_first_nonempty SERVER_TOKEN SERVER_TOKEN LTC_SERVER_TOKEN LR_SERVER_TOKEN LS_SERVER_TOKEN
  ltc_assign_first_nonempty DATA_TOKEN DATA_TOKEN LTC_DATA_TOKEN LR_DATA_TOKEN LS_DATA_TOKEN
  ltc_assign_first_nonempty QA_TOKEN QA_TOKEN LTC_QA_TOKEN LR_QA_TOKEN LS_QA_TOKEN
  ltc_assign_first_nonempty DOCS_TOKEN DOCS_TOKEN LTC_DOCS_TOKEN LR_DOCS_TOKEN LS_DOCS_TOKEN
  ltc_assign_first_nonempty I18N_TOKEN I18N_TOKEN LTC_I18N_TOKEN LR_I18N_TOKEN LS_I18N_TOKEN
  ltc_assign_first_nonempty RELEASE_TOKEN RELEASE_TOKEN LTC_RELEASE_TOKEN LR_RELEASE_TOKEN LS_RELEASE_TOKEN
  ltc_assign_first_nonempty OPS_TOKEN OPS_TOKEN LTC_OPS_TOKEN LR_OPS_TOKEN LS_OPS_TOKEN
  ltc_assign_first_nonempty UX_TOKEN UX_TOKEN LTC_UX_TOKEN LR_UX_TOKEN LS_UX_TOKEN
  ltc_assign_first_nonempty SERVICES_TOKEN SERVICES_TOKEN LTC_SERVICES_TOKEN LR_SERVICES_TOKEN LS_SERVICES_TOKEN

  : "${PROJECT_NAME:=osw-ai-template}"
  : "${FORGEJO_BASE_URL:=https://git.osw.tw}"
  FORGEJO_BASE_URL="${FORGEJO_BASE_URL%/}"
  : "${FORGEJO_API_BASE:=${FORGEJO_BASE_URL}/api/v1}"
  FORGEJO_API_BASE="${FORGEJO_API_BASE%/}"
  : "${FORGEJO_HOST:=git.osw.tw}"
  : "${FORGEJO_SSH_BASE:=ssh://git@${FORGEJO_HOST}:2222}"
  : "${FORGEJO_ORG:=${PROJECT_NAME}}"
  ltc_assign_first_nonempty PROJECT_SLUG PROJECT_SLUG FORGEJO_ORG PROJECT_NAME
  PROJECT_SLUG="$(ltc_normalize_identifier "$PROJECT_SLUG")"
  : "${PROJECT_SLUG:=project}"
  : "${ROLE_ACCOUNT_PREFIX:=${PROJECT_SLUG}}"
  : "${ROLE_ACCOUNT_SEPARATOR:--}"

  ltc_assign_first_nonempty AI_REPO AI_REPO LTC_AI_REPO LR_AI_REPO LS_AI_REPO
  ltc_assign_first_nonempty SPEC_REPO SPEC_REPO LTC_SPEC_REPO LR_SPEC_REPO LS_SPEC_REPO
  ltc_assign_first_nonempty APP_REPO APP_REPO LTC_APP_REPO LR_APP_REPO LS_APP_REPO
  ltc_assign_first_nonempty SERVER_REPO SERVER_REPO LTC_SERVER_REPO LR_SERVER_REPO LS_SERVER_REPO
  ltc_assign_first_nonempty DATA_REPO DATA_REPO LTC_DATA_REPO LR_DATA_REPO LS_DATA_REPO
  ltc_assign_first_nonempty QA_REPO QA_REPO LTC_QA_REPO LR_QA_REPO LS_QA_REPO
  ltc_assign_first_nonempty DOCS_REPO DOCS_REPO LTC_DOCS_REPO LR_DOCS_REPO LS_DOCS_REPO
  ltc_assign_first_nonempty I18N_REPO I18N_REPO LTC_I18N_REPO LR_I18N_REPO LS_I18N_REPO
  ltc_assign_first_nonempty UX_REPO UX_REPO LTC_UX_REPO LR_UX_REPO LS_UX_REPO
  ltc_assign_first_nonempty OPS_REPO OPS_REPO LTC_OPS_REPO LR_OPS_REPO LS_OPS_REPO
  ltc_assign_first_nonempty RELEASE_REPO RELEASE_REPO LTC_RELEASE_REPO LR_RELEASE_REPO LS_RELEASE_REPO
  ltc_assign_first_nonempty SERVICES_REPO SERVICES_REPO LTC_SERVICES_REPO LR_SERVICES_REPO LS_SERVICES_REPO

  : "${AI_REPO:=ai}"
  : "${SPEC_REPO:=spec}"
  : "${APP_REPO:=app}"
  : "${SERVER_REPO:=server}"
  : "${DATA_REPO:=data}"
  : "${QA_REPO:=qa}"
  : "${DOCS_REPO:=docs}"
  : "${I18N_REPO:=i18n}"
  : "${UX_REPO:=ux}"
  : "${OPS_REPO:=ops}"
  : "${RELEASE_REPO:=release}"
  : "${SERVICES_REPO:=services}"

  : "${LTC_ADMIN_TOKEN:=${ADMIN_TOKEN:-}}"
  : "${LTC_SPEC_TOKEN:=${SPEC_TOKEN:-}}"
  : "${LTC_APP_TOKEN:=${APP_TOKEN:-}}"
  : "${LTC_SERVER_TOKEN:=${SERVER_TOKEN:-}}"
  : "${LTC_DATA_TOKEN:=${DATA_TOKEN:-}}"
  : "${LTC_QA_TOKEN:=${QA_TOKEN:-}}"
  : "${LTC_DOCS_TOKEN:=${DOCS_TOKEN:-}}"
  : "${LTC_I18N_TOKEN:=${I18N_TOKEN:-}}"
  : "${LTC_RELEASE_TOKEN:=${RELEASE_TOKEN:-}}"
  : "${LTC_OPS_TOKEN:=${OPS_TOKEN:-}}"
  : "${LTC_UX_TOKEN:=${UX_TOKEN:-}}"
  : "${LTC_SERVICES_TOKEN:=${SERVICES_TOKEN:-}}"

  export PROJECT_NAME PROJECT_SLUG FORGEJO_BASE_URL FORGEJO_API_BASE FORGEJO_HOST FORGEJO_SSH_BASE FORGEJO_ORG
  export ROLE_ACCOUNT_PREFIX ROLE_ACCOUNT_SEPARATOR
  export AI_REPO SPEC_REPO APP_REPO SERVER_REPO DATA_REPO QA_REPO DOCS_REPO I18N_REPO UX_REPO OPS_REPO RELEASE_REPO SERVICES_REPO
  export ADMIN_TOKEN SPEC_TOKEN APP_TOKEN SERVER_TOKEN DATA_TOKEN QA_TOKEN
  export DOCS_TOKEN I18N_TOKEN RELEASE_TOKEN OPS_TOKEN UX_TOKEN SERVICES_TOKEN
  export LTC_ADMIN_TOKEN LTC_SPEC_TOKEN LTC_APP_TOKEN LTC_SERVER_TOKEN LTC_DATA_TOKEN LTC_QA_TOKEN
  export LTC_DOCS_TOKEN LTC_I18N_TOKEN LTC_RELEASE_TOKEN LTC_OPS_TOKEN LTC_UX_TOKEN LTC_SERVICES_TOKEN
}

ltc_repo_for_role() {
  case "$1" in
    spec) printf '%s\n' "$SPEC_REPO" ;;
    app) printf '%s\n' "$APP_REPO" ;;
    server) printf '%s\n' "$SERVER_REPO" ;;
    data) printf '%s\n' "$DATA_REPO" ;;
    qa) printf '%s\n' "$QA_REPO" ;;
    docs) printf '%s\n' "$DOCS_REPO" ;;
    i18n) printf '%s\n' "$I18N_REPO" ;;
    ux) printf '%s\n' "$UX_REPO" ;;
    ops) printf '%s\n' "$OPS_REPO" ;;
    release) printf '%s\n' "$RELEASE_REPO" ;;
    services) printf '%s\n' "$SERVICES_REPO" ;;
    dispatcher) printf '\n' ;;
    *) return 1 ;;
  esac
}

ltc_prompt_for_role() {
  if [ "$1" = "dispatcher" ]; then
    printf 'dispatcher.md\n'
  else
    printf 'ltc-%s.md\n' "$1"
  fi
}

ltc_account_for_role() {
  local role="$1"
  if [ -n "${ROLE_ACCOUNT_PREFIX:-}" ]; then
    printf '%s%s%s\n' "$ROLE_ACCOUNT_PREFIX" "${ROLE_ACCOUNT_SEPARATOR:--}" "$role"
  else
    printf '%s\n' "$role"
  fi
}

ltc_token_var_for_role() {
  printf '%s_TOKEN\n' "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
}

ltc_write_shared_env() {
  local target="$1"
  cat > "$target" <<EOF_ENV
PROJECT_NAME=${PROJECT_NAME}
PROJECT_SLUG=${PROJECT_SLUG}
FORGEJO_BASE_URL=${FORGEJO_BASE_URL}
FORGEJO_API_BASE=${FORGEJO_API_BASE}
FORGEJO_HOST=${FORGEJO_HOST}
FORGEJO_SSH_BASE=${FORGEJO_SSH_BASE}
FORGEJO_ORG=${FORGEJO_ORG}
ROLE_ACCOUNT_PREFIX=${ROLE_ACCOUNT_PREFIX}
ROLE_ACCOUNT_SEPARATOR=${ROLE_ACCOUNT_SEPARATOR}
AI_REPO=${AI_REPO}
SPEC_REPO=${SPEC_REPO}
APP_REPO=${APP_REPO}
SERVER_REPO=${SERVER_REPO}
DATA_REPO=${DATA_REPO}
QA_REPO=${QA_REPO}
DOCS_REPO=${DOCS_REPO}
I18N_REPO=${I18N_REPO}
UX_REPO=${UX_REPO}
OPS_REPO=${OPS_REPO}
RELEASE_REPO=${RELEASE_REPO}
SERVICES_REPO=${SERVICES_REPO}
EOF_ENV
}

ltc_metadata_token() {
  local var
  for var in \
    ADMIN_TOKEN \
    SPEC_TOKEN \
    APP_TOKEN \
    SERVER_TOKEN \
    DATA_TOKEN \
    QA_TOKEN \
    DOCS_TOKEN \
    I18N_TOKEN \
    RELEASE_TOKEN \
    OPS_TOKEN \
    UX_TOKEN \
    SERVICES_TOKEN \
    LTC_ADMIN_TOKEN \
    LTC_SPEC_TOKEN \
    LTC_APP_TOKEN \
    LTC_SERVER_TOKEN \
    LTC_DATA_TOKEN \
    LTC_QA_TOKEN \
    LTC_DOCS_TOKEN \
    LTC_I18N_TOKEN \
    LTC_RELEASE_TOKEN \
    LTC_OPS_TOKEN \
    LTC_UX_TOKEN \
    LTC_SERVICES_TOKEN; do
    if [ -n "${!var-}" ]; then
      printf '%s\n' "${!var}"
      return 0
    fi
  done
  return 1
}

ltc_git_has_commits() {
  local repo_dir="$1"
  git -C "$repo_dir" rev-parse --verify HEAD >/dev/null 2>&1
}

ltc_git_pull_if_ready() {
  local repo_dir="$1"
  if [ -d "$repo_dir/.git" ] && ltc_git_has_commits "$repo_dir"; then
    git -C "$repo_dir" pull --quiet
  fi
}
