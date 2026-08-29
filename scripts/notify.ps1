# Notification + PermissionRequest hook - plays the "needs input" rising chime.
# Also logs the event name, notification_type (only present on Notification), and
# notification_text (Claude's human-readable message) for future diagnosis.
#
# Non-Windows guard: plugin hooks fire on every OS (there is no platform
# gating in the plugin system), so exit quietly where there is no beep API.
if ($env:OS -ne 'Windows_NT') { exit 0 }

# State/log dir: the hook runner exports CLAUDE_PLUGIN_DATA (survives plugin
# updates). Direct pipe-tests don't have it - fall back to the legacy dir.
$dataDir = if ($env:CLAUDE_PLUGIN_DATA) { $env:CLAUDE_PLUGIN_DATA } else { "$env:USERPROFILE\.claude\hooks" }
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$evt = "unknown"
$type = ""
$text = ""
try {
    $j = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if ($j.hook_event_name)   { $evt  = $j.hook_event_name }
    if ($j.notification_type) { $type = $j.notification_type }
    if ($j.notification_text) { $text = $j.notification_text }
} catch {}

$typePart = if ($type) { "[$type] " } else { "" }
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $evt $typePart$text" |
    Out-File -Append -Encoding ascii "$dataDir\notify.log"

[console]::beep(1200,150)
[console]::beep(1500,200)
