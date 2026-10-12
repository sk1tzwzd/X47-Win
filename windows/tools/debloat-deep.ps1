# Deep debloat: disable services a home PC never uses, drop legacy Windows features/capabilities,
# and turn off leftover telemetry tasks. Records every service's previous start type so -Undo restores it.
#   .\tools\debloat-deep.ps1 -DryRun   # list what would change
#   .\tools\debloat-deep.ps1           # apply (self-elevates)
#   .\tools\debloat-deep.ps1 -Undo     # restore services from the newest journal
# Kept on purpose: Bluetooth, Xbox controller (XboxGipSvc), GameInput, camera, Windows Search, SysMain,
# Print spooler (Print to PDF, local only), Store, Insider service (Insider builds need it), OEM services (e.g. Acer NitroSense), CaptureService (Snipping Tool).
[CmdletBinding()]
param([switch]$DryRun, [switch]$Undo, [string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')

$services = [ordered]@{
    'Xbox / Game DVR'          = 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'BcastDVRUserService'
    'Phone / payments / cell'  = 'PhoneSvc', 'SmsRouter', 'MessagingService', 'WalletService', 'SEMgrSvc', 'autotimesvc', 'wlpasvc', 'icssvc', 'SharedAccess'
    'AI / telemetry'           = 'WSAIFabricSvc', 'InventorySvc', 'whesvc', 'CDPSvc', 'CDPUserSvc', 'diagnosticshub.standardcollector.service'
    'Enterprise / remote'      = 'Netlogon', 'DmEnrollmentSvc', 'workfolderssvc', 'MSiSCSI', 'SNMPTrap', 'SessionEnv', 'UmRdpService', 'TermService', 'WebClient', 'TapiSrv', 'EntAppSvc', 'embeddedmode', 'PeerDistSvc', 'NetTcpPortSharing', 'RemoteAccess', 'SstpSvc', 'lltdsvc', 'WMPNetworkSvc', 'WpcMonSvc', 'perceptionsimulation', 'SharedRealitySvc', 'spectrum', 'PushToInstall', 'LanmanServer'
    'Hyper-V guest (bare metal)' = 'vmicguestinterface', 'vmicheartbeat', 'vmickvpexchange', 'vmicrdv', 'vmicshutdown', 'vmictimesync', 'vmicvmsession', 'vmicvss'
    'Smart card / pen / sensors' = 'SCardSvr', 'ScDeviceEnum', 'SCPolicySvc', 'PenService', 'SensrSvc', 'SensorDataService', 'SensorService'
    'Printer extras / scanning' = 'PrintNotify', 'StiSvc', 'WiaRpc'   # Spooler kept for Print to PDF (see below)
    'Hello / casting'          = 'WbioSrvc', 'NaturalAuthentication', 'WFDSConMgrSvc', 'wcncsvc'
}
$features = 'MicrosoftWindowsPowerShellV2Root', 'MicrosoftWindowsPowerShellV2', 'WorkFolders-Client', 'Printing-XPSServices-Features',
    'Internet-Explorer-Optional-amd64', 'Recall', 'Printing-Foundation-InternetPrinting-Client'
$capabilities = 'App.StepsRecorder', 'MathRecognizer', 'Media.WindowsMediaPlayer', 'Browser.InternetExplorer', 'App.Support.QuickAssist',
    'Print.Fax.Scan', 'XPS.Viewer', 'Hello.Face', 'Microsoft.Windows.WordPad'
$tasks = @(
    '\Microsoft\Windows\Maps\MapsUpdateTask', '\Microsoft\Windows\Maps\MapsToastTask',
    '\Microsoft\Windows\Shell\FamilySafetyMonitor', '\Microsoft\Windows\Shell\FamilySafetyRefreshTask',
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting', '\Microsoft\Windows\PI\Sqm-Tasks',
    '\Microsoft\Windows\NetTrace\GatherNetworkInfo', '\Microsoft\Windows\Speech\SpeechModelDownloadTask',
    '\Microsoft\Windows\XblGameSave\XblGameSaveTask', '\Microsoft\Windows\Device Information\Device',
    '\Microsoft\Windows\Device Information\Device User', '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
    '\Microsoft\Windows\Location\Notifications', '\Microsoft\Windows\Location\WindowsActionDialog'
)
$svcRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services'

if ($DryRun) {
    foreach ($grp in $services.Keys) {
        $live = $services[$grp] | Where-Object { Test-Path "$svcRoot\$_" } | Where-Object { (Get-ItemProperty "$svcRoot\$_").Start -ne 4 }
        if ($live) { Write-Host "[$grp]" -ForegroundColor Cyan; $live | ForEach-Object { "  disable $_" } }
    }
    Write-Host '[Windows features]' -ForegroundColor Cyan; $features | ForEach-Object { "  disable $_ (if enabled)" }
    Write-Host '[Capabilities]' -ForegroundColor Cyan; $capabilities | ForEach-Object { "  remove $_* (if installed)" }
    Write-Host '[Scheduled tasks]' -ForegroundColor Cyan; $tasks | ForEach-Object { "  disable $_" }
    Write-Host '[Policy]' -ForegroundColor Cyan; '  Delivery Optimization: no peer-to-peer upload/download'
    exit 0
}

if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
$logDir = Join-Path $script:OpsRepo 'logs'
try {
    if ($Undo) {
        $j = Get-ChildItem $logDir -Filter 'debloat-deep-journal-*.json' | Sort-Object Name | Select-Object -Last 1
        if (-not $j) { throw 'no journal found in logs\' }
        $prev = Get-Content $j.FullName -Raw | ConvertFrom-Json
        foreach ($p in $prev.PSObject.Properties) {
            Set-ItemProperty "$svcRoot\$($p.Name)" -Name Start -Value ([int]$p.Value) -ErrorAction SilentlyContinue
            X47-Log "restored $($p.Name) Start=$($p.Value)" 'OK'
        }
        X47-Log "services restored from $($j.Name). Reboot to apply. (Features/capabilities: re-add in Settings > Optional features.)" 'WARN'
        return
    }

    # --- services: journal old Start value, then Start=4 via registry (works for per-user service templates too)
    $journal = [ordered]@{}
    foreach ($grp in $services.Keys) {
        foreach ($s in $services[$grp]) {
            $key = "$svcRoot\$s"
            if (-not (Test-Path $key)) { continue }
            $old = (Get-ItemProperty $key -ErrorAction SilentlyContinue).Start
            if ($old -eq 4) { continue }
            $journal[$s] = $old
            Stop-Service $s -Force -ErrorAction SilentlyContinue
            try { Set-ItemProperty $key -Name Start -Value 4 -ErrorAction Stop; X47-Log "disabled $s ($grp)" 'OK' }
            catch { X47-Log "could not disable ${s}: $($_.Exception.Message)" 'WARN'; $journal.Remove($s) }
        }
    }
    if ($journal.Count) {
        $jf = Join-Path $logDir ("debloat-deep-journal-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))
        $journal | ConvertTo-Json | Set-Content $jf -Encoding UTF8
        X47-Log "journal: $jf (use -Undo to restore)" 'OK'
    }

    # --- optional features
    foreach ($f in $features) {
        $st = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
        if ($st -and $st.State -eq 'Enabled') {
            try { Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction Stop | Out-Null; X47-Log "feature off: $f" 'OK' }
            catch { X47-Log "feature ${f}: $($_.Exception.Message)" 'WARN' }
        }
    }

    # --- capabilities (features on demand)
    $caps = Get-WindowsCapability -Online | Where-Object { $_.State -eq 'Installed' }
    foreach ($c in $capabilities) {
        foreach ($hit in ($caps | Where-Object { $_.Name -like "$c*" })) {
            try { Remove-WindowsCapability -Online -Name $hit.Name -ErrorAction Stop | Out-Null; X47-Log "removed capability $($hit.Name)" 'OK' }
            catch { X47-Log "capability $($hit.Name): $($_.Exception.Message)" 'WARN' }
        }
    }

    # --- scheduled tasks
    foreach ($t in $tasks) {
        $path = (Split-Path $t -Parent) + '\'; $name = Split-Path $t -Leaf
        $task = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue
        if ($task -and $task.State -ne 'Disabled') {
            try { $task | Disable-ScheduledTask -ErrorAction Stop | Out-Null; X47-Log "task off: $name" 'OK' } catch { X47-Log "task ${name}: $($_.Exception.Message)" 'WARN' }
        }
    }

    # --- Print to PDF stays: spooler on, but no remote connections to it (PrintNightmare-class attacks)
    Set-ItemProperty "$svcRoot\Spooler" -Name Start -Value 2
    Set-ItemProperty "$svcRoot\PrintWorkflowUserSvc" -Name Start -Value 3
    X47-SetReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers' 'RegisterSpoolerRemoteRpcEndPoint' 2
    Start-Service Spooler -ErrorAction SilentlyContinue
    X47-Log 'print spooler on for Print to PDF (remote RPC endpoint off)' 'OK'

    # --- Delivery Optimization: HTTP only (no P2P sharing of your bandwidth)
    X47-SetReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0

    X47-Log 'deep debloat done. Reboot to finish (services + features).' 'WARN'
} finally {
    Ops-StopTranscript $OpsTranscript
}
