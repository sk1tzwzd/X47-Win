# Private automatic time zone: picks the zone from the Wi-Fi network you're on, with no location services.
# Known networks live in %LOCALAPPDATA%\X47\tz-networks.json (never in the kit). Unknown networks: no change.
# Network names match exactly first, then by prefix ("Home" covers "Home_5G" and "Home_2G").
#   .\tools\timezone-auto.ps1 -Install                       # task: runs at logon + whenever a network connects
#   .\tools\timezone-auto.ps1 -Add 'GMT Standard Time'       # remember the network you're on now
#   .\tools\timezone-auto.ps1 -Add 'SE Asia Standard Time' -Network 'Home'   # or name it (prefix)
#   .\tools\timezone-auto.ps1 -List
#   .\tools\timezone-auto.ps1                                # apply now (what the task runs)
# Time zone ids: Get-TimeZone -ListAvailable | Select Id, DisplayName
[CmdletBinding()]
param([switch]$Install, [string]$Add, [string]$Network, [switch]$List)

$x47Dir = Join-Path $env:LOCALAPPDATA 'X47'
$map = Join-Path $x47Dir 'tz-networks.json'
$log = Join-Path $x47Dir 'timezone-auto.log'
New-Item -ItemType Directory -Force $x47Dir | Out-Null
if (-not (Test-Path $map)) { '{}' | Set-Content $map -Encoding UTF8 }

function Get-Networks {
    # Profile names = SSIDs for Wi-Fi, readable without location access; skip VPN/virtual adapters.
    Get-NetConnectionProfile -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -notmatch 'Mullvad|WireGuard|OpenVPN|TAP|vEthernet|Loopback' } |
        Select-Object -ExpandProperty Name
}
function Read-Map { $h = @{}; (Get-Content $map -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }; $h }

if ($List) { Get-Content $map; "current network(s): $((Get-Networks) -join ', ')"; "time zone: $((Get-TimeZone).Id)"; return }

if ($Add) {
    try { [void](Get-TimeZone -Id $Add -ErrorAction Stop) } catch { Write-Host "Unknown time zone id '$Add'. See: Get-TimeZone -ListAvailable"; exit 1 }
    $net = if ($Network) { $Network } else { @(Get-Networks)[0] }
    if (-not $net) { Write-Host 'Not connected to a network; pass -Network <name>.'; exit 1 }
    $h = Read-Map; $h[$net] = $Add
    $h | ConvertTo-Json | Set-Content $map -Encoding UTF8
    Write-Host "Remembered '$net' -> $Add"
}

if ($Install) {
    $self = Join-Path $x47Dir 'timezone-auto.ps1'
    Copy-Item $PSCommandPath $self -Force
    $taskArgs = "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$self`""
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>X47: set time zone from the connected Wi-Fi network</Description></RegistrationInfo>
  <Triggers>
    <LogonTrigger><UserId>$user</UserId></LogonTrigger>
    <EventTrigger>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[EventID=10000]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
      <Delay>PT10S</Delay>
    </EventTrigger>
  </Triggers>
  <Principals><Principal id="Author"><UserId>$user</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author"><Exec><Command>conhost.exe</Command><Arguments>$([Security.SecurityElement]::Escape($taskArgs))</Arguments></Exec></Actions>
</Task>
"@
    $tmp = Join-Path $env:TEMP 'x47-tz-task.xml'
    $xml | Set-Content $tmp -Encoding Unicode
    schtasks.exe /Create /TN 'X47\TimeZoneAuto' /XML $tmp /F | Out-Null
    Remove-Item $tmp -Force
    Write-Host 'Installed scheduled task X47\TimeZoneAuto (logon + network connect).'
}

# --- apply
$h = Read-Map
foreach ($net in Get-Networks) {
    $zone = $h[$net]
    if (-not $zone) { $k = $h.Keys | Where-Object { $net.StartsWith($_) } | Select-Object -First 1; if ($k) { $zone = $h[$k] } }
    if ($zone) {
        if ((Get-TimeZone).Id -ne $zone) {
            Set-TimeZone -Id $zone
            Add-Content $log ("{0:s} {1} -> {2}" -f (Get-Date), $net, $zone)
        }
        break
    }
}
