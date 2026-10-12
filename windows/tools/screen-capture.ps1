# Ubuntu-style capture bar = Windows Snipping Tool. Win+Shift+S (or PrtSc) opens it: pick area / window /
# full screen, and flip the Screenshot / Record toggle on the bar. Win+Shift+R jumps straight to recording.
# The x47 debloat force-denies background apps for everything, which stops Snipping Tool from saving
# captures and recording; this exempts it. Idempotent.
[CmdletBinding()]
param([string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')
if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
try {
    $pkg = 'Microsoft.ScreenSketch_8wekyb3d8bbwe'
    X47-SetReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground_ForceAllowTheseApps' ([string[]]@($pkg)) ([Microsoft.Win32.RegistryValueKind]::MultiString)
    X47-SetReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$pkg" 'Disabled' 0
    X47-SetReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$pkg" 'DisabledByUser' 0
    X47-Log 'Snipping Tool exempt from the background-apps block' 'OK'

    # PrtSc opens the capture bar too (Ubuntu habit)
    X47-SetReg 'HKCU:\Control Panel\Keyboard' 'PrintScreenKeyForSnippingEnabled' 1
    X47-Log 'PrtSc opens the capture bar' 'OK'

    # Make sure the recording capture service can start on demand
    $cs = 'HKLM:\SYSTEM\CurrentControlSet\Services\CaptureService'
    if ((Get-ItemProperty $cs -ErrorAction SilentlyContinue).Start -eq 4) { Set-ItemProperty $cs -Name Start -Value 3; X47-Log 'CaptureService set to manual' 'OK' }

    # Restart Snipping Tool so it picks up the new policy
    Get-Process SnippingTool, ScreenClippingHost -ErrorAction SilentlyContinue | Stop-Process -Force
    X47-Log 'Done. Win+Shift+S / PrtSc = capture bar (Screenshot/Record toggle). Win+Shift+R = record.' 'OK'
} finally {
    Ops-StopTranscript $OpsTranscript
}
