# Right-click > Send to > Ubuntu X47. Copies the selected files/folders to ~/FromWindows on the Ubuntu box over SSH.
# Installed into the Send to menu by tools\transfer-tools.ps1. Uses the 'x47' host from ~/.ssh/config.
param([Parameter(ValueFromRemainingArguments)][string[]]$Paths)
$Host.UI.RawUI.WindowTitle = 'Send to Ubuntu X47'
if (-not $Paths) { Write-Host 'Nothing selected.'; Start-Sleep 2; exit 1 }

ssh -o ConnectTimeout=8 -o BatchMode=yes x47 'mkdir -p ~/FromWindows' 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Could not reach the Ubuntu box (x47).' -ForegroundColor Red
    Write-Host ' - Is it on and on the same Wi-Fi?'
    Write-Host ' - Key locked? Run once in a terminal:  ssh-add $HOME\.ssh\id_ed25519'
    Read-Host 'Press Enter to close'; exit 1
}
$fail = 0
foreach ($p in $Paths) {
    Write-Host "-> $(Split-Path $p -Leaf)" -ForegroundColor Cyan
    scp -r -p -o BatchMode=yes "$p" 'x47:~/FromWindows/'
    if ($LASTEXITCODE -ne 0) { $fail++ }
}
if ($fail) { Write-Host "$fail item(s) failed." -ForegroundColor Red; Read-Host 'Press Enter to close' }
else { Write-Host 'Done: on Ubuntu in ~/FromWindows' -ForegroundColor Green; Start-Sleep 2 }
