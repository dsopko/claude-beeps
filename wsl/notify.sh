#!/usr/bin/env bash
# Notification + PermissionRequest hook - plays "needs input" rising chime
# via powershell.exe over WSL interop so Windows audio plays it.
# Also logs event, notification_type, and notification_text for diagnosis.
payload=$(cat)
evt=$(echo "$payload"  | jq -r '.hook_event_name // "unknown"'   2>/dev/null)
type=$(echo "$payload" | jq -r '.notification_type // ""'         2>/dev/null)
text=$(echo "$payload" | jq -r '.notification_text // ""'         2>/dev/null)

typePart=""
[ -n "$type" ] && typePart="[$type] "
echo "$(date '+%Y-%m-%d %H:%M:%S') $evt ${typePart}${text}" >> "$HOME/.claude/hooks/notify.log"

powershell.exe -c "[console]::beep(1200,150); [console]::beep(1500,200)"
