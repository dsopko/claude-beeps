# DEMO — Claude's runbook for demoing claude-beeps

> **Human, looking to hear a demo?** Ask Claude in this repo: "demo the
> beeps" / "play the sounds" / "show me what claude-beeps sounds like".
> Claude reads this file and runs the demo below.

This runbook is for **Claude**. It has two paths — pick one based on
whether the hooks are installed on this machine, then follow it end to
end. Do not paraphrase the on-screen text into a shorter version; the
pacing and the text were tuned to line up with the audio.

## Step 0 — Detect install state

```powershell
$pid_ = (Get-Content .\PROJECT_ID -Raw).Trim()
$installed = Test-Path "$env:USERPROFILE\.claude\hooks\notify-$pid_.ps1"
```

Then branch:

- **`$installed` is true → Path A (installed).** Play via the actual
  installed hooks. Proves the whole chain works and leaves entries in
  `notify.log` you can look at afterwards.
- **`$installed` is false → Path B (not installed).** Play the beep
  sequences directly, sourced from the `.ps1` files in `windows/`.
  No hook-directory writes, no log entries, no side effects. Same
  audio as Path A because the sequences come from the same source.

Announce which path you're taking in one line of your response
("Hooks are installed — playing through them" or "Hooks aren't
installed here — playing the sounds directly from the source files").

The Step 2–5 on-screen text is **identical** for both paths — same
explanation, same table, same continue/quit question. Only Step 1
(how you play notify) and Steps 5/6 (how you play the tiers) differ.

---

## Path A — Installed

### Step 1 (A) — Play notify through the installed hook

```powershell
$pid_ = (Get-Content .\PROJECT_ID -Raw).Trim()
$hooksDir = "$env:USERPROFILE\.claude\hooks"
'{"session_id":"demo","hook_event_name":"Notification","notification_type":"agent_needs_input","notification_text":"claude-beeps demo starting"}' | powershell -ExecutionPolicy Bypass -File "$hooksDir\notify-$pid_.ps1"
```

### Step 5 (A) — Continuation intent

Print exactly this if the user chose "Continue":

> Continuing. Playing all three finish sounds through the installed
> `stop-cb-<PID>.ps1` hook — plus the final "done" sound for this turn
> itself, which will fire naturally at end-of-turn based on how long
> the whole conversation has been running.

They'll hear four sounds total: the three demo tiers plus the real
`Stop` event when your response ends.

### Step 6 (A) — Play the three tiers through the installed hook

```powershell
$pid_ = (Get-Content .\PROJECT_ID -Raw).Trim()
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

---

## Path B — Not installed

Source-of-truth for the beep patterns is the `.ps1` files under
`windows/`. Read them and extract the `[console]::beep(...)` calls
at demo time, so the demo tracks any local edits to the sounds
without needing DEMO.md to be updated in lockstep.

### Step 1 (B) — Read notify's beep calls from the source and play them

Read `windows/notify-<PROJECT_ID>.ps1`. Grab every line matching
`[console]::beep(...)` (there should be two). Chain them with `;` and
execute in one PowerShell tool call.

Effective command shape (build it from what's in the file):

```powershell
[console]::beep(1200,150); [console]::beep(1500,200)
```

Do not hard-code that command from this runbook — read the file, extract
the actual lines, and run whatever's there. If the user has customized
notify's sounds, this reflects that.

### Step 5 (B) — Continuation intent (no fourth sound)

Print exactly this if the user chose "Continue":

> Continuing. Playing all three finish sounds by pulling the beep
> sequences straight out of `windows/stop-cb-<PID>.ps1`. Because the
> hooks aren't installed on this machine, no real `Stop` event will
> fire when this turn ends — you'll hear three sounds, not four.
> If you want the fourth (the real end-of-turn chime), install with
> `windows/install-cb-<PID>.ps1` first.

### Step 6 (B) — Read stop's three tiers from the source and play them

Read `windows/stop-<PROJECT_ID>.ps1`. It has three tier branches:

- **Long** — the body of `if ($elapsed -gt 120) { ... }` (13 beeps)
- **Normal** — the body of `elseif ($elapsed -ge 15) { ... }` (4 beeps)
- **Short** — the body of the terminal `else { ... }` (2 beeps)

Extract the `[console]::beep(...)` calls from each branch. Play them
in **Short → Normal → Long** order (from lightest to heaviest), same
labels and 900ms Start-Sleep between tiers as Path A:

```powershell
Write-Host ""
Write-Host ">>> [1/3] SHORT - under 15 seconds - 2 beeps"
# insert the Short branch's beep calls, joined with ;
Start-Sleep -Milliseconds 900

Write-Host ""
Write-Host ">>> [2/3] NORMAL - 15 seconds to 2 minutes - 4 beeps"
# insert the Normal branch's beep calls
Start-Sleep -Milliseconds 900

Write-Host ""
Write-Host ">>> [3/3] LONG - over 2 minutes - 13-beep cascade"
# insert the Long branch's beep calls
```

Do not invoke `stop-<PID>.ps1` from the repo — it hardcodes
`$env:USERPROFILE\.claude\hooks\start-<session_id>.txt` as its
timestamp path, which would require creating the hooks directory
just to satisfy it. Extracting the beep calls is cleaner.

---

## Common — Steps 2, 3, 4 (both paths)

### Step 2 — Explain what they just heard (in your response text)

Emit this text (or a close paraphrase — meaning matters, not exact
words):

> You just heard the **"Claude needs your input"** notification (rising
> 1200 → 1500 Hz two-note chime). It plays whenever Claude needs a
> response from you — a real question like the one coming up, a
> permission prompt for a tool that isn't allowlisted, or an MCP
> server asking for input mid-task. You're hearing it *now* because
> I'm about to ask you a question.

### Step 3 — Show the finish-sound tiers

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

### Step 4 — AskUserQuestion (continue / quit)

Call `AskUserQuestion` with a single question and two options:

- Question: "Continue the demo? Answering 'continue' will play the
  three finish sounds back-to-back so you can hear the difference."
- Option 1 label: "Continue the demo" — plays all three finish sounds.
- Option 2 label: "Quit the demo" — ends the demo here.

If the user quits, acknowledge briefly and stop. Do not play the finish
sounds.

---

## Step 7 — Wrap up (both paths)

Say the demo is done in one sentence.

**Path A:** note that the fourth sound the user is about to hear (the
real end-of-turn `Stop` chime) will play based on the actual duration
of this whole conversation turn — so if you've been running long,
they'll hear the Long tier for real.

**Path B:** offer to run the installer now (`windows/install-cb-<PID>.ps1`)
so the user can hear the sounds fire naturally during real work, not
just in the demo.

Optionally offer either path:
- Replay any single sound (they name it, you play it — installed hook
  or source-extraction depending on which path you're on)
- Show `notify.log` entries the demo wrote (Path A only; Path B doesn't
  write to the log)
- Explain the source files that produced the sounds

## Notes

- `Notification` events for `AskUserQuestion` don't reliably fire the
  installed hook (Claude Code doesn't route the internal
  `agent_needs_input` from AskUserQuestion the same way it does other
  in-app notifications). That's why Step 1 in Path A plays the chime
  manually through the installed hook — it's the closest honest
  simulation of the real experience.
- Real `PermissionRequest` events (Claude asking to run a
  non-allowlisted tool) do fire the hook reliably. If the user wants
  to see a real permission-triggered chime, run any tool that isn't in
  their `permissions.allow` list.
- Path A leaves no lingering state: `stop-<PID>.ps1` deletes its own
  timestamp file, and the fake `session_id`s used here never collide
  with the current Claude Code session's id.
- Path B leaves no lingering state at all — nothing is written to disk.
