#requires -RunAsAdministrator
<#
.SYNOPSIS
  Undo an X47-Win install using the snapshot in <KitRoot>\rollback.
  Does not delete user files. Does not turn BitLocker off.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$KitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $KitRoot 'lib\X47Common.ps1')
$script:X47Root = $KitRoot

X47-RequireAdmin
X47-EnsureLog

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' X47-Win — rollback' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'This restores registry, hosts, services, firewall, wallpaper,'
Write-Host "and NTP from $KitRoot\rollback. Documents are not deleted."
Write-Host 'Store apps may need Microsoft Store or System Restore.'
Write-Host 'BitLocker is left alone.'
Write-Host ''
$go = Read-Host 'Type ROLLBACK to undo the kit'
if ($go -ne 'ROLLBACK') {
    X47-Log 'rollback aborted by user'
    exit 1
}

X47-RestoreKit -KitRoot $KitRoot
