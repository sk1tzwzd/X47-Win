# Create/repair C:\Users\<you>\Vault: one easy place for keys and server details. Idempotent, no admin.
#   ssh\ -> ~\.ssh   aws\ -> ~\.aws   (junctions, so ssh/aws keep using their normal paths)
#   servers\         server notes, compose files, .env files
# Gives the folder the vault icon and adds a "Vault" Start menu shortcut (right-click it > Pin to taskbar).
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')

$H = $env:USERPROFILE; $me = $env:USERNAME
$vault = Join-Path $H 'Vault'
$ssh = Join-Path $H '.ssh'; $aws = Join-Path $H '.aws'

function Lock-Dir([string]$Path) {
    # owner-only: OpenSSH refuses keys others can read
    icacls $Path /inheritance:r /grant:r "${me}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' | Out-Null
    Get-ChildItem $Path -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object { icacls $_.FullName /reset | Out-Null }
}

foreach ($d in $vault, $ssh, $aws, (Join-Path $vault 'servers')) { New-Item -ItemType Directory -Force $d | Out-Null }
foreach ($pair in @(@('ssh', $ssh), @('aws', $aws))) {
    $link = Join-Path $vault $pair[0]
    if (-not (Test-Path $link)) { New-Item -ItemType Junction -Path $link -Target $pair[1] | Out-Null }
}

# Host list comes from ~/.ssh/config at run time, so no server details live in the repo.
$hosts = ''
$cfg = Join-Path $ssh 'config'
if (Test-Path $cfg) {
    $hosts = (Select-String -Path $cfg -Pattern '^\s*Host\s+(.+)$' | ForEach-Object {
            '              ssh ' + $_.Matches[0].Groups[1].Value.Split()[0]
        }) -join "`r`n"
}
@"
X47 Vault - keys and server details (only your account can open this)

ssh\      = C:\Users\$me\.ssh   keys + config (ssh reads them from there)
$hosts
aws\      = C:\Users\$me\.aws   AWS CLI config + credentials
servers\  server notes, compose files, .env files

Never committed to git. Back this folder up only to encrypted storage.
"@ | Set-Content (Join-Path $vault 'README.txt') -Encoding UTF8

foreach ($p in $vault, $ssh, $aws) { Lock-Dir $p }

# --- icon: stable copy outside the repo, folder icon via desktop.ini, Start menu shortcut
$iconDir = Join-Path $env:LOCALAPPDATA 'X47'
New-Item -ItemType Directory -Force $iconDir | Out-Null
$ico = Join-Path $iconDir 'vault.ico'
Copy-Item (Join-Path $PSScriptRoot 'assets\vault.ico') $ico -Force

$ini = Join-Path $vault 'desktop.ini'
if (Test-Path $ini) { attrib -s -h $ini }
"[.ShellClassInfo]`r`nIconResource=$ico,0`r`nInfoTip=Keys and server details`r`n" | Set-Content $ini -Encoding Unicode
attrib +s +h $ini
attrib +r $vault   # tells Explorer to read desktop.ini

$lnkPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Vault.lnk'
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = "$env:windir\explorer.exe"
$lnk.Arguments = "`"$vault`""
$lnk.IconLocation = "$ico,0"
$lnk.Description = 'Keys and server details'
$lnk.Save()

# Quick Access pin (taskbar pinning can't be scripted on Windows 11)
try {
    $qa = (New-Object -ComObject Shell.Application).Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}').Items() | Where-Object { $_.Path -eq $vault }
    if (-not $qa) { (New-Object -ComObject Shell.Application).Namespace($vault).Self.InvokeVerb('pintohome') }
} catch {}
ie4uinit.exe -show   # refresh icon cache

X47-Log "vault ready at $vault (Start menu: Vault; Quick Access pinned)" 'OK'
