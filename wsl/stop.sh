#!/usr/bin/env bash
# Stop hook - reads timestamp from start.sh, picks beep tier by elapsed seconds:
#   < 15s     -> Short  (2 beeps)
#   15s..120s -> Normal (4 beeps)
#   > 120s    -> Long   (13 beeps)
sid=$(jq -r '.session_id // "default"' 2>/dev/null)
[ -z "$sid" ] && sid="default"
f="$HOME/.claude/hooks/start-$sid.txt"

elapsed=0
if [ -f "$f" ]; then
    start=$(cat "$f")
    now=$(date +%s)
    elapsed=$((now - start))
    rm -f "$f"
fi

if [ "$elapsed" -gt 120 ]; then
    # Long (>2 min) - 13-beep ascending+descending finish
    powershell.exe -c "[console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,180); [console]::beep(784,180); [console]::beep(880,180); [console]::beep(1047,180); [console]::beep(880,180); [console]::beep(784,180); [console]::beep(659,180); [console]::beep(1047,1300)"
elif [ "$elapsed" -ge 15 ]; then
    # Normal (15s..2min) - 4-beep CECE
    powershell.exe -c "[console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,360)"
else
    # Short (<15s) - 2-beep CE
    powershell.exe -c "[console]::beep(523,180); [console]::beep(659,360)"
fi
