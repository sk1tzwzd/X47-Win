# X47-Win kit

PowerShell pack for this repo. Ubuntu X47 is a [separate project](https://sk1tzwzd.github.io/ubuntu-x47-build/).

**Site:** [Overview](https://sk1tzwzd.github.io/X47-Win/) · [Install](https://sk1tzwzd.github.io/X47-Win/install.html) · [Security](https://sk1tzwzd.github.io/X47-Win/security.html)

Run **from Windows 11 (Home or Pro), as Administrator**. Staging from Linux only copies files. Encryption is advised, not required.

Double-click `Launch-X47Setup.bat` — first run builds `X47Setup.exe`, then a wizard lets you pick the default look and which features to apply.

```powershell
Set-ExecutionPolicy Bypass -Scope Process
C:\X47\Install-X47Windows.ps1          # console
C:\X47\Install-X47Windows.bat /cli     # same, via the old YES prompt
```

Snapshot first; undo with `Rollback-X47Windows.bat`. Does not delete your files.

## Security and privacy (short)

**Keeps:** Defender, SmartScreen, Windows Update, local files. BitLocker is opt-in (`-EnableBitLocker`). VeraCrypt is fine — install it yourself from [veracrypt.fr](https://www.veracrypt.fr/); do not stack it on BitLocker.

**Locks:** inbound firewall; RDP/WinRM/SMBv1/LLMNR off; UAC max; Recall off; Fast Startup off.

**Cuts:** telemetry to Required; ads/location/activity history off; Advertising ID + SQM ID rotated; Microsoft accounts blocked; Store/OneDrive/Xbox/telemetry hosts blocked; OneDrive uninstalled; physical NIC MACs randomized (software override); NTP → pool.ntp.org.

**Does not hide:** board UUID, TPM, `MachineGuid`, or your ISP IP (run Mullvad on Windows for that). Those cannot be hidden without breaking Windows.

**Breaks:** Store, OneDrive, Xbox Live, “Sign in with Microsoft.”

Revert hosts: `Apply-X47Anonymity.ps1 -Revert`

## Looks

`Apply-X47Theme.bat` — `x47` | `xp` | `xp-remastered` | `vista` | `win10` | `win11`

Open-Shell skins are GPL. No Microsoft theme files.

See `START-HERE.txt` and `docs/x47-windows-guide.html`.
