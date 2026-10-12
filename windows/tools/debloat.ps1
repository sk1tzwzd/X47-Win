# Remove leftover bloat and switch off Start/lock-screen/Edge nags. Idempotent.
#   .\tools\debloat.ps1 -DryRun    # show what would go
#   .\tools\debloat.ps1            # do it (self-elevates)
[CmdletBinding()]
param([switch]$DryRun, [string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')

# Appx packages to remove for every user and de-provision. Kept on purpose:
# Store, Terminal, Notepad, Calculator, Paint, Photos, ScreenSketch, Defender, codecs.
$appx = @(
    'Clipchamp.Clipchamp'
    'Microsoft.OneDriveSync'
    'Microsoft.WidgetsPlatformRuntime'
    'MicrosoftWindows.Client.WebExperience'
    'MicrosoftCorporationII.MicrosoftFamily'
    'Microsoft.Copilot'
    'Microsoft.Windows.Ai.Copilot.Provider'
    'Microsoft.BingSearch'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.OutlookForWindows'
    'Microsoft.Todos'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.YourPhone'
    'MicrosoftWindows.CrossDevice'
    'Microsoft.Windows.DevHome'
    'MSTeams'
    'Microsoft.GamingApp'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.Xbox.TCUI'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.WindowsMaps'
    'MicrosoftCorporationII.QuickAssist'
)

$installed = if (Ops-IsAdmin) { @(Get-AppxPackage -AllUsers) } else { @(Get-AppxPackage) }
$targets = $installed | Where-Object { $appx -contains $_.Name -and -not $_.NonRemovable }
$copilot = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Copilot' -ErrorAction SilentlyContinue

if ($DryRun) {
    Write-Host 'Would remove Appx:' -ForegroundColor Cyan
    $targets | Select-Object -ExpandProperty Name -Unique | ForEach-Object { "  $_" }
    if ($copilot) { Write-Host "Would uninstall Win32: Copilot $($copilot.DisplayVersion)" -ForegroundColor Cyan }
    Write-Host 'Would set policies: Copilot off, Widgets off, consumer features off, Start/lock-screen suggestions off, Bing in Start off, Edge startup boost/background off.' -ForegroundColor Cyan
    exit 0
}

if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
$removed = @()
try {
    # --- Appx: installed copies (all users) then provisioned copies
    foreach ($p in $targets) {
        try {
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
            X47-Log "removed $($p.Name)" 'OK'; $removed += $p.Name
        } catch {
            try { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop; X47-Log "removed $($p.Name) (current user)" 'OK'; $removed += $p.Name }
            catch { X47-Log "could not remove $($p.Name): $($_.Exception.Message)" 'WARN' }
        }
    }
    Get-AppxProvisionedPackage -Online | Where-Object { $appx -contains $_.DisplayName } | ForEach-Object {
        try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null; X47-Log "deprovisioned $($_.DisplayName)" 'OK' }
        catch { X47-Log "could not deprovision $($_.DisplayName): $($_.Exception.Message)" 'WARN' }
    }

    # --- Copilot desktop app (Win32, ships with Edge)
    if ($copilot) {
        $exe = ($copilot.UninstallString -split '"')[1]
        if ($exe -and (Test-Path $exe)) {
            Start-Process $exe -ArgumentList '--uninstall --mscopilot --channel=stable --system-level --force-uninstall' -Wait
            X47-Log 'uninstalled Copilot (Win32)' 'OK'; $removed += 'Copilot (Win32)'
        }
    }

    # --- Policies (HKLM)
    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft'
    X47-SetReg "$pol\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1
    # Dsh key is ACL-protected on recent builds; only write if it isn't already 0.
    if ((Get-ItemProperty "$pol\Dsh" -ErrorAction SilentlyContinue).AllowNewsAndInterests -ne 0) {
        X47-SetReg "$pol\Dsh" 'AllowNewsAndInterests' 0
    }
    X47-SetReg "$pol\Windows\CloudContent" 'DisableWindowsConsumerFeatures' 1
    X47-SetReg "$pol\Windows\CloudContent" 'DisableConsumerAccountStateContent' 1
    X47-SetReg "$pol\Windows\CloudContent" 'DisableSoftLanding' 1
    X47-SetReg "$pol\Windows\OneDrive" 'DisableFileSyncNGSC' 1
    X47-SetReg "$pol\Edge" 'StartupBoostEnabled' 0
    X47-SetReg "$pol\Edge" 'BackgroundModeEnabled' 0
    X47-SetReg "$pol\Edge" 'HubsSidebarEnabled' 0
    X47-SetReg "$pol\Edge" 'CopilotCDPPageContext' 0
    X47-SetReg "$pol\Edge" 'ShowRecommendationsEnabled' 0
    X47-SetReg "$pol\Edge" 'PersonalizationReportingEnabled' 0

    # --- Per-user (HKCU of the elevated admin == this user)
    X47-SetReg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    X47-SetReg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    X47-SetReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($n in 'ContentDeliveryAllowed', 'FeatureManagementEnabled', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
        'RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled', 'SilentInstalledAppsEnabled', 'SoftLandingEnabled',
        'SystemPaneSuggestionsEnabled', 'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled',
        'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled', 'SubscribedContent-88000326Enabled') {
        X47-SetReg $cdm $n 0
    }
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    X47-SetReg $adv 'Start_IrisRecommendations' 0
    X47-SetReg $adv 'Start_AccountNotifications' 0
    X47-SetReg $adv 'ShowCopilotButton' 0
    X47-SetReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
    X47-SetReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0

    if ($removed) { $removed | Set-Content (Join-Path $script:OpsRepo 'logs\debloat-removed.txt') -Encoding UTF8 }
    X47-Log "debloat done; removed $($removed.Count) item(s). Sign out/in for Start + taskbar changes." 'OK'
} finally {
    Ops-StopTranscript $OpsTranscript
}
