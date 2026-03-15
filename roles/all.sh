#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION="${PROJECT_SLUG}-ai"
MODE="${1:-}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/ltc-common.sh"
ltc_source_env "$ROOT_DIR/.env"
ltc_init_project_env

CORE_ROLES=(dispatcher spec app server data qa ops)
SUPPORT_ROLES=(docs i18n ux release services)
ALL_ROLES=("${CORE_ROLES[@]}" "${SUPPORT_ROLES[@]}")

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "⚠️  tmux session '$SESSION' 已存在"
  echo "   重新連入：tmux attach -t $SESSION"
  echo "   強制重建：tmux kill-session -t $SESSION && bash $0"
  exit 0
fi

echo "=== 啟動 ${PROJECT_NAME} AI（所有角色）==="
echo "Session: $SESSION"
echo ""

tmux new-session -d -s "$SESSION" -n "dispatcher"
tmux send-keys -t "$SESSION:dispatcher" \
  "cd '$ROOT_DIR/..' && bash ai/roles/dispatcher.sh $MODE" Enter

for ROLE in "${ALL_ROLES[@]}"; do
  [ "$ROLE" = "dispatcher" ] && continue
  tmux new-window -t "$SESSION" -n "$ROLE"
  tmux send-keys -t "$SESSION:$ROLE" \
    "cd '$ROOT_DIR/..' && bash ai/roles/${ROLE}.sh $MODE" Enter
done

tmux select-window -t "$SESSION:dispatcher"

echo "✅ 已啟動 ${#ALL_ROLES[@]} 個角色"
echo ""
echo "連入 session："
echo "  tmux attach -t $SESSION"
echo ""
echo "切換角色（window）："
for i in "${!ALL_ROLES[@]}"; do
  echo "  Ctrl+b $i  → ${ALL_ROLES[$i]}"
done

if [ -t 0 ]; then
  tmux attach -t "$SESSION"
fi
