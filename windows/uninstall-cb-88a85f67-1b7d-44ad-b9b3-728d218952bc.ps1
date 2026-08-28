# claude-beeps uninstaller (Windows / PowerShell 5.1+)
#
# Removes ONLY the hook groups whose command references THIS project's
# scripts. The project id lives in ..\PROJECT_ID at the repo root, and
# this script looks for files matching:
#   notify-<PROJECT_ID>.ps1
#   start-<PROJECT_ID>.ps1
#   stop-<PROJECT_ID>.ps1
# Two other claude-beeps installs with different GUIDs stay untouched.
#
# Also matches the legacy pre-GUID names (notify.ps1, start.ps1,
# stop.ps1) so a stale install from an earlier commit still cleans up.
#
# What it does:
#   1. Backs up ~/.claude/settings.json to settings.json.bak-uninstall-<timestamp>
#   2. Filters out our hook groups from each event; removes now-empty event keys
#   3. Validates the resulting JSON (restores backup if it fails)
#   4. Deletes our .ps1 files, notify.log, and stale start-<session>.txt files
#      from ~/.claude/hooks/ (leaves the directory in case other tools use it)
#
# Run:
#   powershell -ExecutionPolicy Bypass -File .\uninstall-cb-<PROJECT_ID>.ps1

$ErrorActionPreference = 'Stop'

# Read this project's identifier from PROJECT_ID at the repo root
$projectIdPath = Join-Path $PSScriptRoot '..\PROJECT_ID'
if (-not (Test-Path $projectIdPath)) {
    throw "PROJECT_ID not found at $projectIdPath. Cannot determine which scripts belong to this project."
}
$projectId = (Get-Content $projectIdPath -Raw).Trim()
if (-not $projectId) { throw "PROJECT_ID at $projectIdPath is empty." }
Write-Host "Uninstalling project: $projectId"

$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$hooksDir     = "$env:USERPROFILE\.claude\hooks"

# Filenames belonging to THIS project (plus the legacy pre-GUID names)
$ourScripts = @(
    "notify-$projectId.ps1", "start-$projectId.ps1", "stop-$projectId.ps1",
    'notify.ps1',            'start.ps1',            'stop.ps1'
)
$ourEvents  = @('Notification', 'PermissionRequest', 'UserPromptSubmit', 'Stop')

if (-not (Test-Path $settingsPath)) {
    Write-Host "No settings.json at $settingsPath - nothing to uninstall."
    exit 0
}

# Back up first
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = "$settingsPath.bak-uninstall-$stamp"
Copy-Item $settingsPath $backup -Force
Write-Host "Backed up settings.json -> $backup"

$data = Get-Content $settingsPath -Raw | ConvertFrom-Json

function Test-IsOurGroup {
    param($group)
    if (-not $group.hooks) { return $false }
    foreach ($h in $group.hooks) {
        if ($h.type -eq 'command' -and $h.command) {
            foreach ($script in $ourScripts) {
                if ($h.command -match [regex]::Escape($script)) { return $true }
            }
        }
    }
    return $false
}

function HasProperty {
    param($obj, [string]$name)
    if ($null -eq $obj) { return $false }
    return $null -ne $obj.PSObject.Properties[$name]
}

$removedGroups = 0
$removedEvents = @()

if (HasProperty $data 'hooks') {
    foreach ($evt in $ourEvents) {
        if (-not (HasProperty $data.hooks $evt)) { continue }
        $before = @($data.hooks.$evt)
        $after  = @($before | Where-Object { -not (Test-IsOurGroup $_) })
        $removedGroups += ($before.Count - $after.Count)
        if ($after.Count -eq 0) {
            $data.hooks.PSObject.Properties.Remove($evt)
            $removedEvents += $evt
        } else {
            $data.hooks.$evt = $after
        }
    }
    if (@($data.hooks.PSObject.Properties).Count -eq 0) {
        $data.PSObject.Properties.Remove('hooks')
    }
}

$data | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8

try {
    Get-Content $settingsPath -Raw | ConvertFrom-Json | Out-Null
    Write-Host "settings.json parses OK after uninstall."
} catch {
    Write-Host "ERROR: settings.json failed to parse after edit. Restoring from $backup"
    Copy-Item $backup $settingsPath -Force
    throw
}

Write-Host "Removed $removedGroups hook group(s)."
if ($removedEvents.Count -gt 0) {
    Write-Host "Removed now-empty event keys: $($removedEvents -join ', ')"
}

foreach ($f in ($ourScripts + @('notify.log'))) {
    $p = Join-Path $hooksDir $f
    if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "Deleted $p"
    }
}
Get-ChildItem $hooksDir -Filter 'start-*.txt' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force
    Write-Host "Deleted $($_.FullName)"
}

Write-Host ""
Write-Host "Done. Restart Claude Code (or run /hooks once) so the change takes effect."
Write-Host "Backup preserved at: $backup"
