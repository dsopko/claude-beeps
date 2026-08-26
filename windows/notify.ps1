# Notification + PermissionRequest hook - plays the "needs input" rising chime.
# Logs which event fired it so wiring can be verified via notify.log.
$evt = "unknown"
try {
    $j = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if ($j.hook_event_name) { $evt = $j.hook_event_name }
} catch {}

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $evt fired" |
    Out-File -Append -Encoding ascii "$env:USERPROFILE\.claude\hooks\notify.log"

[console]::beep(1200,150)
[console]::beep(1500,200)
