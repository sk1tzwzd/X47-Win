# Gaming Mode: one-click toggle. No admin needed.
#   ON : High performance power plan, Windows Game Mode on, notifications silenced,
#        Mullvad disconnected (lockdown lifted if set), WSL shut down to free RAM.
#   OFF: puts every one of those back exactly as it was before ON.
#   .\tools\gaming-mode.ps1 -Install   # copy to %LOCALAPPDATA%\X47 + Start menu/Desktop "Gaming Mode" button
#   .\tools\gaming-mode.ps1 [-On|-Off] # toggle (default) or force a state
[CmdletBinding()]
param([switch]$On, [switch]$Off, [switch]$Install, [switch]$Quiet)

$x47Dir = Join-Path $env:LOCALAPPDATA 'X47'
$stateFile = Join-Path $x47Dir 'gaming-mode.json'
$mullvad = "$env:ProgramFiles\Mullvad VPN\resources\mullvad.exe"
$highPerf = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$lnkName = 'Gaming Mode.lnk'
$lnkPlaces = @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [Environment]::GetFolderPath('Desktop'),
    (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
)

function Set-ButtonIcon([bool]$IsOn) {
    $ico = Join-Path $x47Dir ($(if ($IsOn) { 'gaming-on.ico' } else { 'gaming-off.ico' }))
    $ws = New-Object -ComObject WScript.Shell
    foreach ($dir in $lnkPlaces) {
        $p = Join-Path $dir $lnkName
        if (Test-Path $p) { $l = $ws.CreateShortcut($p); $l.IconLocation = "$ico,0"; $l.Description = "Gaming Mode is $(if ($IsOn) { 'ON' } else { 'OFF' }) - click to toggle"; $l.Save() }
    }
    ie4uinit.exe -show
}

function Get-RegValue($Path, $Name) { try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { $null } }
function Set-RegValue($Path, $Name, $Value) {
    if ($null -eq $Value) { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue; return }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}
function Show-Note([string]$Text) {
    if ($Quiet) { Write-Host $Text; return }
    (New-Object -ComObject WScript.Shell).Popup($Text, 3, 'Gaming Mode', 64) | Out-Null
}

if ($Install) {
    New-Item -ItemType Directory -Force $x47Dir | Out-Null
    Copy-Item $PSCommandPath (Join-Path $x47Dir 'gaming-mode.ps1') -Force
    foreach ($i in 'gaming-on.ico', 'gaming-off.ico') { Copy-Item (Join-Path $PSScriptRoot "assets\$i") (Join-Path $x47Dir $i) -Force }
    $ws = New-Object -ComObject WScript.Shell
    foreach ($dir in $lnkPlaces[0..1]) {
        $l = $ws.CreateShortcut((Join-Path $dir $lnkName))
        $l.TargetPath = "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
        $l.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$x47Dir\gaming-mode.ps1`""
        $l.WindowStyle = 7
        $l.Save()
    }
    Set-ButtonIcon (Test-Path $stateFile)
    Write-Host "Gaming Mode button installed (Start menu + Desktop). Right-click it > Pin to taskbar."
    return
}

$isOn = Test-Path $stateFile
$target = if ($On) { $true } elseif ($Off) { $false } else { -not $isOn }
if ($target -eq $isOn) { Show-Note "Gaming Mode is already $(if ($isOn) { 'ON' } else { 'OFF' })."; return }

$gb = 'HKCU:\Software\Microsoft\GameBar'
$pn = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'

if ($target) {
    # ---------- ON: record the current state first
    $scheme = ((powercfg /getactivescheme) -replace '.*GUID:\s*([0-9a-f-]+).*', '$1').Trim()
    $mvStatus = if (Test-Path $mullvad) { (& $mullvad status | Select-Object -First 1) } else { '' }
    $mvLock = if (Test-Path $mullvad) { (& $mullvad lockdown-mode get) -match ': on' } else { $false }
    $state = [ordered]@{
        since          = (Get-Date).ToString('s')
        powerScheme    = $scheme
        autoGameMode   = Get-RegValue $gb 'AutoGameModeEnabled'
        allowGameMode  = Get-RegValue $gb 'AllowAutoGameMode'
        toastEnabled   = Get-RegValue $pn 'ToastEnabled'
        mullvadWasUp   = [bool]($mvStatus -match '^(Connected|Connecting)')
        mullvadLocked  = [bool]$mvLock
    }
    New-Item -ItemType Directory -Force $x47Dir | Out-Null
    $state | ConvertTo-Json | Set-Content $stateFile -Encoding UTF8

    powercfg /setactive $highPerf
    Set-RegValue $gb 'AutoGameModeEnabled' 1
    Set-RegValue $gb 'AllowAutoGameMode' 1
    Set-RegValue $pn 'ToastEnabled' 0
    if (Test-Path $mullvad) {
        if ($state.mullvadLocked) { & $mullvad lockdown-mode set off | Out-Null }
        if ($state.mullvadWasUp) { & $mullvad disconnect | Out-Null }
    }
    if ((Get-Service WSLService -ErrorAction SilentlyContinue) -and (wsl.exe --list --running --quiet 2>$null)) { wsl.exe --shutdown 2>$null }

    Set-ButtonIcon $true
    $plug = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1).PowerOnline
    $tip = if ($plug -eq $false) { "`n`nOn battery: plug in for full GPU power." } else { '' }
    Show-Note "Gaming Mode ON`n`nHigh performance, Game Mode on, notifications muted, VPN paused, WSL stopped.$tip"
}
else {
    # ---------- OFF: restore what was recorded
    $s = Get-Content $stateFile -Raw | ConvertFrom-Json
    if ($s.powerScheme) { powercfg /setactive $s.powerScheme }
    Set-RegValue $gb 'AutoGameModeEnabled' $s.autoGameMode
    Set-RegValue $gb 'AllowAutoGameMode' $s.allowGameMode
    Set-RegValue $pn 'ToastEnabled' $s.toastEnabled
    if (Test-Path $mullvad) {
        if ($s.mullvadWasUp) { & $mullvad connect | Out-Null }
        if ($s.mullvadLocked) { & $mullvad lockdown-mode set on | Out-Null }
    }
    Remove-Item $stateFile -Force
    Set-ButtonIcon $false
    $vpn = if ($s.mullvadWasUp) { 'VPN reconnected, ' } else { '' }
    Show-Note "Gaming Mode OFF`n`nPower plan, notifications and ${vpn}settings restored."
}
