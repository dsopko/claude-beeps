# UserPromptSubmit hook - records turn start time, keyed by session_id
# so concurrent Claude Code sessions don't collide.
$j = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = "$env:USERPROFILE\.claude\hooks\start-$($j.session_id).txt"
(Get-Date).Ticks | Out-File -Encoding ascii -NoNewline $file
