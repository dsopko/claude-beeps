# claude-beeps

Audible hooks for Claude Code — a rising chime when Claude needs your
input or permission, and a duration-tiered "task complete" sound so
you can hear from another room whether the last turn was quick, normal,
or a long-running task.

Works on Windows (PowerShell) and inside WSL (bash scripts calling
`powershell.exe` over interop, so beeps play through Windows audio
regardless of which side you're running Claude Code on).

## Project identity

The file `PROJECT_ID` at the repo root holds a stable identifier
(`cb-<uuid>`) for this project. That identifier is the suffix on every
`.ps1` script name, so hook files installed to `~/.claude/hooks/`
carry their origin in the filename. Two claude-beeps installs from
forks with different IDs can coexist in the same hooks directory
without stepping on each other, and the uninstaller reads
`PROJECT_ID` at runtime to know which files belong to it.

**This project's identifier:** `cb-88a85f67-1b7d-44ad-b9b3-728d218952bc`

If you fork and want a fresh namespace, generate a new GUID
(`[guid]::NewGuid()` in PowerShell), overwrite `PROJECT_ID`, and
rename the five `.ps1` files to match (`notify-<newid>.ps1`, etc.),
then update this README's paths.

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
  README.md                                (this file — human-facing overview)
  CLAUDE.md                                 Claude's operating manual for this repo
  SETUP.md                                  Claude's install runbook
  DEMO.md                                   Claude's demo runbook
  PROJECT_ID                                stable "cb-<uuid>" identifier
  windows/
    install-cb-<PID>.ps1                    Installer (copies hooks + merges settings.json)
    uninstall-cb-<PID>.ps1                  Safe remover (only touches this project's hook groups)
    notify-cb-<PID>.ps1                     Notification + PermissionRequest hook
    start-cb-<PID>.ps1                      UserPromptSubmit hook (records timestamp)
    stop-cb-<PID>.ps1                       Stop hook (picks tier and plays it)
    settings-hooks-fragment.json            JSON to merge into ~/.claude/settings.json
  wsl/
    notify.sh
    start.sh
    stop.sh
    settings-hooks-fragment.json
    uninstall.sh
    WSL-SETUP.md                            WSL-specific setup guide
  demo/
    beeps-cb-<PID>.ps1                      Standalone demo (`. beeps-cb-<PID>.ps1` then
                                            `Triumphant`, `BellTower`, `Arpeggio`,
                                            `CallResp` to play named sounds)
```

`<PID>` is the value in `PROJECT_ID`, currently
`88a85f67-1b7d-44ad-b9b3-728d218952bc`.

## Install

Claude is the installer. Open a terminal, `cd` to the directory where you
want claude-beeps to live, then paste:

```
git clone https://github.com/dsopko/claude-beeps.git
cd claude-beeps
claude "set up claude-beeps"
```

Claude reads `CLAUDE.md`, notices no hooks are installed for this
project's PROJECT_ID yet, and follows `SETUP.md`'s install runbook: a
brief interview (target dir, backup confirmation, WSL skip), one setup
command, pipe-test verification, an offer to run the guided demo
(~10 seconds — plays the "needs input" chime and the three finish-sound
tiers), then hand-off.

**What happens on your machine:**
- Three PowerShell scripts land in `%USERPROFILE%\.claude\hooks\`.
- Your `%USERPROFILE%\.claude\settings.json` gets a backup at
  `settings.json.bak-install-<timestamp>` and then hook entries are
  merged in — nothing else is touched. A pre-existing claude-beeps
  hook group for this same PROJECT_ID is announced by its command
  and replaced in place.
- If a pre-1.0 (bare-name) claude-beeps install is present, the
  installer performs a one-time announced migration. It prints
  `Found pre-1.0 claude-beeps install - migrating`, removes the
  matching hook groups from the four managed events, and deletes
  the legacy `.ps1` files. Each removed group and each deleted
  file appears on the console. Absent those files, the migration
  step does nothing.
- The hooks go live on their own within seconds — the next turn plays
  the "done" chime. No reload or restart needed on current Claude Code
  (see [gotcha 3](#six-gotchas-all-lessons-learned-the-hard-way)).

**Prefer to install without Claude?** The install script is the same
one Claude runs — you can drive it yourself:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\install-cb-88a85f67-1b7d-44ad-b9b3-728d218952bc.ps1
```

Preview mode: append `-DryRun` — nothing is written, but the exact
copies and merges are printed.

**Want to hear the sounds?** Ask Claude in this repo: "demo the beeps"
(or "play the sounds", or "show me what claude-beeps sounds like").
Claude reads `DEMO.md` and plays the "needs input" chime, prints a
tier table, asks you continue/quit, and plays the three finish-sound
tiers back-to-back. Total runtime ~10 seconds — no waiting for
15-second or 2-minute turns to hear the different tiers.

Works before install too: `DEMO.md` has two paths. If hooks are
installed, they fire through the real chain (proves your install
works, leaves entries in `notify.log`, and you'll hear a real fourth
sound at end-of-turn). If hooks aren't installed yet, Claude reads
the beep sequences straight out of the source `.ps1` files and plays
them inline — same audio, no side effects, no need for
`~/.claude/hooks/` to exist yet.

## Install (WSL)

Not yet automated — see `wsl/WSL-SETUP.md`. Short version:

- Copy `wsl/*.sh` into `~/.claude/hooks/` inside WSL and `chmod +x` them.
- Requires `jq` (`sudo apt install -y jq`) and working `powershell.exe`
  interop (default on WSL2).
- Merge `wsl/settings-hooks-fragment.json` into `~/.claude/settings.json`
  inside WSL. No path substitution needed — uses `~` throughout.

(WSL bash scripts don't currently carry the project id in their names;
if you want the same namespace isolation on the WSL side, ask and we
can extend it.)

## Six gotchas (all lessons learned the hard way)

1. **Forward slashes in JSON paths, not backslashes.** Claude Code's
   hook runner pipes the `command` string through a bash-like shell
   that interprets `\` as an escape character. `C:\Users\me\.claude\hooks\...ps1`
   collapses to `C:Usersme.claudehooks...ps1` and the hook silently
   fails. Use `C:/Users/me/.claude/hooks/...ps1` — PowerShell `-File`
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

3. **Mid-session `settings.json` edits *are* live — verify, don't
   assume.** This entry used to claim the opposite. On Claude Code
   v2.1.250, installing mid-session had `PermissionRequest` firing
   15 seconds later with no `/hooks` and no restart (verified
   2026-08-28). Older versions read hooks only at session start, so
   don't assume either behavior — check for evidence:

   - a line in `~/.claude/hooks/notify.log` you didn't pipe in yourself
   - `start-<session_id>.txt` appearing for your *current* session

   Beware the trap that produced the original wrong advice: the
   install pipe-tests and the demo invoke the `.ps1` files directly,
   bypassing the hook runner. Hearing those beeps tells you the
   scripts and your speakers work — nothing more. If a full turn
   passes with neither signal above, *then* run `/hooks` (then
   dismiss) to reload, or restart `claude`.

4. **Bypass-permissions mode kills `PermissionRequest`.** If the user
   has `--dangerously-skip-permissions` or accepted bypass mode, no
   permission prompts fire, so the chime doesn't either. Not a bug.

5. **Chat-render wrapping breaks pasted commands.** When copying
   multi-line PowerShell out of a rendered chat block, use the "Copy
   code" button — click-and-drag selection can turn visual wraps into
   real newlines, which breaks parsing mid-token. Or use short helper
   functions / dot-sourced files (see the demo `beeps-cb-<PID>.ps1`) so
   paste-able lines stay short.

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
by editing that string in `settings.json`; the change takes effect
within seconds on current Claude Code, and `/hooks` or a restart is
only needed if it doesn't (see [gotcha 3](#six-gotchas-all-lessons-learned-the-hard-way)).
Reference: matcher list and payload fields from Claude Code's official
hooks docs (`code.claude.com/docs/en/hooks`).

**Log helps diagnosis.** `notify-cb-<PID>.ps1` writes each firing to
`~/.claude/hooks/notify.log` including the `notification_type` and the
`notification_text` (Claude's human-readable message). If a subtype
you'd like to beep on isn't in the matcher yet, watch the log during
normal use — you'll see the exact string to add.

## Customizing

- **Sounds:** all beep patterns are `[console]::beep(FREQUENCY_HZ, DURATION_MS)`
  calls. Edit `notify-cb-<PID>.ps1` and `stop-cb-<PID>.ps1` directly
  — no JSON escaping.
- **Thresholds:** the `15` and `120` seconds are bare numbers in
  `stop-cb-<PID>.ps1`. Change them and save — the hook scripts are
  read fresh on every firing, so edits to the installed `.ps1` files
  take effect on the next event with no reload at all. (Only
  `settings.json` changes involve the config load; editing the copies
  under `windows/` needs a reinstall to sync them across.)
- **Notification subtypes:** see the section above — edit the `matcher`
  string on the Notification hook in `settings.json`.
- **Note reference:** C5=523, D5=587, E5=659, F5=698, G5=784, A5=880,
  B5=988, C6=1047, D6=1175, E6=1319, G6=1568. Musical intervals in the
  same key sound "chime-like"; random pitches sound like error tones.

## Uninstall

The `Notification`, `PermissionRequest`, `UserPromptSubmit`, and `Stop`
events can each hold **multiple hook groups** — Claude Code itself adds
some internal HTTP hooks under those same events. Don't wipe the whole
event key; remove only the hook groups whose `command` references this
project's scripts.

**Fingerprint of a claude-beeps hook (this project):** `type: "command"`
where the inner `hooks[].command` names `notify-cb-<PID>.ps1`,
`start-cb-<PID>.ps1`, or `stop-cb-<PID>.ps1` (or the `.sh` equivalents
on WSL). The uninstaller also matches the anchored legacy pattern
`\.claude/hooks/(notify|start|stop).ps1` (or `.sh`), so a pre-GUID
install still cleans up — but only when the command path resolves
inside the Claude hooks directory. Third-party hooks whose command
merely ends with `notify.ps1`, `start.ps1`, or `stop.ps1` — for
example `restart.ps1`, `.../slack-notify.ps1`, or a
`.../hooks/autostop.ps1` outside `.claude` — are never touched.
Anything else in those arrays (HTTP hooks, other projects' hooks
with different GUIDs, different paths) belongs to something else —
leave it alone. Every removal is announced on the console with the
group's command, so no eviction is ever silent.

**Ask Claude:** in a session started from this repo, say "uninstall
claude-beeps" / "start clean" / "remove". Claude follows CLAUDE.md's
operating-mode instructions and runs the uninstaller for you.

**Or run it yourself:**

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\windows\uninstall-cb-88a85f67-1b7d-44ad-b9b3-728d218952bc.ps1
```
```bash
# WSL
bash ./wsl/uninstall.sh
```

The Windows uninstaller reads `PROJECT_ID` at runtime, so if you forked
and generated a new GUID, the same script uninstalls whatever ID is
current in `PROJECT_ID`.

Both scripts back up `settings.json` first, filter out only this
project's hook groups, drop any event key whose array ends up empty,
delete the matching `.ps1`/`.sh` scripts and `notify.log`, and validate
the resulting JSON.

**Manual:** edit `~/.claude/settings.json` and for each of the four events:

1. In the event's array, delete the hook group whose inner `command`
   contains one of this project's script names.
2. If that group was the only entry, remove the event key entirely.
3. If other groups remain, keep the event key with just those.

Then optionally delete `~/.claude/hooks/notify-cb-<PID>.ps1`,
`~/.claude/hooks/start-cb-<PID>.ps1`, `~/.claude/hooks/stop-cb-<PID>.ps1`,
and `~/.claude/hooks/notify.log`.

The removal takes effect within seconds on current Claude Code. If the
beeps outlive it, run `/hooks` (and dismiss) or restart Claude Code.

## How it works

- `start-cb-<PID>.ps1` (`UserPromptSubmit` event) writes the current
  time in ticks to `~/.claude/hooks/start-<session_id>.txt`. Keyed by
  `session_id` so concurrent Claude Code sessions don't collide.
- `stop-cb-<PID>.ps1` (`Stop` event) reads that file, computes elapsed
  seconds, picks the tier, plays the beeps, and deletes the timestamp
  file.
- `notify-cb-<PID>.ps1` (`Notification` + `PermissionRequest` events)
  plays the rising chime and appends
  `{timestamp} {event} [{notification_type}] {notification_text}` to
  `notify.log`. The `matcher` field on the Notification hook filters
  which subtypes reach this script — Claude Code short-circuits before
  even spawning PowerShell for subtypes that don't match.

All three scripts read the hook input JSON from stdin using
`[Console]::In.ReadToEnd() | ConvertFrom-Json`. The WSL versions use
`jq` for the same purpose.
