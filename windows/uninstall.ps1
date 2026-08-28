# claude-beeps uninstaller (Windows / PowerShell 5.1+)
#
# Removes ONLY the hook groups whose command references our scripts
# (notify.ps1, start.ps1, stop.ps1). Leaves every other hook group and
# every other settings key untouched. Safe to run multiple times.
#
# What it does:
#   1. Backs up ~/.claude/settings.json to settings.json.bak-uninstall-<timestamp>
#   2. Reads the settings, filters out our hook groups from each event
#   3. Removes any event key whose hooks array ends up empty
#   4. Writes settings.json back and validates it parses
#   5. Deletes the three .ps1 files and notify.log from ~/.claude/hooks/
#      (leaves the hooks directory itself in case other tools use it)
#
# Run:
#   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

$ErrorActionPreference = 'Stop'

$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$hooksDir     = "$env:USERPROFILE\.claude\hooks"
$ourScripts   = @('notify.ps1', 'start.ps1', 'stop.ps1')
$ourEvents    = @('Notification', 'PermissionRequest', 'UserPromptSubmit', 'Stop')

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
    # If hooks object is now completely empty, remove it entirely
    if (@($data.hooks.PSObject.Properties).Count -eq 0) {
        $data.PSObject.Properties.Remove('hooks')
    }
}

# Write back with pretty formatting
$data | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8

# Validate
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

# Remove hook scripts and log
foreach ($f in ($ourScripts + @('notify.log'))) {
    $p = Join-Path $hooksDir $f
    if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "Deleted $p"
    }
}
# Best-effort: remove any leftover start-<session>.txt timestamps
Get-ChildItem $hooksDir -Filter 'start-*.txt' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force
    Write-Host "Deleted $($_.FullName)"
}

Write-Host ""
Write-Host "Done. Restart Claude Code (or run /hooks once) so the change takes effect."
Write-Host "Backup preserved at: $backup"
