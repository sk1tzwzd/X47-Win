# Shared helpers for tools\ scripts. Dot-source as the first line of every tool:
#   . (Join-Path $PSScriptRoot 'lib\Ops.ps1')
# Reuses the kit's logging/registry helpers (lib\X47Common.ps1); logs land in <kit>\logs.

$script:OpsRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $script:OpsRepo 'lib\X47Common.ps1')
$script:X47Root = $script:OpsRepo

function Ops-IsAdmin {
    $prin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $prin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Re-launch the calling script elevated (one UAC prompt), wait for it, then echo its
# transcript so a non-elevated caller (e.g. Claude's shell) sees the full output.
# Returns $true in the original process when it handed off; caller should then exit.
function Ops-Elevate {
    param([string]$ScriptPath, [hashtable]$BoundParams)
    if (Ops-IsAdmin) { return $false }
    $logDir = Join-Path $script:OpsRepo 'logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $name = [IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $transcript = Join-Path $logDir ("{0}-{1:yyyyMMdd-HHmmss}.log" -f $name, (Get-Date))
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$ScriptPath`"", '-OpsTranscript', "`"$transcript`"")
    foreach ($k in $BoundParams.Keys) {
        $v = $BoundParams[$k]
        if ($v -is [switch] -or $v -is [bool]) { if ($v) { $argList += "-$k" } }
        else { $argList += "-$k"; $argList += "`"$v`"" }
    }
    Write-Host "Requesting elevation for $name (approve the UAC prompt)..." -ForegroundColor Cyan
    # Minimized: a click inside a visible console turns on QuickEdit selection and freezes the script.
    try { $p = Start-Process powershell.exe -Verb RunAs -WindowStyle Minimized -ArgumentList $argList -Wait -PassThru -ErrorAction Stop }
    catch { Write-Host "UAC prompt was cancelled; nothing changed." -ForegroundColor Yellow; $global:LASTEXITCODE = 1223; return $true }
    if (Test-Path $transcript) { Get-Content $transcript | Out-Host }
    Write-Host "[$name exited $($p.ExitCode); transcript: $transcript]"
    $global:LASTEXITCODE = $p.ExitCode
    return $true
}

function Ops-StartTranscript {
    param([string]$Path)
    if ($Path) { Start-Transcript -Path $Path -Force | Out-Null }
}

function Ops-StopTranscript {
    param([string]$Path)
    if ($Path) { try { Stop-Transcript | Out-Null } catch {} }
}

# winget install that is idempotent and quiet; returns $true if present afterwards.
function Ops-Winget {
    param([string]$Id, [string[]]$Extra = @())
    $listed = winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String
    if ($listed -match [regex]::Escape($Id)) { X47-Log "$Id already installed"; return $true }
    X47-Log "installing $Id"
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity @Extra
    if ($LASTEXITCODE -eq 0) { X47-Log "$Id installed" 'OK'; return $true }
    X47-Log "$Id install failed (exit $LASTEXITCODE)" 'WARN'; return $false
}

function Ops-RefreshPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
