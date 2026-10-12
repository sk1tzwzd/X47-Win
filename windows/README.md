# X47-Win kitPowerShell pack for this repo. Ubuntu X47 is a [separate project](https://sk1tzwzd.github.io/ubuntu-x47-build/).**Site:** [Overview](https://sk1tzwzd.github.io/X47-Win/) · [Install](https://sk1tzwzd.github.io/X47-Win/install.html) · [Security](https://sk1tzwzd.github.io/X47-Win/security.html)Run **from Windows 11 (Home or Pro), as Administrator**. Staging from Linux only copies files. Encryption is advised, not required.Double-click `Launch-X47Setup.bat` — first run builds `X47Setup.exe`, then a wizard lets you pick the default look and which features to apply.```powershellSet-ExecutionPolicy Bypass -Scope ProcessC:\X47\Install-X47Windows.ps1          # consoleC:\X47\Install-X47Windows.bat /cli     # same, via the old YES prompt```Snapshot first; undo with `Rollback-X47Windows.bat`. Does not delete your files.## Security and privacy (short)**Keeps:** Defender, SmartScreen, Windows Update, local files. BitLocker is opt-in (`-EnableBitLocker`). VeraCrypt is fine — install it yourself from [veracrypt.fr](https://www.veracrypt.fr/); do not stack it on BitLocker.**Locks:** inbound firewall; RDP/WinRM/SMBv1/LLMNR off; UAC max; Recall off; Fast Startup off.**Cuts:** telemetry to Required; ads/location/activity history off; Advertising ID + SQM ID rotated; Microsoft accounts blocked (held back automatically while you still sign in with one; `tools\local-account.ps1` finishes it); Store/OneDrive/Xbox/telemetry hosts blocked; OneDrive uninstalled; Ethernet MACs randomized (software override) and Wi-Fi on Windows' per-network random address; NTP → Cloudflare + pool.ntp.org.**Does not hide:** board UUID, TPM, `MachineGuid`, or your ISP IP (run Mullvad on Windows for that). Those cannot be hidden without breaking Windows.**Breaks:** Store, OneDrive, Xbox Live, “Sign in with Microsoft.”Revert hosts: `Apply-X47Anonymity.ps1 -Revert`## Toolbox (1.2.0)

Optional tools in `tools\` for after the install. Each is re-runnable, self-elevates only when needed (one UAC prompt) and logs to `logs\`.

```powershell
.\tools\debloat-deep.ps1 -DryRun      # ~60 unused services, legacy features, telemetry tasks (-Undo restores)
.\tools\debloat.ps1                   # Copilot app, Clipchamp, Family, Widgets, Start/lock-screen/Edge nags
.\tools\harden.ps1                    # Defender full on + network protection, telemetry tasks, SSDP/UPnP off
.\tools\performance.ps1               # Best performance on AC, CPU boost, GPU scheduling, NVIDIA Control Panel
.\tools\gaming-mode.ps1 -Install      # one-click Gaming Mode button (restores everything when switched off)
.\tools\vault.ps1                     # ~\Vault: owner-only home for SSH keys, AWS config, server notes
.\tools\ssh-transfer.ps1 -UbuntuIp <ip> -UbuntuUser <user> -PubKey <linux .pub>   # key-only SSH from one LAN box
.\tools\transfer-tools.ps1 -UbuntuIp <ip> -UbuntuUser <user>   # Send to > Ubuntu X47, WinSCP session, inbox
.\tools\timesync.ps1                  # NTP via Cloudflare + pool.ntp.org
.\tools\timezone-auto.ps1 -Add 'GMT Standard Time'; .\tools\timezone-auto.ps1 -Install   # zone by Wi-Fi network
.\tools\screen-capture.ps1            # Snipping Tool capture bar (screenshot/record) under the background-apps block
.\tools\local-account.ps1 -DisplayName <name>   # after leaving a Microsoft account
.\tools\dev-setup.ps1 [-GitName n -GitEmail e]  # Python/uv, Node, pwsh, gh, Rust, Go, C++ Build Tools (packages.json)
.\tools\wsl.ps1 -Install|-Remove      # optional WSL2 + Debian (then tools\debian-setup.ps1)
.\tools\mullvad.ps1 [-Lockdown] [-Blockers]     # auto-connect, LAN allowed for transfers
```

Linux side for transfers: allow this PC's subnet in `ufw`, add the PC to `~/.ssh/config` as `<hostname>.local` (mDNS) so a changed IP doesn't matter, and keep `mullvad lan set allow`.
## Looks`Apply-X47Theme.bat` — `x47` | `xp` | `xp-remastered` | `vista` | `win10` | `win11`Open-Shell skins are GPL. No Microsoft theme files.See `START-HERE.txt` and `docs/x47-windows-guide.html`.