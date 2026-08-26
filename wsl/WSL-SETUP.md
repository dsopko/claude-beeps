# Claude Code beep hooks — WSL (Ubuntu) setup

Mirror of the Windows hook setup, for when Claude Code runs inside WSL.
Beeps are played through Windows audio by invoking `powershell.exe` over
WSL interop, so you hear the same chimes you hear on the Windows side.

## Prerequisites

- WSL2 + Ubuntu actually running (`wsl -l -v` shows it as Running, not
  Stopped — if it won't start, fix the BIOS virtualization /
  "Virtual Machine Platform" issue first; this guide can't help with that).
- `jq` installed inside WSL: `sudo apt update && sudo apt install -y jq`
- `powershell.exe` reachable from inside WSL (`which powershell.exe`
  should print something under `/mnt/c/...`). This is default on
  WSL2 — no setup needed.

## File layout (inside WSL)

```
~/.claude/
  settings.json        # WSL-side Claude Code config
  hooks/
    notify.sh          # Notification + PermissionRequest -> rising chime
    start.sh           # UserPromptSubmit -> records turn start timestamp
    stop.sh            # Stop -> tier by elapsed seconds, plays short/normal/long
    notify.log         # auto-created, audit trail for chime fires
```

## Step 1 — create the scripts

From inside WSL:

```bash
mkdir -p ~/.claude/hooks
```

### `~/.claude/hooks/notify.sh`

```bash
#!/usr/bin/env bash
evt=$(jq -r '.hook_event_name // "unknown"' 2>/dev/null)
echo "$(date '+%Y-%m-%d %H:%M:%S') $evt fired" >> "$HOME/.claude/hooks/notify.log"
powershell.exe -c "[console]::beep(1200,150); [console]::beep(1500,200)"
```

### `~/.claude/hooks/start.sh`

```bash
#!/usr/bin/env bash
sid=$(jq -r '.session_id // "default"' 2>/dev/null)
[ -z "$sid" ] && sid="default"
date +%s > "$HOME/.claude/hooks/start-$sid.txt"
```

### `~/.claude/hooks/stop.sh`

```bash
#!/usr/bin/env bash
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
    # Long (>2 min) — 13-beep ascending+descending finish
    powershell.exe -c "[console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,180); [console]::beep(784,180); [console]::beep(880,180); [console]::beep(1047,180); [console]::beep(880,180); [console]::beep(784,180); [console]::beep(659,180); [console]::beep(1047,1300)"
elif [ "$elapsed" -ge 15 ]; then
    # Normal (15s..2min) — 4-beep CECE
    powershell.exe -c "[console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,360)"
else
    # Short (<15s) — 2-beep CE
    powershell.exe -c "[console]::beep(523,180); [console]::beep(659,360)"
fi
```

### Make them executable

```bash
chmod +x ~/.claude/hooks/notify.sh ~/.claude/hooks/start.sh ~/.claude/hooks/stop.sh
```

## Step 2 — wire them up in `~/.claude/settings.json`

If you already have a `~/.claude/settings.json` in WSL, **merge** the
`hooks` block below into it — don't overwrite existing `permissions`,
`model`, etc. If the file doesn't exist, this whole content is fine as-is.

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/notify.sh" }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/notify.sh" }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/start.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/stop.sh" }
        ]
      }
    ]
  }
}
```

## Step 3 — verify before launching Claude Code

Pipe-test each script with a synthetic stdin payload (these run the
scripts exactly the way Claude Code will):

```bash
# Notification (should beep rising chime)
echo '{"session_id":"verify","hook_event_name":"Notification"}' | bash ~/.claude/hooks/notify.sh

# Start (writes a timestamp file)
echo '{"session_id":"verify"}' | bash ~/.claude/hooks/start.sh
ls ~/.claude/hooks/start-verify.txt

# Stop (reads timestamp, plays short tier since elapsed ~0s)
echo '{"session_id":"verify"}' | bash ~/.claude/hooks/stop.sh

# Force a fake "long task" by writing a past timestamp, then stopping
echo $(($(date +%s) - 200)) > ~/.claude/hooks/start-fake.txt
echo '{"session_id":"fake"}' | bash ~/.claude/hooks/stop.sh
# (should play the 13-beep long pattern)

# Verify JSON syntax
python3 -c "import json,sys; json.load(open('$HOME/.claude/settings.json')); print('JSON OK')"
```

## Step 4 — launch Claude Code inside WSL

```bash
claude
```

After it starts, run `/hooks` once to confirm all four events show up
(`Notification`, `PermissionRequest`, `UserPromptSubmit`, `Stop`).

## Troubleshooting

- **No beep but log shows fire:** Windows audio side issue — try the
  same `powershell.exe -c "[console]::beep(800,300)"` directly from a
  WSL shell. If silent, Windows audio is muted or `powershell.exe`
  interop is broken.
- **No beep and no log entry:** hook isn't loaded. Run `/hooks` to
  reload the config, or restart `claude`.
- **`jq: command not found`:** `sudo apt install -y jq`.
- **`PermissionRequest` doesn't fire but `Notification` does (or vice
  versa):** different Claude Code versions emit different events for
  permission prompts. Both are wired to the same script here, so one of
  them should always cover it.

## Notes

- Timestamps are stored in `~/.claude/hooks/start-<session_id>.txt`
  and removed by `stop.sh`. Concurrent WSL sessions won't collide.
- Edit thresholds (15s, 120s) directly in `stop.sh` — no JSON-escape
  pain.
- The Windows-side setup at `C:\Users\daves\.claude\hooks\` is
  independent — running Claude Code in PowerShell and in WSL each use
  their own hook directory and `settings.json`.
