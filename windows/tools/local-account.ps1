# Finish moving off a Microsoft account: set the name shown on the sign-in screen and Start menu, hide
# the email, block Microsoft accounts, and complete the anonymity module's MSA block if it was held back.
# Step 1 (manual, Windows has no supported CLI for it):
#   Settings > Accounts > Your info > "Sign in with a local account instead" > set a local password.
# Step 2: .\tools\local-account.ps1 -DisplayName 'Name'
[CmdletBinding()]
param([Parameter(Mandatory)][string]$DisplayName, [string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')

$me = Get-LocalUser -Name $env:USERNAME
if ($me.PrincipalSource -eq 'MicrosoftAccount') {
    Write-Host "'$($me.Name)' is still a Microsoft account. Do this first, then re-run:" -ForegroundColor Yellow
    Write-Host '  Settings > Accounts > Your info > "Sign in with a local account instead"'
    Write-Host '  (save your device encryption / BitLocker recovery key before you do)'
    Start-Process 'ms-settings:yourinfo'
    exit 2
}

if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
try {
    Set-LocalUser -Name $env:USERNAME -FullName $DisplayName -Description ''
    X47-Log "display name set to $DisplayName" 'OK'

    $sys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    X47-SetReg $sys 'NoConnectedUser' 3                 # block adding/switching to Microsoft accounts
    X47-SetReg $sys 'DontDisplayLockedUserId' 2         # lock screen: display name only
    X47-SetReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'BlockUserFromShowingAccountDetailsOnSignin' 1  # no email on sign-in

    $ids = 'HKCU:\Software\Microsoft\IdentityCRL\UserExtendedProperties'
    if (Test-Path $ids) { Remove-Item $ids -Recurse -Force; X47-Log 'cleared cached MSA identity properties' 'OK' }

    # If the anonymity module ran while this was a Microsoft account, it held back the sign-in hosts. Finish it.
    $hosts = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -Raw -ErrorAction SilentlyContinue
    if ($hosts -match 'x47-anon') {
        & (Join-Path $script:OpsRepo 'modules\08-anonymity.ps1') -KitRoot $script:OpsRepo
    }

    Get-LocalUser -Name $env:USERNAME | Select-Object Name, FullName, PrincipalSource | Format-Table | Out-Host
    X47-Log "Sign out and back in to see $DisplayName on the sign-in screen and Start menu." 'OK'
} finally {
    Ops-StopTranscript $OpsTranscript
}
