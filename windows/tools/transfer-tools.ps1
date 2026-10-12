# Easy LAN file transfer with the Ubuntu X47 box, all over the key-only SSH set up by ssh-transfer.ps1.
#   - WinSCP: two-pane drag-and-drop, saved session "Ubuntu X47"
#   - Explorer right-click > Send to > Ubuntu X47   (lands in ~/FromWindows)
#   - C:\Users\<you>\FromUbuntu: drop target for the Ubuntu side
# No admin needed except the WinSCP install (winget shows its own prompt).
[CmdletBinding()]
param([Parameter(Mandatory)][string]$UbuntuIp, [Parameter(Mandatory)][string]$UbuntuUser)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')

Ops-Winget -Id 'WinSCP.WinSCP' | Out-Null

# Inbox for files coming from Ubuntu
$inbox = Join-Path $env:USERPROFILE 'FromUbuntu'
New-Item -ItemType Directory -Force $inbox | Out-Null

# WinSCP saved session (registry storage). Points at the OpenSSH key; on first connect WinSCP offers to
# convert it (asks for the passphrase) - save the .ppk next to it, then re-run this script to switch to it.
$sess = 'HKCU:\Software\Martin Prikryl\WinSCP 2\Sessions\Ubuntu%20X47'
New-Item -Path $sess -Force | Out-Null
$vals = @{
    HostName = $UbuntuIp; UserName = $UbuntuUser; PortNumber = 22; FSProtocol = 2
    PublicKeyFile = $($ppk = Join-Path $env:USERPROFILE '.ssh\id_ed25519.ppk'; if (Test-Path $ppk) { $ppk } else { Join-Path $env:USERPROFILE '.ssh\id_ed25519' })
    LocalDirectory = $inbox; RemoteDirectory = "/home/$UbuntuUser"
}
foreach ($k in $vals.Keys) {
    $type = if ($vals[$k] -is [int]) { 'DWord' } else { 'String' }
    New-ItemProperty -Path $sess -Name $k -Value $vals[$k] -PropertyType $type -Force | Out-Null
}
X47-Log 'WinSCP session "Ubuntu X47" saved' 'OK'

# Send to menu entry (stable copy of the sender outside the repo)
$x47Dir = Join-Path $env:LOCALAPPDATA 'X47'
New-Item -ItemType Directory -Force $x47Dir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'send-to-x47.ps1') (Join-Path $x47Dir 'send-to-x47.ps1') -Force
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $env:APPDATA 'Microsoft\Windows\SendTo\Ubuntu X47.lnk'))
$lnk.TargetPath = "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
$lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$x47Dir\send-to-x47.ps1`""
$lnk.IconLocation = "$env:windir\System32\imageres.dll,-1023"
$lnk.Save()
X47-Log 'Send to > Ubuntu X47 added' 'OK'

# Quick Access pin for the inbox
try {
    $sh = New-Object -ComObject Shell.Application
    $pinned = $sh.Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}').Items() | Where-Object { $_.Path -eq $inbox }
    if (-not $pinned) { $sh.Namespace($inbox).Self.InvokeVerb('pintohome') }   # verb toggles, so only when not pinned
} catch {}
X47-Log "inbox $inbox pinned" 'OK'
