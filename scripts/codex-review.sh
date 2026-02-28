#!/bin/bash
# codex-review.sh — Send a code review task to the VS Code Codex panel
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

BRANCH=$(git branch --show-current)
BASE_BRANCH="main"

# ── 0. Parse arguments ──────────────────────────────────────────
MODE="vscode"
CONTEXT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        cli)
            MODE="cli"
            shift
            ;;
        --context)
            CONTEXT_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ── 1. Check for changes ─────────────────────────────────────────
DIFF_COMMITTED=$(git diff "${BASE_BRANCH}...HEAD" 2>/dev/null || true)
DIFF_UNCOMMITTED=$(git diff 2>/dev/null || true)
DIFF_STAGED=$(git diff --cached 2>/dev/null || true)
ALL_DIFF="${DIFF_COMMITTED}${DIFF_UNCOMMITTED}${DIFF_STAGED}"

if [ -z "$ALL_DIFF" ]; then
    echo "No changes to review (branch: $BRANCH)."
    exit 0
fi

# Stats
STAT=$(git diff "${BASE_BRANCH}...HEAD" --stat 2>/dev/null || true)
FILES_CHANGED=$(echo "$STAT" | tail -1)

# ── 2. Find matching spec ────────────────────────────────────────
SPEC_REF=""
for dir in "$REPO_ROOT/specs"/*/; do
    [ -d "$dir" ] || continue
    dir_name=$(basename "$dir")
    if echo "$BRANCH" | grep -qi "$dir_name"; then
        SPEC_REF="specs/${dir_name}/spec.md"
        break
    fi
done

# ── 3. Build review prompt ───────────────────────────────────────
CONTEXT_SECTION=""
if [ -n "$CONTEXT_FILE" ] && [ -f "$CONTEXT_FILE" ]; then
    CONTEXT_SECTION="

--- 변경 요약 (Claude 제공) ---
$(cat "$CONTEXT_FILE")
---"
fi

PROMPT="코드 리뷰를 수행해주세요. 파일을 수정하지 마세요.

브랜치 '${BRANCH}'의 변경 사항을 '${BASE_BRANCH}' 대비 리뷰해주세요.
변경 통계: ${FILES_CHANGED}
${CONTEXT_SECTION}
리뷰 항목:
1. 코드 품질: 버그, 로직 오류, 엣지 케이스, 네이밍, 가독성
2. 스펙 GAP 분석: ${SPEC_REF:-스펙 없음} 파일과 비교하여 미구현/불완전한 부분 식별
3. 전체 평가: 보안, 성능, 유지보수성

git diff ${BASE_BRANCH}...HEAD 로 변경 사항을 확인하고, 필요시 전체 파일도 읽어주세요.
구조화된 리뷰 리포트를 한국어로 출력해주세요."

echo "=== Codex Review ==="
echo "Branch: $BRANCH"
echo "Changes: $FILES_CHANGED"
[ -n "$SPEC_REF" ] && echo "Spec: $SPEC_REF" || echo "Spec: (no matching spec found)"
[ -n "$CONTEXT_FILE" ] && echo "Context: $CONTEXT_FILE" || echo "Context: (none)"
echo "===================="

# ── 4. Mode selection ─────────────────────────────────────────────
if [ "$MODE" = "cli" ]; then
    # Fallback: launch Codex CLI directly
    exec codex --approval-mode suggest "$PROMPT"
fi

# ── 5. VS Code Codex panel automation ─────────────────────────────
# Save prompt to temp file for xdotool type fallback
PROMPT_FILE=$(mktemp /tmp/codex-review-XXXXXX.txt)
echo "$PROMPT" > "$PROMPT_FILE"

# Set clipboard via Python tkinter (background — keeps clipboard alive)
python3 -c "
import tkinter as tk, sys, signal
root = tk.Tk()
root.withdraw()
root.clipboard_clear()
root.clipboard_append(open('$PROMPT_FILE').read())
root.update()
signal.signal(signal.SIGTERM, lambda *a: (root.destroy(), sys.exit(0)))
root.after(10000, root.destroy)  # auto-exit after 10s
root.mainloop()
" &
CLIP_PID=$!
sleep 0.3

# Find VS Code window matching current project
PROJECT_NAME=$(basename "$REPO_ROOT")
# Try project-specific match first (title: "file — project — Visual Studio Code")
VSCODE_WID=$(xdotool search --name "$PROJECT_NAME.*Visual Studio Code" 2>/dev/null | head -1)
# Fallback: any VS Code window
[ -z "$VSCODE_WID" ] && VSCODE_WID=$(xdotool search --name "Visual Studio Code" 2>/dev/null | head -1)
[ -z "$VSCODE_WID" ] && VSCODE_WID=$(xdotool search --class "code" 2>/dev/null | head -1)

if [ -z "$VSCODE_WID" ]; then
    echo "VS Code window not found. Prompt saved to: $PROMPT_FILE"
    echo "Paste into Codex manually."
    kill "$CLIP_PID" 2>/dev/null || true
    exit 0
fi

# Focus VS Code
xdotool windowactivate --sync "$VSCODE_WID"
sleep 0.3

# Open Codex Sidebar via Command Palette to focus the input area
xdotool key --clearmodifiers ctrl+shift+p
sleep 0.5
xdotool type --clearmodifiers --delay 30 "Open Codex Sidebar"
sleep 0.5
xdotool key Return
sleep 1.0

# Paste the prompt (Ctrl+V) and submit (Enter)
xdotool key --clearmodifiers ctrl+v
sleep 0.3
xdotool key Return

# Cleanup
kill "$CLIP_PID" 2>/dev/null || true
rm -f "$PROMPT_FILE"
[ -n "$CONTEXT_FILE" ] && rm -f "$CONTEXT_FILE"

echo "Review task sent to VS Code Codex panel."
