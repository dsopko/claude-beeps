# SETUP — Claude's install runbook for claude-beeps

> **Human, looking to install this?** You're in the wrong file. SETUP.md
> is the runbook **Claude** reads to install claude-beeps on your machine
> — it's written for the assistant, not for you to work through by hand.
> For the human install path, see **[README.md](README.md)** — it's two
> `/plugin` commands.

You are in **install mode** when `claude plugin list` does not show
`claude-beeps` (detection details in CLAUDE.md). Your job: one
detection pass, a short interview, the install, verify, hand off. Keep
it tight — the user is a developer.

## 1. Detect the environment (read-only, no approval friction)

- Platform: Windows native is the supported target
  (`$env:OS -eq 'Windows_NT'`, not inside WSL). WSL shows `microsoft`
  in `uname -r` or `/proc/version`.
- `claude` on PATH and its version (`claude --version`). The `/plugin`
  system needs a current Claude Code; if `/plugin` is unknown, the CLI
  needs an update first.

## 2. Platform support matrix

| Platform | Beeps play | Plugin supported | Status |
|---|---|---|---|
| Windows native (PS 5.1 or 7) | yes | yes | supported |
| WSL2 | no | hooks no-op or error (can't resolve `powershell` with a Linux plugin path) | not supported |
| Linux / macOS | no (Windows-only .NET beep API) | hooks exit 0 via the guard where pwsh exists | not supported |

**If you detect WSL or Linux/macOS:** stop and say the beeps are
Windows-only (`[console]::beep` under .NET). Installing the plugin
there adds noise at best.

## 3. Check for prior state

- `claude plugin list` shows `claude-beeps` → already installed. Switch
  to operating mode (CLAUDE.md) and stop — don't reinstall unasked.
- Legacy pre-plugin install: hook groups in `~/.claude/settings.json`
  whose commands reference `notify-cb-*.ps1` / `start-cb-*.ps1` /
  `stop-cb-*.ps1` (or bare `notify.ps1` etc. under
  `~/.claude/hooks/`). Report it plainly. Offer to remove those
  specific hook groups (CLAUDE.md rule 2: backup first, never wipe
  whole event keys) — otherwise the user will get **double beeps**
  once the plugin is enabled. Do not remove without approval.

## 4. Interview

Keep it short. Ask only what actually branches the install.

1. **Confirm the plan.** "I'll add this repo as a plugin marketplace
   and install the claude-beeps plugin at user scope. OK?" If no, stop.
2. **Only if a legacy install was found in step 3:** get a yes/no on
   removing the old hook groups (with backup) before enabling the
   plugin.

Do **not** ask about sound customization, thresholds, or the
Notification matcher. Ship the defaults; direct customization requests
to CLAUDE.md's operating-mode entry after install.

## 5. Execute

In the session (preferred — the user sees the scope picker and install
summary):

```
/plugin marketplace add dsopko/claude-beeps
/plugin install claude-beeps@claude-beeps
```

Tell the user to pick **user scope**. If the install summary says
`Run /reload-plugins to activate.`, run that. (Shell alternative:
`claude plugin install claude-beeps@claude-beeps` installs to user
scope without the interactive step, then takes effect next session or
after `/reload-plugins`.)

If the user is sitting in a clone of this repo and wants to install
from it rather than from GitHub: `/plugin marketplace add .` then the
same install command.

## 6. Verify the scripts and audio (pipe-test)

```powershell
'{"session_id":"verify","hook_event_name":"Notification","notification_type":"agent_needs_input","notification_text":"install verify"}' | powershell -ExecutionPolicy Bypass -File .\scripts\notify.ps1
'{"session_id":"verify"}' | powershell -ExecutionPolicy Bypass -File .\scripts\start.ps1
'{"session_id":"verify"}' | powershell -ExecutionPolicy Bypass -File .\scripts\stop.ps1
```

Expected: rising chime, then the short 2-beep "done" tone (elapsed
since the fake start is ~0s). If nothing played, check
`~/.claude/hooks/notify.log` (the fallback dir pipe-tests write to) —
a timestamp entry means the script ran but Windows audio didn't play
(muted, wrong output device); no entry means the script itself failed.

**What this does and does not prove.** Pipe-tests bypass the hook
runner entirely. They prove the scripts and the audio device work —
*nothing* about whether the plugin's hooks are registered and live.
Don't tell the user "it's working" on this alone; liveness has its own
evidence in Step 8.

## 7. Offer the demo

Call `AskUserQuestion` with a single question:

- Question: "Install worked. Want a quick demo of what each sound
  means? Takes about 10 seconds — plays the 'needs input' chime, then
  the three finish-sound tiers (short / normal / long) back to back."
- Option 1: "Yes — play the demo" → follow **DEMO.md**.
- Option 2: "Skip — I'll hear them naturally" → Step 8.

Do not paraphrase DEMO.md; that runbook was tuned so the audio and the
on-screen explanation line up.

## 8. Hand off

One thing the user must do: **trigger something.** Submit a prompt;
when Claude finishes responding they'll hear the "done" chime, and
when Claude needs input or permission they'll hear the rising chime.

Then confirm liveness from evidence, not from the Step 6 pipe-tests
(CLAUDE.md rule 3). Either of these proves the plugin's hooks loaded:

- a line in the plugin's `notify.log` (under
  `~/.claude/plugins/data/<id>/`) you did **not** pipe in yourself
- `start-<current session_id>.txt` in that data dir after the user
  submits a prompt

If a full turn passes with neither signal, run `/reload-plugins`, or
restart the `claude` CLI.

Tell them the log path and CLAUDE.md's operating mode for future
customization (edit source → bump version → `/plugin marketplace
update claude-beeps` → `/reload-plugins`).
