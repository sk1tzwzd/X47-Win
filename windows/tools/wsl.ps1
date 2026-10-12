# Optional WSL2 + Debian. Not installed by default (the VM costs battery while running).
#   .\tools\wsl.ps1 -Install   # WSL2 + Debian, auto-sleep after 30s idle. Reboot, run "wsl -d Debian" to
#                            # create your Linux user, then .\tools\debian-setup.ps1 for dev packages + ssh keys.
#   .\tools\wsl.ps1 -Remove    # unregister all distros (deletes their files), uninstall WSL, disable
#                            # Virtual Machine Platform. Reboot after.
[CmdletBinding()]
param([switch]$Install, [switch]$Remove, [string]$Distro = 'Debian', [string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')
if (-not ($Install -xor $Remove)) { Write-Host 'Use -Install or -Remove.'; exit 1 }
if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
$wslCfg = Join-Path $env:USERPROFILE '.wslconfig'
try {
    if ($Install) {
        "[wsl2]`r`nmemory=8GB`r`nswap=4GB`r`nvmIdleTimeout=30000`r`n" | Set-Content $wslCfg -Encoding ASCII
        X47-Log 'wrote .wslconfig (8GB cap, sleeps 30s after last use)' 'OK'
        $distros = (wsl.exe --list --quiet 2>$null) -replace "`0", ''
        if ($distros -match $Distro) { X47-Log "WSL $Distro already present" }
        else {
            wsl.exe --install -d $Distro --no-launch 2>&1 | Out-Host
            X47-Log "WSL2 + $Distro requested. Reboot if asked, then: wsl -d $Distro (create user), then .\tools\debian-setup.ps1" 'WARN'
        }
    }
    if ($Remove) {
        wsl.exe --shutdown 2>$null
        $distros = @((wsl.exe --list --quiet 2>$null) -replace "`0", '' | Where-Object { $_.Trim() })
        foreach ($d in $distros) { wsl.exe --unregister $d.Trim() | Out-Null; X47-Log "unregistered $($d.Trim())" 'OK' }
        wsl.exe --uninstall 2>&1 | Out-Null
        X47-Log 'WSL app uninstalled' 'OK'
        foreach ($f in 'VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux') {
            $st = (Get-WindowsOptionalFeature -Online -FeatureName $f).State
            if ($st -eq 'Enabled') { Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart | Out-Null; X47-Log "disabled $f" 'OK' }
        }
        if (Test-Path $wslCfg) { Remove-Item $wslCfg -Force }
        X47-Log 'WSL removed. Reboot to finish.' 'WARN'
    }
} finally {
    Ops-StopTranscript $OpsTranscript
}
