# Key-only OpenSSH server reachable from ONE LAN host (the Ubuntu X47 box). Idempotent.
#   .\tools\ssh-transfer.ps1 -UbuntuIp 192.168.1.50 -UbuntuUser you
#   .\tools\ssh-transfer.ps1 -UbuntuIp 192.168.1.50 -UbuntuUser you -PubKey 'ssh-ed25519 AAAA... you@laptop'   # or a path to a .pub file
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$UbuntuIp,
    [string]$PubKey,
    [Parameter(Mandatory)][string]$UbuntuUser,
    [string]$OpsTranscript
)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')
if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
$ErrorActionPreference = 'Stop'
try {
    [void][Net.IPAddress]::Parse($UbuntuIp)

    # --- server capability + services
    $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*'
    if ($cap.State -ne 'Installed') {
        $r = Add-WindowsCapability -Online -Name $cap.Name
        X47-Log "OpenSSH.Server capability added (restart needed: $($r.RestartNeeded))" 'OK'
    }
    if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
        X47-Log 'sshd is staged but not registered yet: REBOOT, then re-run this script.' 'WARN'
        exit 2
    }
    Set-Service sshd -StartupType Automatic
    Set-Service ssh-agent -StartupType Automatic
    Start-Service ssh-agent
    if (-not (Test-Path "$env:ProgramData\ssh\sshd_config")) { Start-Service sshd; Stop-Service sshd }  # first start generates config + host keys

    # --- sshd_config: prepend a managed block (sshd uses the first value it reads)
    $cfgPath = "$env:ProgramData\ssh\sshd_config"
    $cfg = Get-Content $cfgPath -Raw
    $cfg = [regex]::Replace($cfg, '(?s)# >>> x47-ops >>>.*?# <<< x47-ops <<<\r?\n', '')
    $block = @"
# >>> x47-ops >>>
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
AllowUsers $env:USERNAME
MaxAuthTries 3
LoginGraceTime 30
# <<< x47-ops <<<

"@
    Set-Content $cfgPath -Value ($block + $cfg) -Encoding ASCII
    X47-Log "sshd_config: key-only, AllowUsers $env:USERNAME" 'OK'

    # --- default shell
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    $shell = if ($pwsh) { $pwsh } else { "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" }
    New-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value $shell -PropertyType String -Force | Out-Null

    # --- admin users authenticate from administrators_authorized_keys (Administrators + SYSTEM only)
    $ak = "$env:ProgramData\ssh\administrators_authorized_keys"
    if (-not (Test-Path $ak)) { New-Item $ak -ItemType File | Out-Null }
    if ($PubKey) {
        $key = if (Test-Path $PubKey) { (Get-Content $PubKey -Raw).Trim() } else { $PubKey.Trim() }
        if ($key -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-\S+|sk-\S+) ') { throw 'PubKey does not look like an OpenSSH public key' }
        if (-not (Select-String -Path $ak -SimpleMatch $key -Quiet)) { Add-Content $ak $key -Encoding ASCII; X47-Log 'added public key' 'OK' }
    }
    icacls $ak /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null

    # --- firewall: drop the capability's allow-any rule, allow 22 from the Ubuntu box only
    Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Get-NetFirewallRule -Name 'X47-SSH-Ubuntu' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -Name 'X47-SSH-Ubuntu' -DisplayName 'X47 SSH from Ubuntu' -Direction Inbound -Protocol TCP `
        -LocalPort 22 -RemoteAddress $UbuntuIp -Action Allow -Profile Any -Program "$env:windir\System32\OpenSSH\sshd.exe" | Out-Null
    X47-Log "firewall: TCP 22 allowed from $UbuntuIp only" 'OK'

    # --- Mullvad: allow LAN while the tunnel is up (or in lockdown), otherwise the Ubuntu box is cut off
    $mv = "$env:ProgramFiles\Mullvad VPN\resources\mullvad.exe"
    if (Test-Path $mv) { & $mv lan set allow | Out-Null; X47-Log 'mullvad: local network sharing = allow' 'OK' }

    # --- user .ssh: owner-only ACL, config template
    $ssh = Join-Path $env:USERPROFILE '.ssh'
    New-Item $ssh -ItemType Directory -Force | Out-Null
    $cfgUser = Join-Path $ssh 'config'
    $cfgText = if (Test-Path $cfgUser) { Get-Content $cfgUser -Raw } else { '' }
    $cfgText = [regex]::Replace($cfgText, '(?s)# >>> x47-ops x47 >>>.*?# <<< x47-ops x47 <<<\r?\n?', '')
    $x47Block = @"
# >>> x47-ops x47 >>>
# Ubuntu X47 box on the LAN (file transfer: scp/sftp/WinSCP)
Host x47
    HostName $UbuntuIp
    User $UbuntuUser
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
# <<< x47-ops x47 <<<
"@
    Set-Content $cfgUser -Value ($cfgText.TrimEnd() + "`r`n`r`n" + $x47Block + "`r`n") -Encoding ASCII
    icacls $ssh /inheritance:r /grant "${env:USERNAME}:(OI)(CI)F" /grant 'SYSTEM:(OI)(CI)F' /grant 'Administrators:(OI)(CI)F' | Out-Null
    if (-not (Test-Path (Join-Path $ssh 'id_ed25519'))) {
        ssh-keygen -t ed25519 -N '""' -C "$env:USERNAME@$env:COMPUTERNAME" -f (Join-Path $ssh 'id_ed25519') | Out-Null
        X47-Log 'generated ~/.ssh/id_ed25519 (no passphrase; add one with ssh-keygen -p)' 'WARN'
    }

    Restart-Service sshd
    & "$env:windir\System32\OpenSSH\sshd.exe" -t
    if ($LASTEXITCODE -ne 0) { throw 'sshd -t reported a config error' }
    X47-Log "sshd running. From Ubuntu: ssh $env:USERNAME@<this-pc-ip>" 'OK'
    Write-Host "This PC's public key (add to Ubuntu ~/.ssh/authorized_keys):" -ForegroundColor Cyan
    Get-Content (Join-Path $ssh 'id_ed25519.pub')
} finally {
    Ops-StopTranscript $OpsTranscript
}
