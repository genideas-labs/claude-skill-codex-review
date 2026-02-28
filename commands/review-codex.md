Send a code review task to the VS Code Codex panel for independent review.

Steps:
1. Run `bash .claude/scripts/codex-review.sh` to send review to VS Code Codex panel
2. Report to the user that the review task was sent
3. If the script falls back to CLI mode or clipboard-only, inform the user

Options:
- Default: sends to VS Code Codex panel (clipboard + xdotool automation)
- `bash .claude/scripts/codex-review.sh cli` — falls back to Codex CLI in terminal
