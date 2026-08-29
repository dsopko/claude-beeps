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
# Also matches the anchored legacy pattern
#   \.claude[/\\]hooks[/\\](notify|start|stop)\.ps1
# so a stale pre-GUID install still cleans up. Anchoring to
# .claude/hooks/ prevents false positives on third-party hooks whose
# command merely ends with notify.ps1, start.ps1, or stop.ps1
# (e.g. restart.ps1, slack-notify.ps1) - such hooks are never touched.
#
# What it does:
#   1. Backs up ~/.claude/settings.json to settings.json.bak-uninstall-<timestamp>
#   2. Prints and removes each matching hook group; drops now-empty event keys
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

# Match patterns: exact GUID names (escaped) plus one anchored legacy regex.
# Substring semantics on the GUID names are safe because the hyphen and full
# UUID keep them from matching anything else. The legacy entry is anchored
# to the Claude hooks directory to prevent third-party false positives.
$ourPatterns = @(
    [regex]::Escape("notify-$projectId.ps1"),
    [regex]::Escape("start-$projectId.ps1"),
    [regex]::Escape("stop-$projectId.ps1"),
    '\.claude[/\\]hooks[/\\](notify|start|stop)\.ps1'
)

# Exact filenames to delete from ~/.claude/hooks/ - the bare legacy names
# are safe here because we're only touching files inside our hooks dir.
$ourFiles = @(
    "notify-$projectId.ps1", "start-$projectId.ps1", "stop-$projectId.ps1",
    'notify.ps1',            'start.ps1',            'stop.ps1'
)
$ourEvents = @('Notification', 'PermissionRequest', 'UserPromptSubmit', 'Stop')

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

function Get-GroupCommand { param($group)
    if (-not $group.hooks) { return $null }
    foreach ($h in $group.hooks) {
        if ($h.type -eq 'command' -and $h.command) { return $h.command }
    }
    return $null
}

function Test-IsOurGroup {
    param($group)
    if (-not $group.hooks) { return $false }
    foreach ($h in $group.hooks) {
        if ($h.type -eq 'command' -and $h.command) {
            foreach ($pattern in $ourPatterns) {
                if ($h.command -match $pattern) { return $true }
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
        $after  = @()
        foreach ($grp in $before) {
            if (Test-IsOurGroup $grp) {
                $cmd = Get-GroupCommand $grp
                Write-Host "Removing $evt hook group: $cmd"
                $removedGroups++
            } else {
                $after += $grp
            }
        }
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

foreach ($f in ($ourFiles + @('notify.log'))) {
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
Write-Host "Done. The removal normally takes effect within seconds."
Write-Host "If the beeps outlive it, run /hooks once (dismiss the dialog) or restart Claude Code."
Write-Host "Backup preserved at: $backup"
