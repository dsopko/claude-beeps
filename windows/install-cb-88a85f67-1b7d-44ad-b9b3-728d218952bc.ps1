# claude-beeps installer (Windows / PowerShell 5.1+)
#
# What it does:
#   1. Reads PROJECT_ID from repo root, computes hook file names.
#   2. Backs up ~/.claude/settings.json (if any) to
#      settings.json.bak-install-<timestamp>.
#   3. Copies notify/start/stop scripts from windows/ to ~/.claude/hooks/.
#   4. One-time legacy migration - triggered only when
#      ~/.claude/hooks/{notify,start,stop}.ps1 exist as files. Removes hook
#      groups whose command matches the anchored pattern
#      \.claude[/\\]hooks[/\\](notify|start|stop)\.ps1 on the four managed
#      events, deletes those legacy files, and announces both.
#   5. Merges the hooks block from settings-hooks-fragment.json into
#      ~/.claude/settings.json, substituting <USERNAME> with $env:USERNAME
#      and preserving all other top-level settings and existing hook
#      groups on the same events. Replaces (with a printed message) any
#      pre-existing hook group belonging to THIS PROJECT_ID.
#   6. Validates the resulting JSON (restores backup on failure).
#   7. Reports what changed. Current Claude Code picks the new hook
#      groups up on its own within seconds; no restart or /hooks reload
#      is issued here, and none is normally needed.
#
# Idempotent: safe to re-run. Existing claude-beeps hook groups for this
# PROJECT_ID are replaced in place; unrelated hook groups on the same
# events are preserved.
#
# Params:
#   -DryRun    Show what would change; don't write anything.
#   -SkipCopy  Skip copying .ps1 files (use if you edited installed files
#              directly and only want to sync the settings.json hooks).
#
# Run:
#   powershell -ExecutionPolicy Bypass -File .\install-cb-<PID>.ps1
#   powershell -ExecutionPolicy Bypass -File .\install-cb-<PID>.ps1 -DryRun

param(
    [switch]$DryRun,
    [switch]$SkipCopy
)

$ErrorActionPreference = 'Stop'

$repoRoot     = Split-Path -Parent $PSScriptRoot   # windows/ -> repo root
$fragmentPath = Join-Path $PSScriptRoot 'settings-hooks-fragment.json'
$idPath       = Join-Path $repoRoot   'PROJECT_ID'

if (-not (Test-Path $idPath)) { throw "PROJECT_ID not found at $idPath" }
$projectId = (Get-Content $idPath -Raw).Trim()
if (-not $projectId) { throw "PROJECT_ID is empty at $idPath" }
Write-Host "Installing project: $projectId"

$notifySrc = Join-Path $PSScriptRoot "notify-$projectId.ps1"
$startSrc  = Join-Path $PSScriptRoot "start-$projectId.ps1"
$stopSrc   = Join-Path $PSScriptRoot "stop-$projectId.ps1"
foreach ($f in @($notifySrc, $startSrc, $stopSrc, $fragmentPath)) {
    if (-not (Test-Path $f)) { throw "Missing required source file: $f" }
}

$claudeDir    = "$env:USERPROFILE\.claude"
$hooksDir     = "$claudeDir\hooks"
$settingsPath = "$claudeDir\settings.json"

$notifyDst = Join-Path $hooksDir "notify-$projectId.ps1"
$startDst  = Join-Path $hooksDir "start-$projectId.ps1"
$stopDst   = Join-Path $hooksDir "stop-$projectId.ps1"

if ($DryRun) { Write-Host "[DRY RUN] no writes will happen" }

# Ensure ~/.claude/hooks/ exists
if (-not (Test-Path $hooksDir)) {
    if ($DryRun) { Write-Host "Would create: $hooksDir" }
    else { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null; Write-Host "Created: $hooksDir" }
}

# Copy the three hook scripts
if (-not $SkipCopy) {
    foreach ($pair in @(@($notifySrc, $notifyDst), @($startSrc, $startDst), @($stopSrc, $stopDst))) {
        $src, $dst = $pair
        if ($DryRun) { Write-Host "Would copy: $src -> $dst" }
        else { Copy-Item $src $dst -Force; Write-Host "Copied: $(Split-Path $dst -Leaf)" }
    }
}

# Load the hooks fragment and substitute <USERNAME>
$fragmentText = (Get-Content $fragmentPath -Raw) -replace '<USERNAME>', $env:USERNAME
$fragment     = $fragmentText | ConvertFrom-Json

# Load or initialize target settings
if (Test-Path $settingsPath) {
    $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    $existing = [pscustomobject]@{}
}

# Back up first (only if settings.json exists)
$backup = $null
if ((Test-Path $settingsPath) -and -not $DryRun) {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$settingsPath.bak-install-$stamp"
    Copy-Item $settingsPath $backup -Force
    Write-Host "Backed up settings.json -> $backup"
}

function HasProperty { param($obj, [string]$name)
    if ($null -eq $obj) { return $false }
    return $null -ne $obj.PSObject.Properties[$name]
}

function Set-Property { param($obj, [string]$name, $value)
    if (HasProperty $obj $name) { $obj.$name = $value }
    else { $obj | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force }
}

function Get-GroupCommand { param($group)
    if (-not $group.hooks) { return $null }
    foreach ($h in $group.hooks) {
        if ($h.type -eq 'command' -and $h.command) { return $h.command }
    }
    return $null
}

$ourGuidPattern = @(
    [regex]::Escape("notify-$projectId.ps1"),
    [regex]::Escape("start-$projectId.ps1"),
    [regex]::Escape("stop-$projectId.ps1")
) -join '|'

function Test-IsOurHookGroup {
    param($group, [string]$pattern)
    if (-not $group.hooks) { return $false }
    foreach ($h in $group.hooks) {
        if ($h.type -eq 'command' -and $h.command -and ($h.command -match $pattern)) {
            return $true
        }
    }
    return $false
}

$ourEvents = @('Notification', 'PermissionRequest', 'UserPromptSubmit', 'Stop')

# --- One-time legacy migration ---
# Gated on file existence: only runs when pre-1.0 bare-name scripts sit
# in ~/.claude/hooks/. The pattern is anchored to that directory so a
# stray restart.ps1 or slack-notify.ps1 elsewhere cannot match.
$legacyBareNames = @('notify.ps1', 'start.ps1', 'stop.ps1')
$legacyFiles     = $legacyBareNames | ForEach-Object { Join-Path $hooksDir $_ }
$legacyPresent   = @($legacyFiles | Where-Object { Test-Path $_ })
$legacyPathPattern = '\.claude[/\\]hooks[/\\](notify|start|stop)\.ps1'

if ($legacyPresent.Count -gt 0) {
    Write-Host "Found pre-1.0 claude-beeps install - migrating."
    if (HasProperty $existing 'hooks') {
        foreach ($evt in $ourEvents) {
            if (-not (HasProperty $existing.hooks $evt)) { continue }
            $before  = @($existing.hooks.$evt)
            $keepers = @()
            foreach ($grp in $before) {
                if (Test-IsOurHookGroup $grp $legacyPathPattern) {
                    $cmd = Get-GroupCommand $grp
                    if ($DryRun) { Write-Host "[DRY RUN] would migrate legacy hook group ($evt): $cmd" }
                    else        { Write-Host "Migrating legacy hook group ($evt): $cmd" }
                } else {
                    $keepers += $grp
                }
            }
            if (-not $DryRun) {
                if ($keepers.Count -eq 0) {
                    $existing.hooks.PSObject.Properties.Remove($evt)
                } else {
                    $existing.hooks.$evt = $keepers
                }
            }
        }
    }
    foreach ($f in $legacyPresent) {
        if ($DryRun) { Write-Host "[DRY RUN] would delete legacy file: $f" }
        else        { Remove-Item $f -Force; Write-Host "Deleted legacy file: $f" }
    }
}

# --- Merge this project's hooks ---
if (-not (HasProperty $existing 'hooks')) {
    Set-Property $existing 'hooks' ([pscustomobject]@{})
}
$targetHooks = $existing.hooks
$fragHooks   = $fragment.hooks

$eventsChanged = @()
foreach ($p in $fragHooks.PSObject.Properties) {
    $evt        = $p.Name
    $ourGroups  = @($p.Value)
    if (HasProperty $targetHooks $evt) {
        $existingGroups = @($targetHooks.$evt)
        $kept = @()
        foreach ($grp in $existingGroups) {
            if (Test-IsOurHookGroup $grp $ourGuidPattern) {
                $cmd = Get-GroupCommand $grp
                Write-Host "Replacing existing claude-beeps hook group ($evt): $cmd"
            } else {
                $kept += $grp
            }
        }
        $merged = @($kept + $ourGroups)
        $targetHooks.$evt = $merged
    } else {
        Set-Property $targetHooks $evt $ourGroups
    }
    $eventsChanged += $evt
}

if ($DryRun) {
    Write-Host "[DRY RUN] would merge hook groups for events: $($eventsChanged -join ', ')"
    Write-Host "[DRY RUN] no settings.json write"
    exit 0
}

# Write and validate
$existing | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
try {
    Get-Content $settingsPath -Raw | ConvertFrom-Json | Out-Null
    Write-Host "settings.json parses OK after merge. Events touched: $($eventsChanged -join ', ')"
} catch {
    Write-Host "ERROR: settings.json failed to parse after write. Restoring $backup"
    if ($backup) { Copy-Item $backup $settingsPath -Force }
    throw
}

Write-Host ""
Write-Host "Install complete."
Write-Host "The hooks normally go live within seconds - just start your next turn."
Write-Host "If a full turn passes with no chime, run '/hooks' in Claude Code (dismiss the dialog) or restart claude."
if ($backup) { Write-Host "Backup preserved at: $backup" }
