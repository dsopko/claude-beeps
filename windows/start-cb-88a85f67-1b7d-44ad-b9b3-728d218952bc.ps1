# UserPromptSubmit hook - records turn start time, keyed by session_id
# so concurrent Claude Code sessions don't collide.
# Non-Windows guard: when installed as a plugin this fires on every OS,
# so exit quietly (0 = no hook-error notice) where there is no beep API.
if ($env:OS -ne 'Windows_NT') { exit 0 }

$j = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = "$env:USERPROFILE\.claude\hooks\start-$($j.session_id).txt"
(Get-Date).Ticks | Out-File -Encoding ascii -NoNewline $file
