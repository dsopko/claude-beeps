#!/usr/bin/env bash
# Notification + PermissionRequest hook - plays "needs input" rising chime
# via powershell.exe over WSL interop so Windows audio plays it.
evt=$(jq -r '.hook_event_name // "unknown"' 2>/dev/null)
echo "$(date '+%Y-%m-%d %H:%M:%S') $evt fired" >> "$HOME/.claude/hooks/notify.log"
powershell.exe -c "[console]::beep(1200,150); [console]::beep(1500,200)"
