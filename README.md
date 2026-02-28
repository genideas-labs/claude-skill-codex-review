# claude-skill-codex-review

Claude Code custom skill that sends code review tasks to the VS Code Codex panel for independent review.

## What it does

When you finish coding with Claude Code, this skill automatically sends a review request to OpenAI Codex in VS Code — giving you an independent second opinion on your changes.

**Review covers:**
1. Code quality (bugs, logic errors, edge cases, naming, readability)
2. Spec gap analysis (compares changes against feature specs in `specs/`)
3. Overall assessment (security, performance, maintainability)

## Components

| File | Purpose |
|------|---------|
| `commands/review-codex.md` | `/review-codex` slash command for Claude Code |
| `scripts/codex-review.sh` | Main script — collects context and sends to Codex |
| `scripts/stop-review-reminder.sh` | Stop hook — reminds you to review when idle |
| `settings-hook.json` | Hook configuration snippet for `.claude/settings.json` |

## Installation

### 1. Copy files into your project

```bash
# From your project root:
cp commands/review-codex.md .claude/commands/
cp scripts/*.sh .claude/scripts/
chmod +x .claude/scripts/codex-review.sh .claude/scripts/stop-review-reminder.sh
```

Or add as a git submodule:

```bash
git submodule add https://github.com/genideas-labs/claude-skill-codex-review.git .claude/skills/codex-review

# Symlink into place
ln -s ../skills/codex-review/commands/review-codex.md .claude/commands/review-codex.md
ln -s ../skills/codex-review/scripts/codex-review.sh .claude/scripts/codex-review.sh
ln -s ../skills/codex-review/scripts/stop-review-reminder.sh .claude/scripts/stop-review-reminder.sh
```

### 2. Add the Stop hook to `.claude/settings.json`

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/scripts/stop-review-reminder.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. Prerequisites

- **xdotool** — for VS Code window automation (`sudo apt install xdotool`)
- **Python 3 + tkinter** — for clipboard management (usually pre-installed)
- **VS Code** with [OpenAI Codex extension](https://marketplace.visualstudio.com/items?itemName=openai.chatgpt)

## Usage

### Manual

Type `/review-codex` in Claude Code to send a review to the Codex panel.

### Automatic reminder

When Claude Code finishes work on a feature branch with 3+ changed Rust files, the Stop hook will remind you to run `/review-codex`. Throttled to max once per 30 minutes.

### CLI fallback

```bash
bash .claude/scripts/codex-review.sh cli
```

Runs Codex CLI in the terminal instead of the VS Code panel.

## How it works

1. Detects current branch and collects `git diff` stats
2. Finds matching spec in `specs/` directory
3. Builds a concise review prompt (in Korean)
4. Copies prompt to clipboard via Python tkinter
5. Uses `xdotool` to: focus VS Code → Command Palette → "New Codex Agent" → paste → submit

## License

MIT
