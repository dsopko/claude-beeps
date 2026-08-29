# DEMO — Claude's runbook for demoing claude-beeps

> **Human, looking to hear a demo?** Ask Claude in this repo: "demo the
> beeps" / "play the sounds" / "show me what claude-beeps sounds like".
> Claude reads this file and runs the demo below.

This runbook is for **Claude**. Follow it end to end. Do not
paraphrase the on-screen text into a shorter version; the pacing and
the text were tuned to line up with the audio.

All sounds play by piping fake hook JSON into the `.ps1` files under
`scripts/` in this repo. That works whether or not the plugin is
installed — the repo copy and the installed cache copy are the same
scripts. Install state changes only the wrap-up (Step 7): when the
plugin is installed, a real fourth sound fires at end-of-turn.

## Step 0 — Detect install state

```powershell
$installed = [bool](claude plugin list 2>$null | Select-String 'claude-beeps')
```

Announce it in one line of your response ("The plugin is installed —
you'll get a real end-of-turn chime as a bonus fourth sound" or "The
plugin isn't installed — you'll hear the three demo tiers only").

Run every command below from the repo root.

## Step 1 — Play the notify chime

```powershell
'{"session_id":"demo","hook_event_name":"Notification","notification_type":"agent_needs_input","notification_text":"claude-beeps demo starting"}' | powershell -ExecutionPolicy Bypass -File .\scripts\notify.ps1
```

## Step 2 — Explain what they just heard (in your response text)

Emit this text (or a close paraphrase — meaning matters, not exact
words):

> You just heard the **"Claude needs your input"** notification (rising
> 1200 → 1500 Hz two-note chime). It plays whenever Claude needs a
> response from you — a real question like the one coming up, a
> permission prompt for a tool that isn't allowlisted, or an MCP
> server asking for input mid-task. You're hearing it *now* because
> I'm about to ask you a question.

## Step 3 — Show the finish-sound tiers

Print this table in your response text:

> Coming up next: three **"turn done"** sounds. Claude Code fires the
> `Stop` event when it finishes responding, and the hook picks a
> different sound based on how long the turn took:
>
> | How long the task took | Tier | What you'll hear |
> |---|---|---|
> | **Under 15 seconds** | Short | 2-beep C5 → E5 (quick "ping ping") |
> | **15 seconds to 2 minutes** | Normal | 4-beep pattern (C5 E5 C5 E5) |
> | **Over 2 minutes** | Long | 13-beep cascade ending on a long C6 ring |

## Step 4 — AskUserQuestion (continue / quit)

Call `AskUserQuestion` with a single question and two options:

- Question: "Continue the demo? Answering 'continue' will play the
  three finish sounds back-to-back so you can hear the difference."
- Option 1 label: "Continue the demo" — plays all three finish sounds.
- Option 2 label: "Quit the demo" — ends the demo here.

If the user quits, acknowledge briefly and stop. Do not play the finish
sounds.

## Step 5 — Continuation intent

Print exactly this if the user chose "Continue" **and the plugin is
installed**:

> Continuing. Playing all three finish sounds through `scripts/stop.ps1`
> — plus the final "done" sound for this turn itself, which will fire
> naturally at end-of-turn based on how long the whole conversation
> has been running.

They'll hear four sounds total: the three demo tiers plus the real
`Stop` event when your response ends.

If the plugin is **not** installed, print this instead:

> Continuing. Playing all three finish sounds through `scripts/stop.ps1`.
> Because the plugin isn't installed on this machine, no real `Stop`
> event will fire when this turn ends — you'll hear three sounds, not
> four. If you want the fourth (the real end-of-turn chime), install
> with `/plugin marketplace add dsopko/claude-beeps` then
> `/plugin install claude-beeps@claude-beeps`.

## Step 6 — Play the three tiers

The scripts run outside the hook runner here, so they use the fallback
state dir `~\.claude\hooks\` (created on demand). The fake session ids
never collide with a real session, and `stop.ps1` deletes each
timestamp file it consumes.

```powershell
$stateDir = "$env:USERPROFILE\.claude\hooks"
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

Write-Host ""
Write-Host ">>> [1/3] SHORT - under 15 seconds - 2 beeps"
"$((Get-Date).Ticks)" | Set-Content -Encoding ascii -NoNewline "$stateDir\start-demo-short.txt"
'{"session_id":"demo-short"}' | powershell -ExecutionPolicy Bypass -File .\scripts\stop.ps1
Start-Sleep -Milliseconds 900

Write-Host ""
Write-Host ">>> [2/3] NORMAL - 15 seconds to 2 minutes - 4 beeps"
"$(((Get-Date).AddSeconds(-30)).Ticks)" | Set-Content -Encoding ascii -NoNewline "$stateDir\start-demo-normal.txt"
'{"session_id":"demo-normal"}' | powershell -ExecutionPolicy Bypass -File .\scripts\stop.ps1
Start-Sleep -Milliseconds 900

Write-Host ""
Write-Host ">>> [3/3] LONG - over 2 minutes - 13-beep cascade"
"$(((Get-Date).AddSeconds(-180)).Ticks)" | Set-Content -Encoding ascii -NoNewline "$stateDir\start-demo-long.txt"
'{"session_id":"demo-long"}' | powershell -ExecutionPolicy Bypass -File .\scripts\stop.ps1
```

If the user has customized the sounds in `scripts/stop.ps1`, this
plays their customizations — the demo always runs whatever is in the
repo's source files.

## Step 7 — Wrap up

Say the demo is done in one sentence.

**Installed:** note that the fourth sound the user is about to hear
(the real end-of-turn `Stop` chime) will play based on the actual
duration of this whole conversation turn — so if you've been running
long, they'll hear the Long tier for real.

**Not installed:** offer to install now (SETUP.md) so the user can
hear the sounds fire naturally during real work, not just in the demo.

Optionally offer either way:
- Replay any single sound (they name it, you play it).
- Explain the source files that produced the sounds.

## Notes

- **AskUserQuestion does fire the Notification hook.** Verified on
  Claude Code v2.1.250: an `AskUserQuestion` call raises a
  `Notification` event with `notification_type: agent_needs_input`,
  and the plugin's `notify.log` records it. Earlier drafts of this
  file claimed the opposite — that was wrong. When the plugin is
  installed, the natural firing at Step 4 (when the AskUserQuestion
  appears) plays the chime *again* on top of the Step 1 manual play,
  so the user hears it twice — separated by however long the Step 2/3
  explanation and table take to read. Not a bug: the second firing
  proves the whole hook chain works during real interactive use, not
  just via pipe-tests. If it feels noisy, drop the Step 1 manual play
  and rewrite Step 2's explanation in future tense ("You'll hear the
  chime when I ask you the next question") instead of past tense.
- Real `PermissionRequest` events (Claude asking to run a
  non-allowlisted tool) also fire the hook reliably. If the user wants
  to hear a permission-triggered chime, run any tool that isn't in
  their `permissions.allow` list.
- The demo leaves no lingering state: `stop.ps1` deletes its own
  timestamp files, and the fake `session_id`s never collide with the
  current session's id. Pipe-runs do append to the *fallback* log
  (`~/.claude/hooks/notify.log`), not the plugin data dir's log —
  which is exactly why demo entries can never be mistaken for the
  liveness evidence CLAUDE.md rule 3 asks for.
