# Debian (WSL2) dev baseline. Idempotent, no admin (uses wsl -u root).
#   - apt packages for dev + transfer (rsync/ssh to the Ubuntu X47 box)
#   - copies %USERPROFILE%\.ssh into Debian ~/.ssh with 600 perms (drvfs perms are too open for ssh)
[CmdletBinding()]
param([string]$Distro = 'Debian')
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')

$pkgs = 'ca-certificates curl wget git rsync openssh-client build-essential python3 python3-venv python3-pip unzip zip jq htop nano less'
wsl.exe -d $Distro -u root -- bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq $pkgs >/dev/null && apt-get upgrade -y -qq >/dev/null"
if ($LASTEXITCODE -ne 0) { X47-Log "apt failed ($LASTEXITCODE)" 'WARN'; exit 1 }
X47-Log 'debian: packages installed + upgraded' 'OK'

$user = (wsl.exe -d $Distro -- whoami).Trim()
$win = '/mnt/c/Users/' + $env:USERNAME + '/.ssh'
$sync = 'mkdir -p ~/.ssh && cp -f ' + $win + '/* ~/.ssh/ 2>/dev/null; chmod 700 ~/.ssh; chmod 600 ~/.ssh/*; chmod 644 ~/.ssh/*.pub 2>/dev/null; true'
wsl.exe -d $Distro -- bash -c $sync
X47-Log "debian: ssh keys + config synced to /home/$user/.ssh (re-run after adding keys on Windows)" 'OK'
