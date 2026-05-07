<#
.SYNOPSIS
    PowerShell fallback for the Settings_Writer component.
    Merges required JSON key-value pairs into a settings file, creates a backup
    before writing, and emits a per-key change report.

.DESCRIPTION
    Implements the same backup + merge + change-report logic as settings_writer.py.
    Invoked automatically by the bat scripts when Python is unavailable.

    Exit codes:
        0  — success (all keys merged, backup created, file written)
        1  — any error (malformed JSON, backup failure, or unexpected write error)

.PARAMETER SettingsPath
    Full path to the JSON settings file to read and update.
    If the file does not exist it will be created (along with parent directories).

.PARAMETER RequiredKeysJson
    A JSON string representing an object whose properties are the required
    key-value pairs to merge into the settings file.
    Example: '{"chat.autopilot.enabled":true,"chat.agent.maxRequests":500}'

.EXAMPLE
    .\settings_writer_fallback.ps1 `
        -SettingsPath "$env:APPDATA\Code\User\settings.json" `
        -RequiredKeysJson '{"chat.autopilot.enabled":true,"chat.agent.enabled":true}'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SettingsPath,

    [Parameter(Mandatory = $true)]
    [string]$RequiredKeysJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. Parse the required keys
# ---------------------------------------------------------------------------
try {
    $requiredKeys = $RequiredKeysJson | ConvertFrom-Json
}
catch {
    Write-Host "ERROR: Could not parse RequiredKeysJson: $_"
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Read (or initialise) the existing settings
# ---------------------------------------------------------------------------
$settingsDir = Split-Path -Parent $SettingsPath

if (-not (Test-Path $SettingsPath)) {
    # Create parent directories and an empty JSON object
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
    '{}' | Set-Content -Path $SettingsPath -Encoding UTF8
}

$rawContent = Get-Content -Path $SettingsPath -Raw -Encoding UTF8

# Guard against a completely empty file
if ([string]::IsNullOrWhiteSpace($rawContent)) {
    $rawContent = '{}'
}

# Validate JSON before touching anything
try {
    $settings = $rawContent | ConvertFrom-Json
}
catch {
    Write-Host "ERROR: Malformed JSON in '$SettingsPath': $_"
    exit 1
}

# ---------------------------------------------------------------------------
# 3. Create backup BEFORE any modification
# ---------------------------------------------------------------------------
$backupPath = "$SettingsPath.pre-autopilot.bak"
try {
    Copy-Item -Path $SettingsPath -Destination $backupPath -Force
}
catch {
    Write-Host "ERROR: Could not create backup '$backupPath': $_"
    Write-Host "Aborting — original file has NOT been modified."
    exit 1
}

# ---------------------------------------------------------------------------
# 4. Merge required keys and build change report
# ---------------------------------------------------------------------------
# ConvertFrom-Json returns a PSCustomObject; we need to inspect its properties
# to determine whether a key already exists and what its current value is.

$changeReport = [ordered]@{}

foreach ($prop in $requiredKeys.PSObject.Properties) {
    $key           = $prop.Name
    $requiredValue = $prop.Value

    # Check whether the key already exists on the settings object
    $existingProp = $settings.PSObject.Properties[$key]

    if ($null -eq $existingProp) {
        # Key is absent — add it
        $settings | Add-Member -MemberType NoteProperty -Name $key -Value $requiredValue -Force
        $changeReport[$key] = 'ADDED'
    }
    else {
        # Key exists — compare values
        # Serialize both sides to JSON for a reliable deep-equality check
        $existingJson  = $existingProp.Value  | ConvertTo-Json -Depth 10 -Compress
        $requiredJson  = $requiredValue        | ConvertTo-Json -Depth 10 -Compress

        if ($existingJson -ne $requiredJson) {
            $settings | Add-Member -MemberType NoteProperty -Name $key -Value $requiredValue -Force
            $changeReport[$key] = 'UPDATED'
        }
        else {
            $changeReport[$key] = 'ALREADY CORRECT'
        }
    }
}

# ---------------------------------------------------------------------------
# 5. Write the merged settings back to disk
# ---------------------------------------------------------------------------
try {
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsPath -Encoding UTF8
}
catch {
    Write-Host "ERROR: Failed to write '$SettingsPath': $_"
    exit 1
}

# ---------------------------------------------------------------------------
# 6. Emit the per-key change report (same format as the Python component)
# ---------------------------------------------------------------------------
foreach ($entry in $changeReport.GetEnumerator()) {
    Write-Host "  $($entry.Key): $($entry.Value)"
}

exit 0
