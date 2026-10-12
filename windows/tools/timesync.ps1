# Keep the clock right: Windows Time on, synced to non-Microsoft NTP, resync now. Idempotent.
#   .\tools\timesync.ps1 [-Zone 'GMT Standard Time' (any Windows time zone id)]
[CmdletBinding()]
param([string]$Zone, [string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')
if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
try {
    $peers = 'time.cloudflare.com,0x9 0.pool.ntp.org,0x9 1.pool.ntp.org,0x9'
    Set-Service W32Time -StartupType Automatic
    Start-Service W32Time
    w32tm /config /manualpeerlist:"$peers" /syncfromflags:manual /reliable:no /update | Out-Null
    # poll every 30-60 min; accept big corrections once (clock was hours off)
    $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time'
    X47-SetReg "$p\Config" 'MaxPosPhaseCorrection' ([int]0xFFFFFFFF)
    X47-SetReg "$p\Config" 'MaxNegPhaseCorrection' ([int]0xFFFFFFFF)
    X47-SetReg "$p\TimeProviders\NtpClient" 'SpecialPollInterval' 1800
    Restart-Service W32Time
    w32tm /resync /force | Out-Host
    if ($Zone) { Set-TimeZone -Id $Zone; X47-Log "time zone -> $Zone" 'OK' }
    X47-Log ("clock now {0:yyyy-MM-dd HH:mm:ss zzz} ({1})" -f (Get-Date), (Get-TimeZone).Id) 'OK'
    w32tm /query /status | Select-Object -First 7 | Out-Host
} finally {
    Ops-StopTranscript $OpsTranscript
}
