# SETUP — Claude's install runbook for claude-beeps

> **Human, looking to install this?** You're in the wrong file. SETUP.md is
> the runbook **Claude** reads to install claude-beeps on your machine — it's
> written for the assistant, not for you to work through by hand. For the
> human install path (clone the repo, then `claude "set up claude-beeps"`),
> see **[README.md](README.md)**.

You are in **install mode** when `~/.claude/hooks/notify-<PROJECT_ID>.ps1`
does not exist (where `<PROJECT_ID>` is the value in this repo's
`PROJECT_ID` file). Your job: one detection pass, a short interview,
one install command, verify, hand off. Keep it tight — the user is a
developer.

## 1. Detect the environment (read-only, no approval friction)

Read PROJECT_ID:
```powershell
$pid_ = (Get-Content .\PROJECT_ID -Raw).Trim()
```

Sanity-check the platform and PowerShell:
- Windows native: `$env:OS -eq 'Windows_NT'` and not inside WSL.
- Inside WSL: `uname -r` mentions `microsoft`, or `/proc/version` mentions WSL.
- PowerShell 5.1+ or 7: `$PSVersionTable.PSVersion` (both fine for the
  installer — it's written to work on 5.1 and above).

Check for `claude` on PATH: `Get-Command claude -ErrorAction SilentlyContinue`.
If missing, note it in the hand-off — hooks still install; user just
won't hear anything until they run Claude Code somewhere.

Confirm the install target dir exists or can be created:
`$env:USERPROFILE\.claude` — this is where the hooks and settings.json live.

## 2. Platform support matrix

| Platform | Beeps play | Auto-install | Status |
|---|---|---|---|
| Windows native (PS 5.1+) | yes | yes (this runbook) | supported |
| Windows native (PS 7) | yes | yes (same script) | supported |
| WSL2 | yes (via `powershell.exe` interop) | **no** — install by hand from `wsl/WSL-SETUP.md` | partial |
| Linux / macOS bare metal | no (Windows-only .NET beep API) | no | not supported |

**If you detect WSL:** stop and tell the user "the Windows installer
here doesn't run against WSL — check `wsl/WSL-SETUP.md`, which walks
through the equivalent bash setup." Do not attempt the WSL install
from this runbook.

**If you detect Linux/macOS bare metal:** stop and say the beeps
themselves are Windows-only (they use `[console]::beep` under .NET).
Point at `wsl/WSL-SETUP.md` if they might be able to run under WSL.

## 3. Check for prior state

Look for signals that something is already installed here:
- `~/.claude/hooks/notify-<PID>.ps1` exists → this project already installed
- `~/.claude/hooks/notify.ps1` exists → an older (pre-GUID) claude-beeps
  install may be present
- `~/.claude/settings.json` has hook entries whose commands reference
  `notify-<something>.ps1`, `start-*.ps1`, or `stop-*.ps1` → some install
  of claude-beeps (this one, another fork, or legacy) is registered

Report what you found. If this project is already installed, switch
to operating mode (see CLAUDE.md) and stop — don't reinstall without
being asked.

If a legacy or foreign install is present, mention it plainly. Do
not force-uninstall it without user permission. The installer will
preserve unrelated hook groups automatically; it will not touch a
foreign install's own scripts on disk.

## 4. Interview

Keep it short. Ask only what actually branches the install.

1. **Confirm the install target.** "I'm going to install the hooks
   into `%USERPROFILE%\.claude\hooks\` and merge into
   `%USERPROFILE%\.claude\settings.json`. OK?" If they say no, stop —
   don't improvise a different location.

2. **Only if a settings.json already exists:** "I'll back it up to
   `settings.json.bak-install-<timestamp>` before merging. Existing
   permissions, model, other hooks, everything else stays. Sound
   good?" (Yes/no.)

3. **Only if WSL is also on the machine** (probe with `wsl -l -v` at
   a distance — silent errors are fine): "You have WSL too. This
   installer only does the Windows side. If you want beeps from
   Claude Code running inside WSL, do that separately with
   `wsl/WSL-SETUP.md`. Skip WSL for now?" (Default yes — skip.)

Do **not** ask about sound customization, threshold values, or the
Notification matcher during the interview. Ship the defaults from the
source files as-is; direct customization requests to CLAUDE.md's
"Change the sounds / thresholds / matcher" entry after install.

## 5. Execute (single approval)

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\install-<PROJECT_ID>.ps1
```

Where `<PROJECT_ID>` is the value read from `PROJECT_ID` above.

Preview first if the user seems unsure — same command with `-DryRun`
appended prints what would change and writes nothing.

The installer:
- Copies the three hook scripts to `~/.claude/hooks/`.
- Backs up `settings.json` (if any) and merges the hooks block, preserving
  everything else and dropping any pre-existing claude-beeps groups for
  this same PROJECT_ID so re-runs don't stack duplicates.
- Validates the resulting JSON and restores the backup if it doesn't parse.
- Prints the backup path.

## 6. Verify

Pipe-test each installed hook. Beeps play; each should be audible:

```powershell
$pid_ = (Get-Content .\PROJECT_ID -Raw).Trim()
'{"session_id":"verify","hook_event_name":"Notification","notification_type":"agent_needs_input","notification_text":"install verify"}' | powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\notify-$pid_.ps1"
'{"session_id":"verify"}' | powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\start-$pid_.ps1"
'{"session_id":"verify"}' | powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\stop-$pid_.ps1"
```

Expected: rising chime (from notify), then the short 2-beep "done"
tone (from stop; elapsed since the fake start file is ~0s). Confirm
with the user that both played. If nothing played, check
`~/.claude/hooks/notify.log` — a timestamp entry means the hook ran
but Windows audio didn't play (muted, wrong output device, headphones
elsewhere). No timestamp means the hook itself didn't fire.

**What this does and does not prove.** These pipe-tests run the `.ps1`
files directly, bypassing Claude Code's hook runner entirely. They
prove the scripts work and the audio device works. They prove *nothing*
about whether the hooks are registered and live. Don't tell the user
"it's working" on the strength of the pipe-tests alone — liveness has
its own evidence, covered in Step 8.

Clean up the leftover start-verify.txt timestamp file if it wasn't
consumed — the second pipe-test above should have removed it, but a
lingering file is harmless.

## 7. Offer the demo

The pipe-tests in Step 6 already confirmed audio works, but they were
minimal. Now offer the full guided demo — it takes ~10 seconds and
teaches the user what each sound means so they recognize them during
real work.

Call `AskUserQuestion` with a single question:

- Question: "Install worked. Want a quick demo of what each sound
  means? Takes about 10 seconds — plays the 'needs input' chime, then
  the three finish-sound tiers (short / normal / long) back to back."
- Option 1 label: "Yes — play the demo" — you'll follow DEMO.md Path A.
- Option 2 label: "Skip — I'll hear them naturally" — skip to Step 8.

If the user picks yes: **follow DEMO.md, Path A.** The install just
finished so the detection in DEMO.md Step 0 will pick Path A
automatically. Do not paraphrase the DEMO.md text; that runbook was
tuned so the audio and the on-screen explanation line up.

If the user picks skip: go straight to Step 8.

## 8. Hand off

**Reloading is usually not required.** On Claude Code v2.1.250 the
settings.json hook groups are picked up mid-session within seconds of
the install writing them — no `/hooks`, no restart (verified
2026-08-28). Older versions may behave differently, so confirm rather
than assert. Do not tell the user to restart as a blanket instruction.

One thing the user must do:

- **Trigger something.** Ask Claude a question in a new prompt. When
  Claude finishes responding, they'll hear the "done" chime. When
  Claude actually needs input (or when a non-allowlisted tool is used
  and permission fires), they'll hear the rising chime.

Then confirm liveness from evidence, not from the pipe-tests in Step 6
(which bypass the hook runner — see the note there). Either of these
proves the config loaded:

- a line in `~/.claude/hooks/notify.log` that you did **not** pipe in
  yourself — a real `PermissionRequest` or `Notification` entry
- `~/.claude/hooks/start-<session_id>.txt` for the *current* session,
  written by the `UserPromptSubmit` hook when the user submits a prompt

If a full turn passes with neither signal, *then* have them run
`/hooks` (dismiss the menu — that reloads the config) or restart the
`claude` CLI.

Tell them where the backup is, the log path
(`~/.claude/hooks/notify.log`), and CLAUDE.md's operating mode entry
for future customization.

## 9. After install

You are now in operating mode — follow CLAUDE.md's operating-mode
section. If the user asks to uninstall, run
`windows/uninstall-<PROJECT_ID>.ps1` — the removal is picked up the
same way, so `/hooks` is only needed if the beeps outlive it.
