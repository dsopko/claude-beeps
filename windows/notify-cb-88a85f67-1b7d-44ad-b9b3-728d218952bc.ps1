# Notification + PermissionRequest hook - plays the "needs input" rising chime.
# Also logs the event name, notification_type (only present on Notification), and
# notification_text (Claude's human-readable message) for future diagnosis.
# Non-Windows guard: when installed as a plugin this fires on every OS,
# so exit quietly (0 = no hook-error notice) where there is no beep API.
if ($env:OS -ne 'Windows_NT') { exit 0 }

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
    Out-File -Append -Encoding ascii "$env:USERPROFILE\.claude\hooks\notify.log"

[console]::beep(1200,150)
[console]::beep(1500,200)
