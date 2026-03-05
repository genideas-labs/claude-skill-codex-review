Send a code review task to the VS Code Codex panel for independent review, with automated change summary.

## Usage modes

Parse the user argument to determine the review scope:
- `/review-codex` — **Full review**: code quality + spec GAP + security/performance/maintainability
- `/review-codex commit` — **Commit review**: latest commit diff only (code quality + brief spec GAP). Fastest.
- `/review-codex branch gap` — **Branch spec GAP**: FR/NFR/SC coverage analysis against spec only
- `/review-codex gap` — **Full GAP**: spec + API contracts + data model gap analysis

## Steps

1. Generate a concise change summary from the current session:
   - List each significant change with severity/category, one-line description, and affected files
   - Include spec FR references if applicable
   - Write in Korean
   - Write this summary to a temp file: `write to /tmp/codex-review-context.txt`
2. Determine the `--scope` flag from the user's argument:
   - No argument or "full" → `--scope full`
   - "commit" → `--scope commit`
   - "branch gap" → `--scope branch-gap`
   - "gap" → `--scope gap`
3. Run `bash .claude/skills/codex-review/scripts/codex-review.sh --scope <scope> --context /tmp/codex-review-context.txt`
4. Report to the user: review scope, whether context was attached, and send status
5. If the script falls back to CLI mode or clipboard-only, inform the user

## Context summary format (example)
```
이번 세션 변경 요약:
1. [Critical] PEP decision 필드가 dynamic allow override 시 'allow'로 합성 (enforcer.ts)
2. [High] /reset에 master role 체크 추가 (orchestrator-router.ts)
3. [Medium] /probe에 10초 타임아웃 추가 (orchestrator-router.ts)
테스트: 2005 passed / 0 failed
```

## Script options
- `--scope full` — Full review (default)
- `--scope commit` — Latest commit only
- `--scope branch-gap` — Spec GAP only
- `--scope gap` — Full GAP analysis
- `--context <file>` — Attach context summary
- `cli` — Falls back to Codex CLI in terminal
