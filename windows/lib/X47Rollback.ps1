# Snapshot + rollback for the X47-Win kit.
# Does not format the disk, delete user documents, or turn BitLocker off.

function X47-SnapshotDir {
    if (-not $script:X47Root) { $script:X47Root = 'C:\X47' }
    return (Join-Path $script:X47Root 'rollback')
}

function X47-EnsureSnapshotDir {
    $dir = X47-SnapshotDir
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function X47-WriteJson {
    param([string]$Name, $Object)
    $dir = X47-EnsureSnapshotDir
    $Object | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $dir $Name) -Encoding UTF8
}

function X47-ReadJson {
    param([string]$Name)
    $path = Join-Path (X47-SnapshotDir) $Name
    if (-not (Test-Path $path)) { return $null }
    return (Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function X47-AppendJsonList {
    param([string]$Name, $Item)
    $list = @()
    $existing = X47-ReadJson $Name
    if ($existing) { $list = @($existing) }
    $list += $Item
    X47-WriteJson $Name $list
}

function X47-JournalReg {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Action = 'set'
    )
    if (-not $script:X47SnapshotActive) { return }
    $existed = $false
    $oldValue = $null
    $oldKind = $null
    if (Test-Path $Path) {
        $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
        if ($item -and ($item.GetValueNames() -contains $Name)) {
            $existed = $true
            $oldValue = $item.GetValue($Name)
            $oldKind = [string]$item.GetValueKind($Name)
        }
    }
    X47-AppendJsonList 'journal-reg.json' @{
        Path     = $Path
        Name     = $Name
        Action   = $Action
        Existed  = $existed
        OldValue = $oldValue
        OldKind  = $oldKind
        When     = (Get-Date -Format o)
    }
}

function X47-JournalService {
    param([string]$Name)
    if (-not $script:X47SnapshotActive) { return }
    $already = X47-ReadJson 'journal-services.json'
    if ($already | Where-Object { $_.Name -eq $Name }) { return }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    X47-AppendJsonList 'journal-services.json' @{
        Name      = $Name
        StartType = [string]$svc.StartType
        Status    = [string]$svc.Status
        When      = (Get-Date -Format o)
    }
}

function X47-JournalTask {
    param([string]$TaskPath, [string]$TaskName)
    if (-not $script:X47SnapshotActive) { return }
    $already = X47-ReadJson 'journal-tasks.json'
    if ($already | Where-Object { $_.TaskPath -eq $TaskPath -and $_.TaskName -eq $TaskName }) { return }
    try {
        $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
        X47-AppendJsonList 'journal-tasks.json' @{
            TaskPath = $TaskPath
            TaskName = $TaskName
            State    = [string]$t.State
            When     = (Get-Date -Format o)
        }
    } catch {}
}

function X47-IsVirtualAdapter {
    param($Adapter)
    $blob = '{0} {1}' -f $Adapter.Name, $Adapter.InterfaceDescription
    return $blob -match 'Hyper-V|vEthernet|Virtual|TAP-Windows|Wintun|WireGuard|Mullvad|VPN|Bluetooth|WAN Miniport|Loopback|Npcap'
}

function X47-GetPhysicalNics {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
        -not (X47-IsVirtualAdapter $_)
    }
}

function X47-SnapshotMacs {
    $rows = @()
    foreach ($if in @(X47-GetPhysicalNics)) {
        $na = $null
        try {
            $prop = Get-NetAdapterAdvancedProperty -Name $if.Name -DisplayName 'Network Address' -ErrorAction SilentlyContinue
            if ($prop) { $na = [string]$prop.DisplayValue }
        } catch {}
        $rows += @{
            Name              = $if.Name
            MacAddress        = [string]$if.MacAddress
            PermanentAddress  = [string]$if.PermanentAddress
            NetworkAddress    = $na
        }
    }
    X47-WriteJson 'macs.json' $rows
}

function X47-NewLocalMacHex {
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $b = New-Object byte[] 6
    $rng.GetBytes($b)
    $b[0] = [byte](($b[0] -band 0xFE) -bor 0x02)
    return -join ($b | ForEach-Object { $_.ToString('X2') })
}

function X47-RandomizePhysicalMacs {
    foreach ($if in @(X47-GetPhysicalNics)) {
        $hex = X47-NewLocalMacHex
        try {
            Set-NetAdapterAdvancedProperty -Name $if.Name -DisplayName 'Network Address' -DisplayValue $hex -ErrorAction Stop
            X47-Log ("MAC {0} → {1} (software override)" -f $if.Name, $hex) 'OK'
        } catch {
            try {
                Set-NetAdapter -Name $if.Name -MacAddress $hex -Confirm:$false -ErrorAction Stop
                X47-Log ("MAC {0} → {1}" -f $if.Name, $hex) 'OK'
            } catch {
                X47-Log ("MAC {0}: {1}" -f $if.Name, $_.Exception.Message) 'WARN'
            }
        }
    }
    netsh wlan set randomization enabled=yes 2>$null | Out-Null
}

function X47-RestoreMacs {
    $rows = X47-ReadJson 'macs.json'
    foreach ($row in @($rows)) {
        if (-not $row -or -not $row.Name) { continue }
        try {
            if ($row.NetworkAddress -and $row.NetworkAddress -notmatch 'Not Present|NotPresent|Absent|^$') {
                Set-NetAdapterAdvancedProperty -Name $row.Name -DisplayName 'Network Address' -DisplayValue $row.NetworkAddress -ErrorAction Stop
            } else {
                Reset-NetAdapterAdvancedProperty -Name $row.Name -DisplayName 'Network Address' -ErrorAction SilentlyContinue
            }
            X47-Log "MAC $($row.Name) restored to factory override" 'OK'
        } catch {
            X47-Log "MAC restore $($row.Name): $($_.Exception.Message)" 'WARN'
        }
    }
}

function X47-CreateRestorePoint {
    param([string]$Description = 'X47-Win before install')
    $info = @{
        Attempted = $true
        Created   = $false
        Detail    = ''
    }
    try {
        foreach ($svc in @('VSS', 'swprv', 'SDRSVC')) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.StartType -eq 'Disabled') {
                Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
            }
            if ($s -and $s.Status -ne 'Running') {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
            }
        }
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
        $sr = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        if (-not (Test-Path $sr)) { New-Item -Path $sr -Force | Out-Null }
        New-ItemProperty -Path $sr -Name SystemRestorePointCreationFrequency -Value 0 -PropertyType DWord -Force | Out-Null
    } catch {}

    try {
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS
        $info.Created = $true
        $info.Detail = 'Checkpoint-Computer'
    } catch {
        try {
            $cls = [wmiclass]'\\.\root\default:SystemRestore'
            $res = $cls.CreateRestorePoint($Description, 12, 100)
            if ($res.ReturnValue -eq 0) {
                $info.Created = $true
                $info.Detail = 'WMI SystemRestore'
            } else {
                $info.Detail = "WMI return $($res.ReturnValue)"
            }
        } catch {
            $info.Detail = $_.Exception.Message
        }
    }
    return $info
}

function X47-BeginSnapshot {
    param(
        [string]$KitRoot,
        [switch]$AllowWithoutRestorePoint
    )
    if ($KitRoot) { $script:X47Root = $KitRoot }
    $dir = X47-EnsureSnapshotDir

    if (Test-Path (Join-Path $dir 'created.txt')) {
        $archive = Join-Path $script:X47Root ("rollback-archive-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
        Copy-Item -Path $dir -Destination $archive -Recurse -Force
        X47-Log "previous snapshot copied to $archive"
        Remove-Item -Path (Join-Path $dir 'journal-reg.json') -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $dir 'journal-services.json') -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $dir 'journal-tasks.json') -Force -ErrorAction SilentlyContinue
    }

    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    if (Test-Path $hostsPath) {
        Copy-Item $hostsPath (Join-Path $dir 'hosts.bak') -Force
    }

    $fw = @()
    try {
        Get-NetFirewallProfile -ErrorAction Stop | ForEach-Object {
            $fw += @{
                Name                  = [string]$_.Name
                DefaultInboundAction  = [string]$_.DefaultInboundAction
                DefaultOutboundAction = [string]$_.DefaultOutboundAction
            }
        }
    } catch {}
    X47-WriteJson 'firewall.json' $fw

    $ntp = @{
        NtpServer = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Name NtpServer -ErrorAction SilentlyContinue).NtpServer
        Type      = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Name Type -ErrorAction SilentlyContinue).Type
    }
    X47-WriteJson 'ntp.json' $ntp

    $wp = @{
        Wallpaper      = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
        WallpaperStyle = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -ErrorAction SilentlyContinue).WallpaperStyle
        TileWallpaper  = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -ErrorAction SilentlyContinue).TileWallpaper
    }
    X47-WriteJson 'wallpaper.json' $wp
    if ($wp.Wallpaper -and (Test-Path $wp.Wallpaper)) {
        Copy-Item $wp.Wallpaper (Join-Path $dir 'wallpaper-original') -Force -ErrorAction SilentlyContinue
    }

    $od = Test-Path (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe')
    X47-WriteJson 'onedrive.json' @{ Installed = [bool]$od }

    $smbv1 = 'Disabled'
    try {
        $feat = Get-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction SilentlyContinue
        if ($feat) { $smbv1 = [string]$feat.State }
    } catch {}
    X47-WriteJson 'smbv1.json' @{ State = $smbv1 }

    $openShell = @(
        "${env:ProgramFiles}\Open-Shell\StartMenu.exe"
        "${env:ProgramFiles(x86)}\Open-Shell\StartMenu.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    $ep = (Test-Path 'HKLM:\SOFTWARE\ExplorerPatcher') -or (Get-ItemProperty 'HKCU:\Software\ExplorerPatcher' -ErrorAction SilentlyContinue)
    X47-WriteJson 'themes.json' @{
        OpenShellPresent       = [bool]$openShell
        ExplorerPatcherPresent = [bool]$ep
    }

    X47-SnapshotMacs

    try {
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Name -Unique |
            Sort-Object |
            Set-Content (Join-Path $dir 'appx-before.txt') -Encoding UTF8
    } catch {}

    $rp = X47-CreateRestorePoint
    X47-WriteJson 'restore-point.json' $rp

    @"
X47-Win snapshot
Created: $(Get-Date -Format o)
Host: $env:COMPUTERNAME
User: $env:USERNAME
Restore point: $($rp.Created) ($($rp.Detail))

Undo the kit (does not delete Documents / Pictures / Desktop):
  $(Join-Path $script:X47Root 'Rollback-X47Windows.bat')

If registry rollback is not enough, use Windows System Restore
and pick the point named "X47-Win before install".
BitLocker is never turned off by rollback.
"@ | Set-Content (Join-Path $dir 'README.txt') -Encoding UTF8

    Get-Date -Format o | Set-Content (Join-Path $dir 'created.txt') -Encoding UTF8
    $script:X47SnapshotActive = $true

    if (-not $rp.Created) {
        X47-Log "Windows restore point was not created: $($rp.Detail)" 'WARN'
        if (-not $AllowWithoutRestorePoint) {
            Write-Host ''
            Write-Host 'A Windows System Restore point could not be created.' -ForegroundColor Yellow
            Write-Host "The kit will still write $dir (registry, hosts, services)." -ForegroundColor Yellow
            Write-Host 'That undoes policy changes. Uninstalled Store apps are easier to get' -ForegroundColor Yellow
            Write-Host 'back if System Restore is working.' -ForegroundColor Yellow
            Write-Host ''
            try {
                $ans = Read-Host 'Type YES to continue without a restore point (or anything else to abort)'
            } catch {
                $ans = 'YES'
            }
            if ($ans -ne 'YES') {
                throw 'aborted: no restore point and user declined to continue'
            }
        } else {
            X47-Log "continuing with registry/file rollback snapshot at $dir" 'WARN'
        }
    } else {
        X47-Log 'Windows restore point created (X47-Win before install)' 'OK'
    }
    X47-Log "snapshot → $dir" 'OK'
    return $dir
}

function X47-ApplyWallpaperPath {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path)) { return }
    if (-not ([System.Management.Automation.PSTypeName]'X47Wallpaper').Type) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class X47Wallpaper {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
    }
    [void][X47Wallpaper]::SystemParametersInfo(0x0014, 0, $Path, 0x03)
}

function X47-RestoreRegistryJournal {
    $list = X47-ReadJson 'journal-reg.json'
    if (-not $list) { return 0 }
    $n = 0
    foreach ($row in ([array]$list | Sort-Object When -Descending)) {
        try {
            if ($row.Existed) {
                $kind = [Microsoft.Win32.RegistryValueKind]::DWord
                if ($row.OldKind) {
                    $kind = [Microsoft.Win32.RegistryValueKind]$row.OldKind
                }
                if (-not (Test-Path $row.Path)) { New-Item -Path $row.Path -Force | Out-Null }
                New-ItemProperty -Path $row.Path -Name $row.Name -Value $row.OldValue -PropertyType $kind -Force | Out-Null
            } else {
                if (Test-Path $row.Path) {
                    Remove-ItemProperty -Path $row.Path -Name $row.Name -Force -ErrorAction SilentlyContinue
                }
            }
            $n++
        } catch {
            X47-Log "reg restore $($row.Path)\$($row.Name): $($_.Exception.Message)" 'WARN'
        }
    }
    return $n
}

function X47-RestoreKit {
    param([string]$KitRoot)
    if ($KitRoot) { $script:X47Root = $KitRoot }
    $dir = X47-SnapshotDir
    if (-not (Test-Path (Join-Path $dir 'created.txt'))) {
        throw "No snapshot at $dir — nothing to roll back. Run the installer first."
    }
    X47-Log "restoring snapshot from $dir"

    $hostsBak = Join-Path $dir 'hosts.bak'
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    if (Test-Path $hostsBak) {
        Copy-Item $hostsBak $hostsPath -Force
        X47-Log 'hosts restored' 'OK'
    }
    Get-NetFirewallRule -Group 'X47-Anon' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

    $regN = X47-RestoreRegistryJournal
    X47-Log "registry values restored: $regN" 'OK'

    $svcs = X47-ReadJson 'journal-services.json'
    foreach ($row in @($svcs)) {
        if (-not $row) { continue }
        try {
            Set-Service -Name $row.Name -StartupType $row.StartType -ErrorAction Stop
            if ($row.Status -eq 'Running') {
                Start-Service -Name $row.Name -ErrorAction SilentlyContinue
            }
            X47-Log "service $($row.Name) → $($row.StartType)" 'OK'
        } catch {
            X47-Log "service $($row.Name): $($_.Exception.Message)" 'WARN'
        }
    }

    $tasks = X47-ReadJson 'journal-tasks.json'
    foreach ($row in @($tasks)) {
        if (-not $row) { continue }
        try {
            Enable-ScheduledTask -TaskPath $row.TaskPath -TaskName $row.TaskName -ErrorAction Stop | Out-Null
            X47-Log "task $($row.TaskName) enabled" 'OK'
        } catch {
            X47-Log "task $($row.TaskName): $($_.Exception.Message)" 'WARN'
        }
    }

    $fw = X47-ReadJson 'firewall.json'
    foreach ($row in @($fw)) {
        if (-not $row) { continue }
        try {
            Set-NetFirewallProfile -Profile $row.Name -DefaultInboundAction $row.DefaultInboundAction -DefaultOutboundAction $row.DefaultOutboundAction -ErrorAction Stop
        } catch {
            X47-Log "firewall $($row.Name): $($_.Exception.Message)" 'WARN'
        }
    }

    X47-RestoreMacs

    $ntp = X47-ReadJson 'ntp.json'
    if ($ntp -and $ntp.NtpServer) {
        try {
            w32tm /config /syncfromflags:manual /manualpeerlist:"$($ntp.NtpServer)" /update | Out-Null
            Restart-Service w32time -ErrorAction SilentlyContinue
            X47-Log "NTP restored → $($ntp.NtpServer)" 'OK'
        } catch {}
    }

    $wp = X47-ReadJson 'wallpaper.json'
    $wpFile = $null
    if ($wp -and $wp.Wallpaper -and (Test-Path $wp.Wallpaper)) { $wpFile = $wp.Wallpaper }
    elseif (Test-Path (Join-Path $dir 'wallpaper-original')) { $wpFile = Join-Path $dir 'wallpaper-original' }
    if ($wpFile) { X47-ApplyWallpaperPath $wpFile; X47-Log "wallpaper restored → $wpFile" 'OK' }

    $od = X47-ReadJson 'onedrive.json'
    if ($od -and $od.Installed) {
        $setup = @(
            "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
            "$env:SystemRoot\System32\OneDriveSetup.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($setup) {
            Start-Process -FilePath $setup -ErrorAction SilentlyContinue
            X47-Log 'OneDrive setup launched' 'OK'
        }
    }

    $smbv1 = X47-ReadJson 'smbv1.json'
    if ($smbv1 -and $smbv1.State -eq 'Enabled') {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -NoRestart -ErrorAction SilentlyContinue | Out-Null
            X47-Log 'SMBv1 re-enabled (was on before the kit)' 'OK'
        } catch {}
    }

    $th = X47-ReadJson 'themes.json'
    if ($th -and -not $th.OpenShellPresent) {
        $msi = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue } |
            Where-Object { $_.DisplayName -match 'Open-Shell|OpenShell' } |
            Select-Object -First 1
        if ($msi -and $msi.UninstallString) {
            try {
                Start-Process -FilePath 'msiexec.exe' -ArgumentList '/x', $msi.PSChildName, '/qn' -Wait -ErrorAction SilentlyContinue
                X47-Log 'Open-Shell uninstalled (it was not present before)' 'OK'
            } catch {}
        }
    }
    if ($th -and -not $th.ExplorerPatcherPresent) {
        $ep = Join-Path $env:WINDIR 'ep_setup.exe'
        if (-not (Test-Path $ep)) { $ep = Join-Path $env:TEMP 'ep_setup.exe' }
        if (Test-Path $ep) {
            try {
                Start-Process -FilePath $ep -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
                X47-Log 'ExplorerPatcher uninstalled (it was not present before)' 'OK'
            } catch {}
        }
    }

    X47-Log 'kit rollback finished' 'OK'
    Write-Host ''
    Write-Host 'Rolled back registry, hosts, services, firewall, wallpaper, and NTP.' -ForegroundColor Green
    Write-Host 'Documents, Pictures, and Desktop were not touched.' -ForegroundColor Green
    Write-Host 'Store apps the kit removed can come back via Microsoft Store,' -ForegroundColor Yellow
    Write-Host 'or use System Restore → "X47-Win before install" for a fuller undo.' -ForegroundColor Yellow
    Write-Host 'BitLocker was not changed.' -ForegroundColor Green
    Write-Host ''
    $rp = X47-ReadJson 'restore-point.json'
    if ($rp -and $rp.Created) {
        Write-Host 'Opening System Restore so you can pick that point if you want it…'
        Start-Process rstrui.exe -ErrorAction SilentlyContinue
    }
}
