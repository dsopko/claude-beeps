# DEMO — Claude's runbook for demoing claude-beeps

> **Human, looking to hear a demo?** Ask Claude in this repo: "demo the
> beeps" / "play the sounds" / "show me what claude-beeps sounds like".
> Claude reads this file and runs the demo below.

This runbook is for **Claude**. When the user asks for a demo, follow
these steps. Do not paraphrase them into a shorter version — the flow
was tuned so the audio and the on-screen text line up.

## Precondition

Read `PROJECT_ID` at the repo root. Confirm the installed notify hook
exists at `~/.claude/hooks/notify-<PROJECT_ID>.ps1`. If it doesn't,
tell the user "claude-beeps isn't installed here yet — run the setup
first" and route them to SETUP.md. Do not fake the demo with inline
`[console]::beep` calls; the whole point is to prove the installed
chain works.

## Step 1 — Play the notification chime through the installed hook

Run this exact command via the PowerShell tool (substitute the actual
PROJECT_ID value):

```powershell
$pid_ = 'cb-<PROJECT_ID_WITHOUT_CB_PREFIX>'
$hooksDir = "$env:USERPROFILE\.claude\hooks"
'{"session_id":"demo","hook_event_name":"Notification","notification_type":"agent_needs_input","notification_text":"claude-beeps demo starting"}' | powershell -ExecutionPolicy Bypass -File "$hooksDir\notify-$pid_.ps1"
```

The user hears the rising 1200→1500 Hz two-note chime through their
speakers. The tool call itself produces no console output — that's
expected; the sound is the point.

## Step 2 — Explain what they just heard, in your response text

Emit this text (or a close paraphrase — the meaning matters, not the
exact words):

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

## Step 4 — Ask permission to continue

Call `AskUserQuestion` with a single question and two options:

- Question: "Continue the demo? Answering 'continue' will play the
  three finish sounds back-to-back so you can hear the difference."
- Option 1 label: "Continue the demo" — plays all three finish sounds.
- Option 2 label: "Quit the demo" — ends the demo here.

If the user quits, acknowledge briefly and stop. Do not play the finish
sounds.

## Step 5 — Set expectations for what they'll hear next

If the user chose "Continue the demo", open your next response text
with **this exact intent**:

> Continuing. Playing all three finish sounds through the installed
> `stop-cb-<PID>.ps1` hook — plus the final "done" sound for this turn
> itself, which will fire naturally at end-of-turn based on how long
> the whole conversation has been running.

They'll hear four sounds total: the three demo tiers you're about to
play, and then the real `Stop` hook when your response ends.

## Step 6 — Play the three tiers through the installed hook

One PowerShell tool call, three fake elapsed times, all routed through
the installed `stop-<PROJECT_ID>.ps1`:

```powershell
$pid_ = 'cb-<PROJECT_ID_WITHOUT_CB_PREFIX>'
$hooksDir = "$env:USERPROFILE\.claude\hooks"

Write-Host ""
Write-Host ">>> [1/3] SHORT - under 15 seconds - 2 beeps"
"$((Get-Date).Ticks)" | Set-Content -Encoding ascii -NoNewline "$hooksDir\start-demo-short.txt"
'{"session_id":"demo-short"}' | powershell -ExecutionPolicy Bypass -File "$hooksDir\stop-$pid_.ps1"
Start-Sleep -Milliseconds 900

Write-Host ""
Write-Host ">>> [2/3] NORMAL - 15 seconds to 2 minutes - 4 beeps"
"$(((Get-Date).AddSeconds(-30)).Ticks)" | Set-Content -Encoding ascii -NoNewline "$hooksDir\start-demo-normal.txt"
'{"session_id":"demo-normal"}' | powershell -ExecutionPolicy Bypass -File "$hooksDir\stop-$pid_.ps1"
Start-Sleep -Milliseconds 900

Write-Host ""
Write-Host ">>> [3/3] LONG - over 2 minutes - 13-beep cascade"
"$(((Get-Date).AddSeconds(-180)).Ticks)" | Set-Content -Encoding ascii -NoNewline "$hooksDir\start-demo-long.txt"
'{"session_id":"demo-long"}' | powershell -ExecutionPolicy Bypass -File "$hooksDir\stop-$pid_.ps1"
```

The Short tier fires with elapsed ≈ 0s. Normal uses a timestamp 30
seconds in the past. Long uses 180 seconds. The stop hook consumes and
deletes each fake timestamp file — safe to re-run.

## Step 7 — Wrap up briefly

Say the demo is done. Note that the fourth sound the user is about to
hear (the real end-of-turn `Stop` chime) will play based on the actual
duration of this whole conversation turn — so if you've been running
long, they'll hear the Long tier for real.

Optionally offer follow-ups:
- Replay any single sound
- Show the `notify.log` entries the demo just wrote
- Explain the source files that produced the sounds

## Notes

- `Notification` events for AskUserQuestion don't reliably fire the
  installed hook (the hook system doesn't route the internal
  "agent_needs_input" from AskUserQuestion the same way it does other
  in-app notifications). That's why Step 1 plays the chime manually
  through the installed hook — it's the closest honest simulation of
  the real experience.
- Real `PermissionRequest` events (Claude asking to run a
  non-allowlisted tool) do fire the hook reliably. If the user wants
  to see a real permission-triggered chime, run any tool that isn't in
  their `permissions.allow` list.
- The demo leaves no lingering state: `stop-<PID>.ps1` deletes its own
  timestamp file, and the fake `session_id`s used here never collide
  with the current Claude Code session's id.
