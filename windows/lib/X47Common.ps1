# Shared helpers for the X47 Windows kit. Dot-source from other scripts.
if (-not $script:X47Root) {
    $script:X47Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    if (-not $script:X47Root) { $script:X47Root = 'C:\X47' }
}
# X47SnapshotActive is deliberately NOT initialised here. Modules run in their own
# script scope (& modules\NN-*.ps1) and re-dot-source this file, so a $script:-scoped
# flag would be reset to $false and every X47-Journal* call would no-op — leaving
# rollback with nothing to restore. The flag lives in $global: and stays unset until
# something decides; see X47-SnapshotIsActive in X47Rollback.ps1.
$rb = Join-Path $PSScriptRoot 'X47Rollback.ps1'
if (Test-Path $rb) { . $rb }

# Log dir/file are $global: for the same reason: one log per run, not one per module.
function X47-EnsureLog {
    $desired = Join-Path $script:X47Root 'logs'
    if ($global:X47LogDir -ne $desired) {
        $global:X47LogDir = $desired
        $global:X47LogFile = $null
    }
    if (-not (Test-Path $global:X47LogDir)) {
        New-Item -ItemType Directory -Path $global:X47LogDir -Force | Out-Null
    }
    if (-not $global:X47LogFile) {
        $global:X47LogFile = Join-Path $global:X47LogDir ("x47-windows-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
    }
}

function X47-Log {
    param([string]$Message, [string]$Level = 'INFO')
    X47-EnsureLog
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
    Add-Content -Path $global:X47LogFile -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'OK' { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
}

function X47-RequireAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $prin = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $prin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'X47 Windows kit must run in an elevated (Administrator) PowerShell.'
    }
}

function X47-SetReg {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )
    if (Get-Command X47-JournalReg -ErrorAction SilentlyContinue) {
        X47-JournalReg -Path $Path -Name $Name -Action 'set'
    }
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function X47-RemoveReg {
    param([string]$Path, [string]$Name)
    if (Get-Command X47-JournalReg -ErrorAction SilentlyContinue) {
        X47-JournalReg -Path $Path -Name $Name -Action 'remove'
    }
    Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
}

function X47-DisableService {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        X47-Log "service $Name not present — skip"
        return
    }
    if (Get-Command X47-JournalService -ErrorAction SilentlyContinue) {
        X47-JournalService -Name $Name
    }
    try {
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
        X47-Log "disabled service $Name" 'OK'
    } catch {
        X47-Log "could not disable ${Name}: $($_.Exception.Message)" 'WARN'
    }
}
