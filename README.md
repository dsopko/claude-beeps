# claude-beeps

Audible hooks for Claude Code — a rising chime when Claude needs your
input or permission, and a duration-tiered "task complete" sound so
you can hear from another room whether the last turn was quick, normal,
or a long-running task.

Works on Windows (PowerShell) and inside WSL (bash scripts calling
`powershell.exe` over interop, so beeps play through Windows audio
regardless of which side you're running Claude Code on).

## What you get

- **Rising chime** (1200 -> 1500 Hz) when Claude actually needs you —
  when it asks a question (`agent_needs_input`), when an MCP server
  needs input (`elicitation_dialog`, `elicitation_url_dialog`), when a
  quota auto-resume is stuck (`quota_auto_resume_stale`,
  `quota_auto_resume_disabled`), and when Claude needs permission for a
  tool call (via the separate `PermissionRequest` event). Idle-attention
  nags are silenced. See [Notification subtype filtering](#notification-subtype-filtering).
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
    uninstall.ps1                       Safe remover (only touches our hook groups)
  wsl/
    notify.sh
    start.sh
    stop.sh
    settings-hooks-fragment.json
    uninstall.sh
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

2. **Both `Notification` AND `PermissionRequest` are needed, but
   `Notification` needs a matcher.** `Notification` fires for twelve
   subtypes — including a ~60s post-turn idle nag (`idle_prompt`) that
   will drive you crazy without a filter. Permission prompts use the
   separate `PermissionRequest` event, and also re-fire ~6s later as
   `Notification(permission_prompt)`, which would double-beep. We wire
   both events but restrict the `Notification` hook to a whitelist via
   the `matcher` field. See [Notification subtype filtering](#notification-subtype-filtering)
   for the full list and the recommended matcher string.

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

## Notification subtype filtering

Claude Code's `Notification` event carries a `notification_type` field
identifying which of twelve subtypes fired. We use the hook's `matcher`
field to whitelist the ones that mean "you need to do something":

| Subtype | What fires it | We beep? |
|---|---|---|
| `permission_prompt` | Claude Code shows a permission dialog | No — `PermissionRequest` fires ~6s earlier for the same event; skip to avoid double-beep |
| `idle_prompt` | Claude has been idle ~60s post-turn and pokes you | No — this is the annoying one |
| `auth_success` | OAuth / auth flow completes | No — informational |
| `elicitation_dialog` | An MCP server needs your input via dialog | **Yes** |
| `elicitation_url_dialog` | An MCP server needs you to visit a URL (usually for auth) | **Yes** |
| `elicitation_complete` | An MCP elicitation interaction finishes | No — informational |
| `elicitation_response` | You respond to an MCP elicitation | No — informational |
| `agent_needs_input` | A subagent or agent needs input to proceed | **Yes** |
| `agent_completed` | A subagent or agent finishes | No — `Stop` hook already handles turn-complete beeps |
| `quota_auto_resume_fired` | Quota auto-resume activated and resumed the session | No — informational (working as designed) |
| `quota_auto_resume_stale` | Quota auto-resume finds the session stuck / stale | **Yes** — session waiting on you |
| `quota_auto_resume_disabled` | Quota auto-resume is off or unavailable | **Yes** — nothing will happen without you |

**Recommended matcher (in `settings-hooks-fragment.json`):**

```json
"Notification": [
  {
    "matcher": "agent_needs_input|elicitation_dialog|elicitation_url_dialog|quota_auto_resume_stale|quota_auto_resume_disabled",
    "hooks": [ { "type": "command", "command": "..." } ]
  }
]
```

The matcher is a regex-style alternation string. Add or remove subtypes
by editing that string in `settings.json`, then run `/hooks` or restart
Claude Code to reload. Reference: matcher list and payload fields from
Claude Code's official hooks docs (`code.claude.com/docs/en/hooks`).

**Log helps diagnosis.** `notify.ps1` writes each firing to
`~/.claude/hooks/notify.log` including the `notification_type` and the
`notification_text` (Claude's human-readable message). If a subtype
you'd like to beep on isn't in the matcher yet, watch the log during
normal use — you'll see the exact string to add.

## Customizing

- **Sounds:** all beep patterns are `[console]::beep(FREQUENCY_HZ, DURATION_MS)`
  calls. Edit `notify.ps1` and `stop.ps1` directly — no JSON escaping.
- **Thresholds:** the `15` and `120` seconds are bare numbers in
  `stop.ps1`. Change them, save, reload hooks.
- **Notification subtypes:** see the section above — edit the `matcher`
  string on the Notification hook in `settings.json`.
- **Note reference:** C5=523, D5=587, E5=659, F5=698, G5=784, A5=880,
  B5=988, C6=1047, D6=1175, E6=1319, G6=1568. Musical intervals in the
  same key sound "chime-like"; random pitches sound like error tones.

## Uninstall

The `Notification`, `PermissionRequest`, `UserPromptSubmit`, and `Stop`
events can each hold **multiple hook groups** — Claude Code itself adds
some internal HTTP hooks under those same events. Don't wipe the whole
event key; remove only the hook groups whose `command` references
claude-beeps scripts.

**Fingerprint of a claude-beeps hook:** `type: "command"` where the
inner `hooks[].command` mentions `notify.ps1`, `start.ps1`, or `stop.ps1`
(or the `.sh` equivalents on WSL). Anything else in those arrays
(HTTP hooks, other tools' commands, different paths) belongs to
something else — leave it alone.

**Automated (recommended):**

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\windows\uninstall.ps1
```
```bash
# WSL
bash ./wsl/uninstall.sh
```

Both scripts back up `settings.json` first, filter out only the claude-beeps
hook groups, drop any event key whose array ends up empty, delete the
`.ps1`/`.sh` scripts and `notify.log`, and validate the resulting JSON.

**Manual:** edit `~/.claude/settings.json` and for each of the four events:

1. In the event's array, delete the hook group whose inner `command`
   contains one of our script names.
2. If that group was the only entry, remove the event key entirely.
3. If other groups remain, keep the event key with just those.

Then optionally delete `~/.claude/hooks/{notify,start,stop}.ps1` and
`~/.claude/hooks/notify.log`.

Restart Claude Code (or run `/hooks` and dismiss) to reload the config.

## How it works

- `start.ps1` (`UserPromptSubmit` event) writes the current time in
  ticks to `~/.claude/hooks/start-<session_id>.txt`. Keyed by
  `session_id` so concurrent Claude Code sessions don't collide.
- `stop.ps1` (`Stop` event) reads that file, computes elapsed seconds,
  picks the tier, plays the beeps, and deletes the timestamp file.
- `notify.ps1` (`Notification` + `PermissionRequest` events) plays the
  rising chime and appends `{timestamp} {event} [{notification_type}] {notification_text}`
  to `notify.log`. The `matcher` field on the Notification hook filters
  which subtypes reach this script — Claude Code short-circuits before
  even spawning PowerShell for subtypes that don't match.

All three scripts read the hook input JSON from stdin using
`[Console]::In.ReadToEnd() | ConvertFrom-Json`. The WSL versions use
`jq` for the same purpose.
