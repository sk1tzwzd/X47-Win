# Mullvad VPN baseline. Idempotent, no admin (the CLI talks to the Mullvad service).
#   Always: auto-connect at boot, LAN sharing allowed (Ubuntu X47 transfers), connect now.
#   -Lockdown : block all internet whenever the VPN is down (kill switch). Gaming Mode lifts/restores it.
#   -Blockers : Mullvad DNS blocking of ads, trackers, malware.
[CmdletBinding()]
param([switch]$Lockdown, [switch]$Blockers)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')

$mv = "$env:ProgramFiles\Mullvad VPN\resources\mullvad.exe"
if (-not (Test-Path $mv)) { X47-Log 'Mullvad not installed' 'WARN'; exit 1 }
if ((& $mv account get 2>&1) -match 'Not logged in') { X47-Log 'Mullvad: log in to your account in the app first' 'WARN'; exit 1 }

& $mv auto-connect set on | Out-Null
& $mv lan set allow | Out-Null
if ($Lockdown) { & $mv lockdown-mode set on | Out-Null }
if ($Blockers) { & $mv dns set default --block-ads --block-trackers --block-malware | Out-Null }
& $mv connect --wait 2>&1 | Out-Null

X47-Log ("mullvad: " + ((& $mv status | Select-Object -First 1) -join '')) 'OK'
& $mv auto-connect get; & $mv lan get; & $mv lockdown-mode get
