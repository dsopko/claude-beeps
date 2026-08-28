# claude-beeps installer (Windows / PowerShell 5.1+)
#
# What it does:
#   1. Reads PROJECT_ID from repo root, computes hook file names.
#   2. Backs up ~/.claude/settings.json (if any) to
#      settings.json.bak-install-<timestamp>.
#   3. Copies notify/start/stop scripts from windows/ to ~/.claude/hooks/.
#   4. Merges the hooks block from settings-hooks-fragment.json into
#      ~/.claude/settings.json, substituting <USERNAME> with $env:USERNAME
#      and preserving all other top-level settings and existing hook
#      groups on the same events.
#   5. Validates the resulting JSON (restores backup on failure).
#   6. Reports what changed. Does NOT restart Claude Code or trigger
#      the /hooks reload — the caller (Claude, or the user) must do that.
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

function Test-IsOurHookGroup {
    param($group, [string]$projectId)
    if (-not $group.hooks) { return $false }
    foreach ($h in $group.hooks) {
        if ($h.type -eq 'command' -and $h.command) {
            if ($h.command -match "notify-$projectId\.ps1|start-$projectId\.ps1|stop-$projectId\.ps1|notify\.ps1|start\.ps1|stop\.ps1") {
                return $true
            }
        }
    }
    return $false
}

# Merge hooks
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
        # Drop any pre-existing claude-beeps groups for this project id
        # (or legacy pre-GUID groups) so re-runs don't stack duplicates.
        $kept = @($existingGroups | Where-Object { -not (Test-IsOurHookGroup $_ $projectId) })
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
Write-Host "Reload required: run '/hooks' in Claude Code (dismiss the dialog) or restart claude."
if ($backup) { Write-Host "Backup preserved at: $backup" }
