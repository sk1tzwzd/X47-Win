# X47-Win

Windows 11 privacy kit — a separate project from [Ubuntu X47](https://sk1tzwzd.github.io/ubuntu-x47-build/). Disk encryption is advised (BitLocker or VeraCrypt), not required.

**Docs site:** [sk1tzwzd.github.io/X47-Win](https://sk1tzwzd.github.io/X47-Win/) · [Install](https://sk1tzwzd.github.io/X47-Win/install.html) · [Security](https://sk1tzwzd.github.io/X47-Win/security.html)

Run **from Windows 11 (Home or Pro), as Administrator**. Staging from Linux only copies files.

Double-click `C:\X47\Launch-X47Setup.bat` (or `Install-X47Windows.bat`). The first run compiles `X47Setup.exe` with the built-in C# compiler, then opens a setup wizard: default look (X47 circuit) plus checkboxes for every feature. After that you can run `C:\X47\X47Setup.exe` or the copy on the Desktop.

Console-only: `Install-X47Windows.bat /cli` then type `YES`.

```powershell
Set-ExecutionPolicy Bypass -Scope Process
C:\X47\Install-X47Windows.ps1
```

The installer writes a snapshot first (`C:\X47\rollback` plus a Windows restore point). It does not delete your documents. Undo with `Rollback-X47Windows.bat` (type `ROLLBACK`).

Physical NIC MACs are randomized (software override). `MachineGuid` stays unless you pass `-SpoofMachineGuid` and type `SPOOF` — that breaks activation and does not hide the board UUID or TPM.

## Security and privacy (short)

**Keeps:** Defender, SmartScreen, Windows Update, local files. Encryption if you set it up (BitLocker helper is opt-in: `-EnableBitLocker`; VeraCrypt is DIY from [veracrypt.fr](https://www.veracrypt.fr/)).

**Locks:** inbound firewall; RDP/WinRM/SMBv1/LLMNR off; UAC max; Recall off; Fast Startup off.

**Cuts:** telemetry to Required; ads/location/activity history off; Advertising ID + SQM ID rotated; Microsoft accounts blocked; Store/OneDrive/Xbox/telemetry hosts blocked; OneDrive uninstalled; physical NIC MACs randomized (software override); NTP → pool.ntp.org.

**Does not hide:** board UUID, TPM, `MachineGuid`, or your ISP IP (run Mullvad on Windows for that). Those cannot be hidden without breaking Windows.

**Breaks:** Store, OneDrive, Xbox Live, “Sign in with Microsoft.”

Revert hosts: `Apply-X47Anonymity.ps1 -Revert`

## Looks

`Apply-X47Theme.bat` — `x47` | `xp` | `xp-remastered` | `vista` | `win10` | `win11`

Open-Shell skins are GPL. No Microsoft theme files.

See `windows/START-HERE.txt` and `windows/docs/x47-windows-guide.html`.

## Features

- **Snapshot + rollback** — restore point + `C:\X47\rollback`. Undo: `Rollback-X47Windows.bat` (type `ROLLBACK`)
- **Debloat / privacy / security / max-offline** — junk apps out, telemetry Required, inbound lock, MSA/hosts block
- **MAC randomization** — all physical NICs (software override)
- **Encryption optional** — `-EnableBitLocker` or VeraCrypt from [veracrypt.fr](https://www.veracrypt.fr/)
- **MachineGuid optional** — `-SpoofMachineGuid` then `SPOOF` (breaks activation; SMBIOS/TPM unchanged)
- **Setup GUI** — `X47Setup.exe` (theme picker + feature checkboxes). Source: `windows/setup/`
- **Looks** — `Apply-X47Theme.bat`
- **Not disk reclaim** — deleting Windows so Ubuntu owns the disk is [X47 Ark](https://sk1tzwzd.github.io/ubuntu-x47-build/ark.html) on Ubuntu
