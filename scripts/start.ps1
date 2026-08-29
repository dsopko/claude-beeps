# UserPromptSubmit hook - records turn start time, keyed by session_id
# so concurrent Claude Code sessions don't collide.
#
# Non-Windows guard: plugin hooks fire on every OS (there is no platform
# gating in the plugin system), so exit quietly where there is no beep API.
if ($env:OS -ne 'Windows_NT') { exit 0 }

$dataDir = if ($env:CLAUDE_PLUGIN_DATA) { $env:CLAUDE_PLUGIN_DATA } else { "$env:USERPROFILE\.claude\hooks" }
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$j = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = "$dataDir\start-$($j.session_id).txt"
(Get-Date).Ticks | Out-File -Encoding ascii -NoNewline $file
