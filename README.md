# claude-beeps

Audible hooks for Claude Code — a rising chime when Claude needs your
input or permission, and a duration-tiered "task complete" sound so
you can hear from another room whether the last turn was quick, normal,
or a long-running task.

claude-beeps is a **Claude Code plugin**, installed with two `/plugin`
commands.

**Windows only.** The sounds use the Windows-only `[console]::beep`
.NET API. The hooks exit quietly on other platforms (see
[Troubleshooting](#troubleshooting)).

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

## Install

The repo is its own single-plugin marketplace. In any Claude Code
session:

```
/plugin marketplace add dsopko/claude-beeps
/plugin install claude-beeps@claude-beeps
```

Pick **user scope** when prompted — you want beeps on your machine in
every project. (Project scope would enable the hooks for everyone who
clones that repo, including Linux cloud sessions; the guard keeps that
harmless, but it's noise nobody asked for.)

If the install summary says `Run /reload-plugins to activate.`, run
that. From a shell instead: `claude plugin install
claude-beeps@claude-beeps` after adding the marketplace once.

**Want to hear the sounds first?** Clone the repo and ask Claude in it:
"demo the beeps" (or "play the sounds"). Claude reads `DEMO.md` and
plays the "needs input" chime, prints a tier table, asks you
continue/quit, and plays the three finish-sound tiers back-to-back.
Total runtime ~10 seconds, works installed or not.

**Developing / customizing?** Load your working copy directly, no
install:

```
claude --plugin-dir /path/to/claude-beeps
```

## Directory contents

```
claude-beeps/
  README.md                 (this file — human-facing overview)
  CLAUDE.md                  Claude's operating manual for this repo
  SETUP.md                   Claude's install runbook
  DEMO.md                    Claude's demo runbook
  .claude-plugin/
    plugin.json              plugin manifest (name, version — bump to ship updates)
    marketplace.json         makes this repo installable as its own marketplace
  hooks/
    hooks.json               the four hook registrations (exec form, no shell)
  scripts/
    notify.ps1               Notification + PermissionRequest hook
    start.ps1                UserPromptSubmit hook (records timestamp)
    stop.ps1                 Stop hook (picks tier and plays it)
  demo/
    beeps.ps1                standalone dot-source demo of named sounds
                             (Triumphant, BellTower, Arpeggio, CallResp)
  .claude/skills/
    commit-messages/         repo development convention, not part of the plugin
```

## How it works

- Claude Code copies the plugin to
  `~/.claude/plugins/cache/claude-beeps/claude-beeps/<version>/` on
  install and records one `enabledPlugins` entry in the settings scope
  you chose.
- `hooks/hooks.json` registers the four events. Each hook uses **exec
  form** — `"command": "powershell"` plus an `args` array — so no shell
  ever parses the command line: backslashes, spaces in paths, and
  special characters in usernames are all safe, and Git Bash is not
  required. `${CLAUDE_PLUGIN_ROOT}` resolves to the versioned cache
  directory at fire time.
- `start.ps1` (`UserPromptSubmit`) writes the current time in ticks to
  `start-<session_id>.txt`, keyed by session so concurrent sessions
  don't collide. `stop.ps1` (`Stop`) reads it, computes elapsed
  seconds, picks the tier, plays it, deletes the file. `notify.ps1`
  (`Notification` + `PermissionRequest`) plays the rising chime and
  appends `{timestamp} {event} [{notification_type}]
  {notification_text}` to `notify.log`.
- State and log live in `${CLAUDE_PLUGIN_DATA}` — a per-plugin data
  directory Claude Code exports to hook processes
  (`~/.claude/plugins/data/<id>/`). It survives plugin updates, unlike
  the cache directory. When the scripts run outside the hook runner
  (pipe-tests, the demo), the variable is absent and they fall back to
  `~/.claude/hooks/`.
- All three scripts read the hook input JSON from stdin via
  `[Console]::In.ReadToEnd() | ConvertFrom-Json`.

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

**Recommended matcher (in `hooks/hooks.json`):**

```json
"Notification": [
  {
    "matcher": "agent_needs_input|elicitation_dialog|elicitation_url_dialog|quota_auto_resume_stale|quota_auto_resume_disabled",
    "hooks": [ { "type": "command", "command": "powershell", "args": ["..."] } ]
  }
]
```

The matcher is a regex-style alternation string. To change which
subtypes beep, edit that string in your clone's `hooks/hooks.json` and
ship yourself the update (see [Customizing](#customizing)).
Reference: matcher list and payload fields from Claude Code's official
hooks docs (`code.claude.com/docs/en/hooks`).

**Log helps diagnosis.** `notify.ps1` writes each firing to
`notify.log` including the `notification_type` and the
`notification_text` (Claude's human-readable message). If a subtype
you'd like to beep on isn't in the matcher yet, watch the log during
normal use — you'll see the exact string to add.

## Customizing

All customization is an edit in your clone of this repo, then a
version bump to ship it to your installed copy:

1. Edit the source — sounds and thresholds in `scripts/`, subtype
   matcher in `hooks/hooks.json`.
2. Bump `version` in `.claude-plugin/plugin.json` (users only receive
   updates when the version changes).
3. `/plugin marketplace update claude-beeps`, then `/reload-plugins`.

For rapid iteration skip the install entirely and run
`claude --plugin-dir /path/to/claude-beeps` — edits to a `--plugin-dir`
plugin are picked up with `/reload-plugins`, no version bump needed.

**Never edit the installed copy** under `~/.claude/plugins/cache/` —
it's replaced wholesale on every plugin update.

What to edit:

- **Sounds:** all beep patterns are `[console]::beep(FREQUENCY_HZ, DURATION_MS)`
  calls in `scripts/notify.ps1` and `scripts/stop.ps1` — no JSON escaping.
- **Thresholds:** the `15` and `120` seconds are bare numbers in
  `scripts/stop.ps1`.
- **Note reference:** C5=523, D5=587, E5=659, F5=698, G5=784, A5=880,
  B5=988, C6=1047, D6=1175, E6=1319, G6=1568. Musical intervals in the
  same key sound "chime-like"; random pitches sound like error tones.

## Uninstall

```
/plugin uninstall claude-beeps@claude-beeps
```

Optionally delete the plugin's data directory afterwards
(`notify.log` and any leftover `start-*.txt` under
`~/.claude/plugins/data/<id>/`).

Removing the marketplace (`/plugin marketplace remove claude-beeps`)
also uninstalls the plugin.

## Troubleshooting

1. **Verify liveness from evidence, don't assume.** Piping JSON into
   the `.ps1` files yourself proves the scripts and your speakers work
   — nothing more. Proof the plugin's hooks are actually registered
   and firing is:

   - a line in the plugin's `notify.log` (under
     `~/.claude/plugins/data/<id>/`) you didn't pipe in yourself
   - `start-<session_id>.txt` appearing there for your *current*
     session after you submit a prompt

   If a full turn passes with neither signal, run `/reload-plugins`,
   or restart `claude`.

2. **`notify.log` is the smoking gun.** If a beep doesn't play, check
   `notify.log` in the plugin data dir (or `~/.claude/hooks/` for
   pipe-tests). Timestamp present but no sound = Windows audio
   problem. No timestamp = hook not wired or not loaded (see #1).

3. **Plugin hooks fire on every OS.** There is no platform-gating
   field anywhere in the plugin system — not in `plugin.json`, not in
   marketplace entries, not in `hooks.json`. That's why every script
   opens with `if ($env:OS -ne 'Windows_NT') { exit 0 }`: anywhere
   PowerShell exists off-Windows (pwsh on Linux/macOS, cloud
   sessions), the hook exits silently instead of erroring every turn.
   Where `powershell` isn't on `PATH` at all, the spawn fails as a
   non-blocking error notice — annoying but harmless. Don't enable the
   plugin on non-Windows machines.
