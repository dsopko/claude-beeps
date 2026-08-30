# claude-beeps — operating manual for Claude Code

This repo is a Claude Code **plugin** that plays audible chimes: a
rising tone when Claude needs input, and a duration-tiered "done"
sound when a turn finishes. See README.md for the human-facing pitch;
this file tells you (Claude) how to behave when a user runs a session
in this directory.

The repo root is the plugin root: `.claude-plugin/plugin.json` is the
manifest, `hooks/hooks.json` registers the hooks, `scripts/*.ps1` are
the hook bodies. The repo doubles as its own marketplace via
`.claude-plugin/marketplace.json`. There is no installer — the plugin
system is the installer. Nothing in this project ever writes to the
user's `settings.json`.

## Install mode detection

Check whether the plugin is installed:

```
claude plugin list 2>$null | Select-String claude-beeps
```

(or on any platform: `claude plugin list` and look for `claude-beeps`;
the plugin cache at `~/.claude/plugins/cache/claude-beeps/` existing is
corroborating evidence, not proof of *enabled*.)

**Install mode — not installed:** read **SETUP.md** and run the install
interview. Don't offer to do anything else until the install is
complete or the user declines it.

**Operating mode — installed:** greet in one line and ask what the
user wants — common answers include:

- **"Update"** or **"reinstall"** — `/plugin marketplace update
  claude-beeps`, then `/reload-plugins`. Users only receive a new
  version when `version` in `.claude-plugin/plugin.json` was bumped.
- **"Uninstall"**, **"remove"**, or **"start clean"** —
  `/plugin uninstall claude-beeps@claude-beeps`. Nothing else to clean
  up; optionally delete the plugin data dir
  (`~/.claude/plugins/data/<id>/` — holds `notify.log` and any
  leftover `start-*.txt`).
- **"Change the sounds / thresholds / matcher"** — edit the source:
  sound patterns are `[console]::beep(HZ, MS)` calls in
  `scripts/notify.ps1` and `scripts/stop.ps1`; thresholds `15` and
  `120` are bare numbers in `scripts/stop.ps1`; the Notification
  matcher lives in `hooks/hooks.json`. Then ship it: bump `version` in
  `.claude-plugin/plugin.json`, `/plugin marketplace update
  claude-beeps`, `/reload-plugins`. For rapid iteration suggest
  `claude --plugin-dir <this repo>` instead.
- **"What changed?"** — diff this repo against the installed copy
  under `~/.claude/plugins/cache/claude-beeps/claude-beeps/<version>/`.
- **"Demo the beeps"**, **"play the sounds"** — read **DEMO.md** and
  follow it exactly. Don't paraphrase the runbook into a shorter
  version; the pacing and the on-screen text were tuned to line up
  with the audio.

## Rules

1. **Never edit the installed copy** under `~/.claude/plugins/cache/`.
   It is replaced wholesale on every plugin update. All changes go in
   this repo, then reach the install via a version bump + marketplace
   update (or `--plugin-dir` during development).
2. **Never write to `~/.claude/settings.json` on this project's
   behalf.** The plugin system owns registration: Claude Code records
   an `enabledPlugins` entry itself at install time.
3. **Never claim the beep is live without evidence — and never claim
   it isn't, either.** Pipe-testing the `.ps1` files or playing the
   demo proves only that the scripts run and the audio device works —
   it says nothing about whether the plugin's hooks are registered.
   Real evidence, either one:
   - a line in the plugin's `notify.log` (under
     `~/.claude/plugins/data/<id>/`) that you did **not** pipe in
     yourself — a real `PermissionRequest` or `Notification` entry
   - `start-<current session_id>.txt` appearing in that data dir after
     the user submits a prompt (written by the `UserPromptSubmit` hook)

   If neither signal shows up after a full turn, have the user run
   `/reload-plugins`, or restart claude.
4. **Match the Notification hook's `matcher` field to the recommended
   set** unless the user asks otherwise: `agent_needs_input|elicitation_dialog|elicitation_url_dialog|quota_auto_resume_stale|quota_auto_resume_disabled`.
   Firing on every subtype means a ~60s idle-prompt nag after every
   turn and a double-beep on permission events. Details in README's
   "Notification subtype filtering" section.
5. **Bypass-permissions mode kills `PermissionRequest`.** If the user
   uses `--dangerously-skip-permissions` or accepted bypass mode, they
   won't hear the chime on permission prompts — it's not a bug and
   don't try to "fix" it.
6. **Keep the non-Windows guard.** Plugin hooks fire on every OS
   (there is no platform gating in the plugin system), so every script
   in `scripts/` opens with `if ($env:OS -ne 'Windows_NT') { exit 0 }`.
   Never remove it, and add it to any new hook script.

## Scripts

| Task | Command |
|---|---|
| Validate the plugin + marketplace manifests | `claude plugin validate .` |
| Load the working copy without installing | `claude --plugin-dir <this repo>` |
| Pipe-test the notify hook (repo copy) | `'{"session_id":"t","hook_event_name":"Notification","notification_type":"agent_needs_input","notification_text":"test"}' \| powershell -ExecutionPolicy Bypass -File .\scripts\notify.ps1` |
| Update an install after a version bump | `/plugin marketplace update claude-beeps` then `/reload-plugins` |
| Uninstall | `/plugin uninstall claude-beeps@claude-beeps` |

## Files

- `.claude-plugin/plugin.json` — manifest; bump `version` to ship any
  change to installed users.
- `.claude-plugin/marketplace.json` — makes the repo installable via
  `/plugin marketplace add dsopko/claude-beeps`.
- `hooks/hooks.json` — the four hook registrations, exec form
  (`command` + `args`, no shell), paths via `${CLAUDE_PLUGIN_ROOT}`.
- `scripts/` — the three hook bodies. State and log go to
  `${CLAUDE_PLUGIN_DATA}` (survives updates); fallback
  `~/.claude/hooks/` when run outside the hook runner.
- `README.md` — human-facing overview.
- `SETUP.md` — install runbook (follow in install mode).
- `DEMO.md` — demo runbook (follow when the user asks to hear the
  sounds).
- `demo/beeps.ps1` — standalone dot-source demo of the named sounds
  (Triumphant, BellTower, Arpeggio, CallResp). Never invoked by the
  hooks; purely a listening tool for the user.
- `.claude/skills/commit-messages/` — commit-message style for
  developing this repo; not a plugin component.
