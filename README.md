# claude-beeps

Audible hooks for Claude Code — a rising chime when Claude needs your
input or permission, and a duration-tiered "task complete" sound so
you can hear from another room whether the last turn was quick, normal,
or a long-running task.

Works on Windows (PowerShell) and inside WSL (bash scripts calling
`powershell.exe` over interop, so beeps play through Windows audio
regardless of which side you're running Claude Code on).

## What you get

- **Rising chime** (1200 -> 1500 Hz) when Claude needs your attention
  (`Notification` and `PermissionRequest` events).
- **Three-tier done sound** on the `Stop` event, based on elapsed
  seconds since your last prompt:
  - `< 15s`  -> **Short**  (2 beeps, `C5, E5`)
  - `15..120s` -> **Normal** (4 beeps, `C5, E5, C5, E5`)
  - `> 120s` -> **Long**  (13 beeps, ends on a long `C6` ring)

## Directory contents

```
claude-beeps/
  README.md                            (this file)
  windows/
    notify.ps1                          Notification + PermissionRequest hook
    start.ps1                           UserPromptSubmit hook (records timestamp)
    stop.ps1                            Stop hook (picks tier and plays it)
    settings-hooks-fragment.json        JSON to merge into ~/.claude/settings.json
  wsl/
    notify.sh
    start.sh
    stop.sh
    settings-hooks-fragment.json
    WSL-SETUP.md                        WSL-specific setup guide
  demo/
    beeps.ps1                           Standalone: `. beeps.ps1` then
                                        `Triumphant`, `BellTower`, `Arpeggio`,
                                        `CallResp` to play named sounds
```

## Install (Windows / PowerShell)

1. **Back up your existing settings** (if any):
   ```powershell
   Copy-Item "$env:USERPROFILE\.claude\settings.json" "$env:USERPROFILE\.claude\settings.json.bak"
   ```

2. **Copy the hook scripts** into your `~/.claude/hooks/`:
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\hooks" | Out-Null
   Copy-Item .\windows\notify.ps1 "$env:USERPROFILE\.claude\hooks\notify.ps1"
   Copy-Item .\windows\start.ps1  "$env:USERPROFILE\.claude\hooks\start.ps1"
   Copy-Item .\windows\stop.ps1   "$env:USERPROFILE\.claude\hooks\stop.ps1"
   ```

3. **Merge the hooks block** from `windows/settings-hooks-fragment.json`
   into `%USERPROFILE%\.claude\settings.json`. Replace `<USERNAME>` in
   the command paths with your actual Windows username (or use
   `$env:USERNAME` when scripting the install). Do **not** overwrite
   other keys like `permissions`, `model`, etc. — merge the `hooks`
   object in.

4. **Validate the JSON:**
   ```powershell
   Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw | ConvertFrom-Json | Out-Null
   "JSON OK"
   ```

5. **Pipe-test each script** before launching Claude Code:
   ```powershell
   '{"session_id":"t","hook_event_name":"Notification"}' | powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\notify.ps1"
   '{"session_id":"t"}' | powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\start.ps1"
   '{"session_id":"t"}' | powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\stop.ps1"
   ```
   You should hear the rising chime, then the short "done" chime.

6. **Restart Claude Code** (or open `/hooks` once and dismiss — that
   reloads the config). Mid-session `settings.json` edits aren't picked
   up automatically.

7. **Confirm in `/hooks`** — should show 4 events: `Notification`,
   `PermissionRequest`, `UserPromptSubmit`, `Stop`.

## Install (WSL)

See `wsl/WSL-SETUP.md`. Short version:

- Copy `wsl/*.sh` into `~/.claude/hooks/` inside WSL and `chmod +x` them.
- Requires `jq` (`sudo apt install -y jq`) and working `powershell.exe`
  interop (default on WSL2).
- Merge `wsl/settings-hooks-fragment.json` into `~/.claude/settings.json`
  inside WSL. No path substitution needed — uses `~` throughout.

## Six gotchas (all lessons learned the hard way)

1. **Forward slashes in JSON paths, not backslashes.** Claude Code's
   hook runner pipes the `command` string through a bash-like shell
   that interprets `\` as an escape character. `C:\Users\me\.claude\hooks\start.ps1`
   collapses to `C:Usersme.claudehooksstart.ps1` and the hook silently
   fails. Use `C:/Users/me/.claude/hooks/start.ps1` — PowerShell `-File`
   accepts forward slashes fine.

2. **Both `Notification` AND `PermissionRequest` are needed.**
   `Notification` only fires for in-app attention pings (AskUserQuestion,
   idle timers). Permission prompts use the separate `PermissionRequest`
   event. Wire the same script to both.

3. **Mid-session `settings.json` edits aren't live.** Claude Code reads
   hooks at session start. After editing, run `/hooks` (then dismiss)
   to reload the config, or restart `claude` entirely.

4. **Bypass-permissions mode kills `PermissionRequest`.** If the user
   has `--dangerously-skip-permissions` or accepted bypass mode, no
   permission prompts fire, so the chime doesn't either. Not a bug.

5. **Chat-render wrapping breaks pasted commands.** When copying
   multi-line PowerShell out of a rendered chat block, use the "Copy
   code" button — click-and-drag selection can turn visual wraps into
   real newlines, which breaks parsing mid-token. Or use short helper
   functions / dot-sourced files (see `demo/beeps.ps1`) so paste-able
   lines stay short.

6. **`notify.log` is the smoking gun.** If a beep doesn't play, check
   `%USERPROFILE%\.claude\hooks\notify.log`. Timestamp present but no
   sound = Windows audio problem. No timestamp = hook not wired or not
   loaded (see #3).

## Customizing

- **Sounds:** all beep patterns are `[console]::beep(FREQUENCY_HZ, DURATION_MS)`
  calls. Edit `notify.ps1` and `stop.ps1` directly — no JSON escaping.
- **Thresholds:** the `15` and `120` seconds are bare numbers in
  `stop.ps1`. Change them, save, reload hooks.
- **Note reference:** C5=523, D5=587, E5=659, F5=698, G5=784, A5=880,
  B5=988, C6=1047, D6=1175, E6=1319, G6=1568. Musical intervals in the
  same key sound "chime-like"; random pitches sound like error tones.

## Uninstall

- Delete the four hook entries from `~/.claude/settings.json` (keep the
  rest of the file).
- Optionally delete `~/.claude/hooks/*.ps1` and `~/.claude/hooks/notify.log`.
- Restart Claude Code or reload via `/hooks`.

## How it works

- `start.ps1` (`UserPromptSubmit` event) writes the current time in
  ticks to `~/.claude/hooks/start-<session_id>.txt`. Keyed by
  `session_id` so concurrent Claude Code sessions don't collide.
- `stop.ps1` (`Stop` event) reads that file, computes elapsed seconds,
  picks the tier, plays the beeps, and deletes the timestamp file.
- `notify.ps1` (`Notification` + `PermissionRequest` events) just plays
  the rising chime and appends a line to `notify.log`.

All three scripts read the hook input JSON from stdin using
`[Console]::In.ReadToEnd() | ConvertFrom-Json`. The WSL versions use
`jq` for the same purpose.
