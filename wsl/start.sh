#!/usr/bin/env bash
# UserPromptSubmit hook - records turn start time keyed by session_id.
sid=$(jq -r '.session_id // "default"' 2>/dev/null)
[ -z "$sid" ] && sid="default"
date +%s > "$HOME/.claude/hooks/start-$sid.txt"
