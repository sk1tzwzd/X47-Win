# Extra hardening on top of the x47 kit. Idempotent.
#   - Defender back to full protection + network protection, high cloud block level, PUA block
#   - Compatibility-telemetry scheduled tasks off
#   - LAN discovery (SSDP/UPnP), geolocation and Maps services off
# Tamper protection cannot be scripted: switch it on in Windows Security afterwards.
[CmdletBinding()]
param([switch]$NoScan, [string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')
if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
try {
    # --- Defender
    Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false -DisableIOAVProtection $false `
        -DisableScriptScanning $false -PUAProtection Enabled -EnableNetworkProtection Enabled `
        -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -CloudBlockLevel High -CloudExtendedTimeout 20
    Update-MpSignature -ErrorAction SilentlyContinue
    $s = Get-MpComputerStatus
    X47-Log ("defender: realtime={0} behaviour={1} ioav={2} tamper={3}" -f $s.RealTimeProtectionEnabled, $s.BehaviorMonitorEnabled, $s.IoavProtectionEnabled, $s.IsTamperProtected) 'OK'

    # --- telemetry scheduled tasks
    $tasks = @(
        @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser Exp'),
        @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
        @('\Microsoft\Windows\Application Experience\', 'MareBackup'),
        @('\Microsoft\Windows\Application Experience\', 'PcaPatchDbTask'),
        @('\Microsoft\Windows\Application Experience\', 'StartupAppTask'),
        @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
        @('\Microsoft\Windows\Autochk\', 'Proxy'),
        @('\Microsoft\Windows\DiskDiagnostic\', 'Microsoft-Windows-DiskDiagnosticDataCollector'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClient'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClientOnScenarioDownload')
    )
    foreach ($t in $tasks) {
        $task = Get-ScheduledTask -TaskPath $t[0] -TaskName $t[1] -ErrorAction SilentlyContinue
        if ($task -and $task.State -ne 'Disabled') {
            try { $task | Disable-ScheduledTask -ErrorAction Stop | Out-Null; X47-Log "disabled task $($t[1])" 'OK' }
            catch { X47-Log "could not disable task $($t[1]): $($_.Exception.Message)" 'WARN' }
        }
    }

    # --- LAN discovery / location services
    foreach ($svc in 'SSDPSRV', 'upnphost', 'lfsvc', 'MapsBroker') { X47-DisableService $svc }

    if (-not $NoScan) {
        X47-Log 'quick scan starting'
        Start-MpScan -ScanType QuickScan
        $t = Get-MpThreatDetection
        if ($t) { X47-Log "quick scan: $(@($t).Count) detection(s), see Windows Security > Protection history" 'WARN' }
        else { X47-Log 'quick scan: clean' 'OK' }
    }
    X47-Log 'Now switch on Tamper Protection: Windows Security > Virus & threat protection > Manage settings.' 'WARN'
} finally {
    Ops-StopTranscript $OpsTranscript
}
