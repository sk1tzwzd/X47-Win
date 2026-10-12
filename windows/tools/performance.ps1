# Always-on performance for gaming laptops and desktops. Idempotent. Reboot after first run.
#   - Hardware-accelerated GPU scheduling on
#   - Plugged in: Windows power mode "Best performance" + aggressive CPU boost. Battery stays Balanced.
#   - NVIDIA Control Panel (Store app the DCH driver needs), only if an NVIDIA GPU is present
# Laptop CPUs are usually locked (no overclock/undervolt). Bigger wins: the OEM performance mode app, and NVIDIA App > Performance > Auto-tune.
[CmdletBinding()]
param([string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')
if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
try {
    # HAGS (2 = on). RTX 30 + recent driver: lower latency, small FPS gain.
    X47-SetReg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
    X47-Log 'hardware GPU scheduling on (after reboot)' 'OK'

    # Overlays only apply on the Balanced plan, so keep Balanced active and set the AC overlay.
    $balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
    $bestPerf = 'ded574b5-45a0-4f42-8737-46345c09c238'
    powercfg /setactive $balanced
    # The overlay key is ACL-protected; powercfg sets it for the CURRENT power source, so only do it on AC.
    $onAc = (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1).BatteryStatus -ne 1
    if ($onAc) { powercfg /overlaysetactive $bestPerf; X47-Log 'AC power mode: Best performance' 'OK' }
    else { X47-Log 'on battery: plug in and re-run to set the AC power mode' 'WARN' }
    # CPU boost: AC aggressive (2), battery enabled (1); full max state on AC
    powercfg /setacvalueindex $balanced SUB_PROCESSOR PERFBOOSTMODE 2
    powercfg /setdcvalueindex $balanced SUB_PROCESSOR PERFBOOSTMODE 1
    powercfg /setacvalueindex $balanced SUB_PROCESSOR PROCTHROTTLEMAX 100
    # don't park/suspend the NVMe or PCIe link while plugged in
    powercfg /setacvalueindex $balanced SUB_PCIEXPRESS ASPM 0
    powercfg /setactive $balanced
    X47-Log 'plugged in: Best performance mode + aggressive boost; battery: balanced' 'OK'

    # NVIDIA Control Panel (msstore) - install before the x47 anonymity pass blocks Store hosts
    $nvidia = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' }
    if (-not $nvidia) { X47-Log 'no NVIDIA GPU: skipping NVIDIA Control Panel' }
    elseif (-not (Get-AppxPackage -AllUsers -Name 'NVIDIACorp.NVIDIAControlPanel' -ErrorAction SilentlyContinue)) {
        winget install --id 9NF8H0H7WMLT --source msstore --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { X47-Log 'NVIDIA Control Panel installed' 'OK' } else { X47-Log "NVIDIA Control Panel install failed ($LASTEXITCODE)" 'WARN' }
    } else { X47-Log 'NVIDIA Control Panel already installed' }

    X47-Log 'Reboot to apply GPU scheduling.' 'WARN'
} finally {
    Ops-StopTranscript $OpsTranscript
}
