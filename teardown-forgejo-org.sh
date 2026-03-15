#!/bin/bash
# teardown-forgejo-org.sh
#
# 清空指定 Forgejo 組織下的所有 repos、teams，以及符合 {ORG}-* 的非管理員帳號。
#
# 用法：
#   ./teardown-forgejo-org.sh <org>          ← 互動確認
#   ./teardown-forgejo-org.sh <org> --yes    ← 跳過確認（CI 用）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/ltc-common.sh"

# ── 參數 ────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "" ]; then
  echo "用法：$0 <org> [--yes]" >&2
  exit 1
fi
ORG="$1"
AUTO_YES="${2:-}"

# ── 環境 ────────────────────────────────────────────────────────────────────
ltc_source_env "$ENV_FILE"
ltc_source_env "$(cd "$SCRIPT_DIR/.." && pwd)/.env"
ltc_init_project_env

FORGEJO_API_BASE="${FORGEJO_API_BASE%/}"

[ -n "${ADMIN_TOKEN:-}" ] || { echo "❌ ADMIN_TOKEN 未設定" >&2; exit 1; }
[ -n "${FORGEJO_API_BASE:-}" ] || { echo "❌ FORGEJO_API_BASE 未設定" >&2; exit 1; }

ltc_require_command curl   || exit 1
ltc_require_command python3 || exit 1

# ── API helpers ─────────────────────────────────────────────────────────────
_api() {
  local method="$1" url="$2" data="${3:-}"
  if [ -n "$data" ]; then
    curl -sk -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$data"
  else
    curl -sk -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}"
  fi
}

_api_code() {
  local method="$1" url="$2" data="${3:-}" tmp
  tmp="$(mktemp)"
  local code
  if [ -n "$data" ]; then
    code="$(curl -sk -o "$tmp" -w '%{http_code}' -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$data")"
  else
    code="$(curl -sk -o "$tmp" -w '%{http_code}' -X "$method" "$url" \
      -H "Authorization: token ${ADMIN_TOKEN}")"
  fi
  rm -f "$tmp"
  printf '%s\n' "$code"
}

# ── 確認 org 存在 ────────────────────────────────────────────────────────────
echo "=== teardown: ${ORG} ==="
code="$(_api_code GET "${FORGEJO_API_BASE}/orgs/${ORG}")"
if [ "$code" = "404" ]; then
  echo "❌ 組織不存在：${ORG}" >&2
  exit 1
elif [ "$code" != "200" ]; then
  echo "❌ 無法存取組織 ${ORG}（HTTP ${code}）" >&2
  exit 1
fi

# ── 收集 repos ───────────────────────────────────────────────────────────────
mapfile -t REPOS < <(
  _api GET "${FORGEJO_API_BASE}/orgs/${ORG}/repos?limit=100" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for r in data:
    print(r["name"])
' 2>/dev/null
)

# ── 收集 teams ───────────────────────────────────────────────────────────────
declare -A TEAM_IDS=()
mapfile -t TEAM_ENTRIES < <(
  _api GET "${FORGEJO_API_BASE}/orgs/${ORG}/teams" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for t in data:
    print(t["id"], t["name"])
' 2>/dev/null
)
for entry in "${TEAM_ENTRIES[@]+"${TEAM_ENTRIES[@]}"}"; do
  [ -z "$entry" ] && continue
  tid="${entry%% *}"
  tname="${entry#* }"
  TEAM_IDS["$tname"]="$tid"
done

# ── 收集符合 {ORG}-* 的非管理員帳號 ─────────────────────────────────────────
USER_PATTERN="${ORG}-"
mapfile -t ALL_USERS < <(
  _api GET "${FORGEJO_API_BASE}/admin/users?limit=200" | python3 -c '
import json, sys
pattern = sys.argv[1]
data = json.load(sys.stdin)
for u in data:
    if u.get("login", "").startswith(pattern) and not u.get("is_admin", False):
        print(u["login"])
' "$USER_PATTERN" 2>/dev/null
)

# ── 預覽 ────────────────────────────────────────────────────────────────────
echo ""
echo "以下資源將被永久刪除："
echo ""
echo "  Repos（${#REPOS[@]} 個）："
for r in "${REPOS[@]+"${REPOS[@]}"}"; do [ -n "$r" ] && echo "    - ${ORG}/${r}"; done

echo ""
echo "  Teams（${#TEAM_IDS[@]} 個）："
for name in "${!TEAM_IDS[@]}"; do echo "    - ${name} (#${TEAM_IDS[$name]})"; done

echo ""
echo "  帳號（${#ALL_USERS[@]} 個，符合 ${USER_PATTERN}*，排除管理員）："
for u in "${ALL_USERS[@]+"${ALL_USERS[@]}"}"; do [ -n "$u" ] && echo "    - ${u}"; done

echo ""

# ── 確認 ────────────────────────────────────────────────────────────────────
if [ "${AUTO_YES}" != "--yes" ]; then
  printf '⚠️  此操作不可逆。請輸入組織名稱 "%s" 確認：' "$ORG"
  read -r confirm
  if [ "$confirm" != "$ORG" ]; then
    echo "取消。"
    exit 0
  fi
fi

# ── 刪除 repos ───────────────────────────────────────────────────────────────
echo ""
echo "-- 刪除 repos --"
for repo in "${REPOS[@]+"${REPOS[@]}"}"; do
  [ -z "$repo" ] && continue
  code="$(_api_code DELETE "${FORGEJO_API_BASE}/repos/${ORG}/${repo}")"
  if [ "$code" = "204" ]; then
    echo "  ✅ 刪除 repo: ${ORG}/${repo}"
  else
    echo "  ⚠️  刪除 repo 失敗: ${ORG}/${repo}（HTTP ${code}）"
  fi
done

# ── 刪除 teams ───────────────────────────────────────────────────────────────
echo ""
echo "-- 刪除 teams --"
for name in "${!TEAM_IDS[@]}"; do
  tid="${TEAM_IDS[$name]}"
  code="$(_api_code DELETE "${FORGEJO_API_BASE}/teams/${tid}")"
  if [ "$code" = "204" ]; then
    echo "  ✅ 刪除 team: ${name} (#${tid})"
  else
    echo "  ⚠️  刪除 team 失敗: ${name}（HTTP ${code}）"
  fi
done

# ── 刪除帳號 ─────────────────────────────────────────────────────────────────
echo ""
echo "-- 刪除帳號 --"
for user in "${ALL_USERS[@]+"${ALL_USERS[@]}"}"; do
  [ -z "$user" ] && continue
  code="$(_api_code DELETE "${FORGEJO_API_BASE}/admin/users/${user}?purge=true")"
  if [ "$code" = "204" ]; then
    echo "  ✅ 刪除帳號: ${user}"
  else
    echo "  ⚠️  刪除帳號失敗: ${user}（HTTP ${code}）"
  fi
done

echo ""
echo "✅ teardown 完成：${ORG}"
