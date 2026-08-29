# Stop hook - reads the timestamp written by the paired start.ps1 hook and
# picks a beep tier by elapsed seconds:
#   < 15s     -> Short  (2 beeps)
#   15s..120s -> Normal (4 beeps)
#   > 120s    -> Long   (13 beeps)
#
# Non-Windows guard: plugin hooks fire on every OS (there is no platform
# gating in the plugin system), so exit quietly where there is no beep API.
if ($env:OS -ne 'Windows_NT') { exit 0 }

$dataDir = if ($env:CLAUDE_PLUGIN_DATA) { $env:CLAUDE_PLUGIN_DATA } else { "$env:USERPROFILE\.claude\hooks" }
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$j = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = "$dataDir\start-$($j.session_id).txt"

$elapsed = 0
if (Test-Path $file) {
    try {
        $start = [long](Get-Content $file -Raw).Trim()
        $elapsed = [int](((Get-Date).Ticks - $start) / 10000000)
    } catch { $elapsed = 0 }
    Remove-Item $file -Force -ErrorAction SilentlyContinue
}

if ($elapsed -gt 120) {
    # Long (>2min)
    [console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,180)
    [console]::beep(523,180); [console]::beep(659,180); [console]::beep(784,180); [console]::beep(880,180)
    [console]::beep(1047,180); [console]::beep(880,180); [console]::beep(784,180); [console]::beep(659,180)
    [console]::beep(1047,1300)
} elseif ($elapsed -ge 15) {
    # Normal (15s-2min)
    [console]::beep(523,180); [console]::beep(659,180); [console]::beep(523,180); [console]::beep(659,360)
} else {
    # Short (<15s)
    [console]::beep(523,180); [console]::beep(659,360)
}
