#!/bin/bash
# stop-review-reminder.sh — Stop hook: remind about /review-codex when substantial changes exist
# Exit code 2 = block stop (Claude continues), 0 = allow stop

INPUT=$(cat)

# Prevent infinite loop: if already triggered once, let Claude stop
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$REPO_ROOT"

BRANCH=$(git branch --show-current 2>/dev/null)

# Skip if on main/master
[ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] && exit 0

# Count changed Rust files vs main
CHANGED_RS=$(git diff main...HEAD --name-only 2>/dev/null | grep -c '\.rs$' || true)
UNCOMMITTED=$(git status --porcelain 2>/dev/null | grep -c '\.rs' || true)
TOTAL=$((CHANGED_RS + UNCOMMITTED))

# Only remind if there are substantial Rust changes (3+ files)
[ "$TOTAL" -lt 3 ] && exit 0

# Throttle: max once per 30 minutes
REMINDER_FILE="$REPO_ROOT/.claude/.last-review-reminder"
if [ -f "$REMINDER_FILE" ]; then
    LAST=$(cat "$REMINDER_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST))
    [ "$ELAPSED" -lt 1800 ] && exit 0
fi

date +%s > "$REMINDER_FILE"

# Block stop and remind via stderr
echo "작업이 완료된 것 같습니다. ${TOTAL}개 Rust 파일이 변경되었습니다. /review-codex 로 Codex 독립 리뷰를 실행하시겠습니까?" >&2
exit 2
