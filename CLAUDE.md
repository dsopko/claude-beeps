# claude-beeps — operating manual for Claude Code

This folder is a set of Claude Code hooks that play audible chimes:
a rising tone when Claude needs input, and a duration-tiered "done"
sound when a turn finishes. See README.md for the human-facing pitch;
this file tells you (Claude) how to behave when a user runs a session
in this directory.

## Install mode detection

Read `PROJECT_ID` at the repo root. Its content (something like
`cb-<uuid>`) is this project's identifier. The three hook scripts
installed to `~/.claude/hooks/` are named `notify-<PROJECT_ID>.ps1`,
`start-<PROJECT_ID>.ps1`, and `stop-<PROJECT_ID>.ps1`.

**You are in install mode when `~/.claude/hooks/notify-<PROJECT_ID>.ps1`
does not exist.** Your first move in install mode: read **SETUP.md**
and run the install interview. Don't offer to do anything else until
the install is complete or the user declines it.

**You are in operating mode when that file exists.** Greet in one
line, note the installed project id, and ask what the user wants —
common answers include:

- **"Reinstall"** or **"update the installed files"** — re-run
  `windows/install-<PROJECT_ID>.ps1`. Idempotent; overwrites the three
  hook scripts and refreshes the settings.json hook groups without
  clobbering unrelated hooks. Remind them to run `/hooks` afterwards.
- **"Uninstall"**, **"remove"**, or **"start clean"** — run
  `windows/uninstall-<PROJECT_ID>.ps1`. It backs up settings.json,
  filters out only this project's hook groups, deletes the three hook
  scripts and `notify.log`, and validates the result. Remind them to
  run `/hooks` afterwards.
- **"Change the sounds / thresholds / matcher"** — edit the source
  files under `windows/` first, then reinstall to sync. Sound patterns
  are `[console]::beep(HZ, MS)`; thresholds `15` and `120` are bare
  numbers in `stop-<PROJECT_ID>.ps1`; the Notification matcher lives
  in `settings-hooks-fragment.json` and gets copied into the user's
  settings.json on install.
- **"What changed?"** — diff installed vs source: the source-of-truth
  file is the settings-hooks-fragment.json plus the three hook scripts
  under `windows/`. Compare against `~/.claude/hooks/notify-<PROJECT_ID>.ps1`
  etc. and the hook groups in `~/.claude/settings.json`.
- **"Demo the beeps"**, **"play the sounds"**, **"show me what it
  sounds like"** — read **DEMO.md** and follow it exactly. It plays
  the notification chime and the three finish-sound tiers through the
  installed hooks, with a continue/quit prompt in the middle. Don't
  paraphrase the runbook into a shorter version; the pacing and the
  on-screen text were tuned to line up with the audio.

## Rules

1. **Never edit `~/.claude/settings.json` without first backing it up.**
   The install and uninstall scripts do this automatically. If you're
   doing surgery by hand, `Copy-Item ... settings.json.bak-<timestamp>`
   before writing.
2. **Never wipe entire hook event keys.** Each of `Notification`,
   `PermissionRequest`, `UserPromptSubmit`, and `Stop` may hold
   multiple hook groups — Claude Code itself adds internal HTTP hooks
   at `http://127.0.0.1:52888/hook` to some of these events. Only
   touch groups whose command references this project's script names.
3. **Never write backslashes in JSON `command` paths.** The hook
   runner passes commands through a bash-like shell that eats `\` as
   escape chars — use forward slashes (`C:/Users/...`). PowerShell
   `-File` accepts both.
4. **Never claim the beep is live after editing settings.json.** The
   config watcher doesn't pick up mid-session edits. Tell the user to
   run `/hooks` (dismiss the menu — that reloads) or restart claude.
5. **Match the Notification hook's `matcher` field to the recommended
   set** unless the user asks otherwise: `agent_needs_input|elicitation_dialog|elicitation_url_dialog|quota_auto_resume_stale|quota_auto_resume_disabled`.
   Firing on every subtype means a ~60s idle-prompt nag after every
   turn and a double-beep on permission events. Details in README's
   "Notification subtype filtering" section.
6. **Bypass-permissions mode kills `PermissionRequest`.** If the user
   uses `--dangerously-skip-permissions` or accepted bypass mode, they
   won't hear the chime on permission prompts — it's not a bug and
   don't try to "fix" it.

## Scripts

| Task | Command |
|---|---|
| Install / reinstall this project's hooks | `powershell -ExecutionPolicy Bypass -File .\windows\install-<PROJECT_ID>.ps1` |
| Preview install without writing | add `-DryRun` |
| Uninstall this project's hooks | `powershell -ExecutionPolicy Bypass -File .\windows\uninstall-<PROJECT_ID>.ps1` |
| Pipe-test the installed notify hook | `'{"session_id":"t","hook_event_name":"Notification","notification_type":"agent_needs_input","notification_text":"test"}' \| powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\notify-<PROJECT_ID>.ps1"` |

Replace `<PROJECT_ID>` with the value in `PROJECT_ID`.

## Files

- `PROJECT_ID` — the identifier. Change here first, then rename the
  five ps1 files and update settings-hooks-fragment.json to match.
- `README.md` — human-facing overview.
- `SETUP.md` — install runbook (this is what you follow in install mode).
- `DEMO.md` — demo runbook (this is what you follow when the user
  asks to hear the sounds).
- `windows/` — hook scripts, install/uninstall scripts, settings fragment.
- `wsl/` — bash equivalents for running Claude Code inside WSL. Not
  auto-installed by the Windows installer; see `wsl/WSL-SETUP.md`.
- `demo/beeps-<PROJECT_ID>.ps1` — standalone dot-source demo of the
  named sounds (Triumphant, BellTower, Arpeggio, CallResp). Never
  invoked by the hooks; purely a listening tool for the user.
