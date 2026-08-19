#requires -Version 5.1
<#
  X47-Win setup GUI (WinForms). Used if X47Setup.exe is not built yet.
  Same options as windows/setup/X47Setup.cs
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$KitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $KitRoot 'Install-X47Windows.ps1'

$Bg = [System.Drawing.Color]::FromArgb(20, 17, 15)
$Card = [System.Drawing.Color]::FromArgb(30, 25, 22)
$Ink = [System.Drawing.Color]::FromArgb(245, 239, 232)
$Muted = [System.Drawing.Color]::FromArgb(196, 184, 174)
$Line = [System.Drawing.Color]::FromArgb(58, 49, 44)
$Teal = [System.Drawing.Color]::FromArgb(45, 212, 191)
$Rose = [System.Drawing.Color]::FromArgb(251, 113, 133)
$Warn = [System.Drawing.Color]::FromArgb(245, 158, 11)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'X47-Win Setup'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(740, 560)
$form.BackColor = $Bg
$form.ForeColor = $Ink
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

function New-Label([string]$text, $x, $y, $w, $h, $color, $bold = $false, $size = 10) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    $l.ForeColor = $color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $l.Font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    return $l
}

$header = New-Object System.Windows.Forms.Panel
$header.Size = New-Object System.Drawing.Size(740, 72)
$header.BackColor = $Card
$brand = New-Label 'X47-Win Setup' 20 14 420 28 $Teal $true 16
$step = New-Label '1 / 4   Welcome' 20 42 500 22 $Muted $false 9.5
$header.Controls.AddRange(@($brand, $step))
$form.Controls.Add($header)

$pages = @()
for ($i = 0; $i -lt 4; $i++) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point(0, 72)
    $p.Size = New-Object System.Drawing.Size(740, 420)
    $p.BackColor = $Bg
    $p.Visible = ($i -eq 0)
    $pages += $p
    $form.Controls.Add($p)
}

# Page 0
$pages[0].Controls.Add((New-Label 'Install a privacy kit on this Windows 11 PC' 28 18 680 28 $Ink $true 13))
$pages[0].Controls.Add((New-Label 'The setup GUI picks a default look and which features to apply. Nothing is written until you click Install on the last page.' 28 56 680 48 $Muted))
$welcomeCard = New-Label @"
Snapshot first — Windows restore point plus C:\X47\rollback, so you can undo.

Does not format the disk or delete Documents, Pictures, or Desktop.

BitLocker stays off unless you opt in. VeraCrypt is also fine — install it yourself from veracrypt.fr. Do not stack both on the same volume.

Store, OneDrive, Xbox, and Microsoft sign-in will likely break if you keep anonymity on. Defender and Windows Update stay on.

Undo later: C:\X47\Rollback-X47Windows.bat
"@ 28 118 684 250 $Ink
$welcomeCard.BackColor = $Card
$welcomeCard.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 12)
$pages[0].Controls.Add($welcomeCard)

# Page 1 themes
$pages[1].Controls.Add((New-Label 'Default look' 28 14 680 26 $Ink $true 13))
$pages[1].Controls.Add((New-Label 'This is applied at the end of install. You can change it later with Apply-X47Theme.' 28 42 680 36 $Muted))

$themes = @(
    @{ Id = 'x47'; Text = 'X47 circuit  (recommended default)'; Hint = 'Teal X47 circuit wallpaper and accent. Stock Windows 11 chrome. This is the default.' }
    @{ Id = 'xp'; Text = 'Windows XP'; Hint = 'Original hills wallpaper, Luna-blue accent, classic Start (Open-Shell). Window chrome stays Windows 11.' }
    @{ Id = 'xp-remastered'; Text = 'Remastered XP'; Hint = 'XP bones with a two-column Start, search, large icons, and dusk 4K hills.' }
    @{ Id = 'vista'; Text = 'Windows Vista'; Hint = 'Aurora wallpaper, Aero-style Start, transparency, dark system theme.' }
    @{ Id = 'win10'; Text = 'Windows 10'; Hint = 'ExplorerPatcher Windows 10 taskbar and bloom wallpaper.' }
    @{ Id = 'win11'; Text = 'Windows 11 stock'; Hint = 'Stock Windows 11 Start and taskbar.' }
)
$radios = @{}
$y = 88
$themeHint = New-Label $themes[0].Hint 28 314 684 88 $Teal
foreach ($t in $themes) {
    $r = New-Object System.Windows.Forms.RadioButton
    $r.Text = $t.Text
    $r.Tag = $t.Id
    $r.Location = New-Object System.Drawing.Point(36, $y)
    $r.Size = New-Object System.Drawing.Size(640, 28)
    $r.ForeColor = $Ink
    $r.BackColor = $Bg
    $r.FlatStyle = 'Flat'
    if ($t.Id -eq 'x47') { $r.Checked = $true }
    $r.Add_CheckedChanged({
        if (-not $this.Checked) { return }
        $id = [string]$this.Tag
        foreach ($item in $themes) {
            if ($item.Id -eq $id) { $themeHint.Text = $item.Hint; break }
        }
    })
    $radios[$t.Id] = $r
    $pages[1].Controls.Add($r)
    $y += 36
}
$pages[1].Controls.Add($themeHint)

# Page 2 features
$pages[2].Controls.Add((New-Label 'What to install' 28 10 680 24 $Ink $true 13))
$pages[2].Controls.Add((New-Label 'Defaults match a full privacy pass. Uncheck anything you do not want.' 28 36 680 22 $Muted))

function New-Tick([string]$text, $x, $y, [bool]$on, $color = $null) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $text
    $c.Location = New-Object System.Drawing.Point($x, $y)
    $c.Size = New-Object System.Drawing.Size(670, 26)
    $c.Checked = $on
    $c.ForeColor = $(if ($color) { $color } else { $Ink })
    $c.BackColor = $Bg
    $c.FlatStyle = 'Flat'
    return $c
}

$snap = New-Tick 'Snapshot first (restore point + C:\X47\rollback)' 36 68 $true
$wall = New-Tick 'Set wallpaper for the selected look' 36 98 $true
$debloat = New-Tick 'Debloat — Xbox, Widgets, Copilot, consumer junk' 36 128 $true
$privacy = New-Tick 'Privacy — telemetry Required, ads and location off' 36 158 $true
$ids = New-Tick 'Rotate advertising ID and SQM ID (MachineGuid left alone)' 36 188 $true
$security = New-Tick 'Security — inbound firewall, RDP off, Defender stays' 36 218 $true
$anon = New-Tick 'Max-offline anonymity — block MSA / Store / OneDrive / hosts' 36 248 $true
$themeOn = New-Tick 'Apply the selected look (Open-Shell / ExplorerPatcher as needed)' 36 278 $true
$opt = New-Label 'Optional — off by default' 28 318 400 22 $Warn $true 10
$bitlocker = New-Tick 'BitLocker + pre-boot PIN  (Windows 11 Pro, full volume)' 36 344 $false $Warn
$guid = New-Tick 'Spoof MachineGuid  (breaks activation; does not hide hardware)' 36 374 $false $Rose
$pages[2].Controls.AddRange(@($snap, $wall, $debloat, $privacy, $ids, $security, $anon, $themeOn, $opt, $bitlocker, $guid))

# Page 3 review
$pages[3].Controls.Add((New-Label 'Review and install' 28 14 680 26 $Ink $true 13))
$review = New-Label '' 28 50 684 340 $Ink
$review.BackColor = $Card
$review.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 12)
$pages[3].Controls.Add($review)

function Get-ThemeId {
    foreach ($id in $radios.Keys) {
        if ($radios[$id].Checked) { return $id }
    }
    return 'x47'
}

function Get-ThemeLabel([string]$id) {
    switch ($id) {
        'xp' { 'Windows XP' }
        'xp-remastered' { 'Remastered XP' }
        'vista' { 'Windows Vista' }
        'win10' { 'Windows 10' }
        'win11' { 'Windows 11 stock' }
        default { 'X47 circuit (default)' }
    }
}

function Get-OnOff([bool]$on) { if ($on) { '[ON] ' } else { '[off]' } }

function Update-Review {
    $t = Get-ThemeId
    $lines = @(
        "Look:  $(Get-ThemeLabel $t)"
        ''
        "$(Get-OnOff $snap.Checked)  Snapshot / rollback"
        "$(Get-OnOff $wall.Checked)  Wallpaper"
        "$(Get-OnOff $debloat.Checked)  Debloat"
        "$(Get-OnOff $privacy.Checked)  Privacy"
        "$(Get-OnOff $ids.Checked)  Rotate advertising + SQM IDs"
        "$(Get-OnOff $security.Checked)  Security hardening"
        "$(Get-OnOff $anon.Checked)  Max-offline anonymity"
        "$(Get-OnOff $themeOn.Checked)  Apply look"
        "$(Get-OnOff $bitlocker.Checked)  BitLocker + PIN"
        "$(Get-OnOff $guid.Checked)  Spoof MachineGuid"
        ''
        'A PowerShell window will open and do the work. Leave it open until it finishes.'
    )
    if ($bitlocker.Checked) { $lines += 'BitLocker will ask for a 6+ digit PIN in that window. Have a USB stick ready.' }
    if ($guid.Checked) { $lines += 'MachineGuid spoof will break activation. Board UUID and TPM stay.' }
    if (-not $snap.Checked) { $lines += 'Warning: snapshot is off. Rollback will have nothing new to restore.' }
    $review.Text = $lines -join [Environment]::NewLine
}

$script:page = 0
$names = @('Welcome', 'Default look', 'Features', 'Install')

$footer = New-Object System.Windows.Forms.Panel
$footer.Location = New-Object System.Drawing.Point(0, 492)
$footer.Size = New-Object System.Drawing.Size(740, 68)
$footer.BackColor = $Card

function New-Btn([string]$text, $x, $w, $solid = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, 16)
    $b.Size = New-Object System.Drawing.Size($w, 36)
    $b.FlatStyle = 'Flat'
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($solid) {
        $b.BackColor = [System.Drawing.Color]::FromArgb(15, 90, 80)
        $b.ForeColor = [System.Drawing.Color]::White
        $b.FlatAppearance.BorderColor = $Teal
        $b.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
    } else {
        $b.BackColor = $Card
        $b.ForeColor = $Ink
        $b.FlatAppearance.BorderColor = $Line
    }
    return $b
}

$btnCancel = New-Btn 'Cancel' 20 100
$btnBack = New-Btn 'Back' 430 90
$btnNext = New-Btn 'Next' 530 190 $true
$btnBack.Enabled = $false
$footer.Controls.AddRange(@($btnCancel, $btnBack, $btnNext))
$form.Controls.Add($footer)

function Show-Page([int]$n) {
    $script:page = $n
    for ($i = 0; $i -lt $pages.Count; $i++) { $pages[$i].Visible = ($i -eq $n) }
    $step.Text = "$($n + 1) / 4   $($names[$n])"
    $btnBack.Enabled = ($n -gt 0)
    if ($n -eq 3) { Update-Review; $btnNext.Text = 'Install' } else { $btnNext.Text = 'Next' }
}

$btnCancel.Add_Click({ $form.Close() })
$btnBack.Add_Click({ Show-Page ($script:page - 1) })
$btnNext.Add_Click({
    if ($script:page -lt 3) { Show-Page ($script:page + 1); return }

    if ($guid.Checked) {
        $r = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "MachineGuid spoof is optional and you turned it ON.`r`n`r`nIt replaces HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid.`r`nActivation WILL break. BitLocker and Windows Update can break.`r`nThe board UUID and TPM are NOT changed. The PC is still identifiable.`r`nRollback can put the old GUID back if C:\X47\rollback still exists.`r`n`r`nContinue with MachineGuid spoof?",
            'X47-Win — MachineGuid warning',
            'YesNo', 'Warning')
        if ($r -ne 'Yes') { $guid.Checked = $false; Update-Review; return }
    }
    if ($bitlocker.Checked) {
        $r = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "BitLocker will encrypt the Windows volume (XTS-AES 256, TPM + PIN).`r`n`r`nStay on AC power. Have a USB stick ready.`r`nPhotograph the 48-digit recovery key.`r`nThe PIN only unlocks Windows. Ubuntu LUKS stays separate.`r`nDo not also put VeraCrypt on this same volume.`r`n`r`nContinue with BitLocker?",
            'X47-Win — BitLocker',
            'YesNo', 'Information')
        if ($r -ne 'Yes') { $bitlocker.Checked = $false; Update-Review; return }
    }
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        [System.Windows.Forms.MessageBox]::Show($form, "Could not find Install-X47Windows.ps1 in $KitRoot", 'X47-Win Setup', 'OK', 'Error') | Out-Null
        return
    }

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath, '-Quiet', '-Theme', (Get-ThemeId))
    if (-not $snap.Checked) { $argList += '-SkipSnapshot' }
    if (-not $wall.Checked) { $argList += '-SkipWallpaper' }
    if (-not $debloat.Checked) { $argList += '-SkipDebloat' }
    if (-not $privacy.Checked) { $argList += '-SkipPrivacy' }
    if (-not $ids.Checked) { $argList += '-SkipIdentifiers' }
    if (-not $security.Checked) { $argList += '-SkipSecurity' }
    if (-not $anon.Checked) { $argList += '-SkipAnonymity' }
    if (-not $themeOn.Checked) { $argList += '-SkipTheme' }
    if ($bitlocker.Checked) { $argList += '-EnableBitLocker' }
    if ($guid.Checked) { $argList += '-SpoofMachineGuid' }

    $btnNext.Enabled = $false
    $btnBack.Enabled = $false
    $btnCancel.Enabled = $false
    $btnNext.Text = 'Installing…'
    $form.Refresh()

    $p = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $argList -WorkingDirectory $KitRoot -Wait -PassThru
    if ($p.ExitCode -eq 0) {
        [System.Windows.Forms.MessageBox]::Show($form, "X47-Win finished.`r`n`r`nEncrypt the disk when you can (BitLocker or VeraCrypt) if you did not already.`r`nUndo: C:\X47\Rollback-X47Windows.bat`r`nChange the look later: C:\X47\Apply-X47Theme.bat", 'X47-Win Setup', 'OK', 'Information') | Out-Null
        $form.Close()
    } else {
        $btnNext.Enabled = $true
        $btnBack.Enabled = $true
        $btnCancel.Enabled = $true
        $btnNext.Text = 'Install'
        [System.Windows.Forms.MessageBox]::Show($form, "The kit reported an error (exit $($p.ExitCode)).`r`nScroll the PowerShell window or open C:\X47\logs.", 'X47-Win Setup', 'OK', 'Warning') | Out-Null
    }
})

[void]$form.ShowDialog()
