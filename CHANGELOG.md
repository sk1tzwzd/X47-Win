# Changelog

## 1.2.0

Toolbox release. The tools and fixes below were run on a real Windows 11 install (Insider build 26300, Microsoft account still active). Not yet exercised on hardware: `local-account.ps1` and `debian-setup.ps1`.

### Toolbox (`windows/tools/`, optional, re-runnable)

- **Deep debloat** (`debloat-deep.ps1`): disables ~60 services a home PC never uses: Xbox Live, phone/SMS/wallet/NFC, Windows AI components and compatibility telemetry, domain/MDM/Work Folders/iSCSI/SNMP/WebDAV, Hyper-V guest, smart card, pen and sensors, scanners, Hello and Wi-Fi Direct. It also drops PowerShell 2.0, Internet Explorer, legacy Media Player, Steps Recorder and Math Recognizer, plus leftover telemetry tasks, and switches Delivery Optimization to HTTP-only. Every service's previous start type is journalled; `-Undo` restores them. `-DryRun` lists everything first. Bluetooth, Xbox controllers, GameInput, camera, search, SysMain, Store and Print to PDF stay. The spooler stays with its remote RPC endpoint off.
- **Debloat extras** (`debloat.ps1`): the Copilot desktop app (Win32), Clipchamp, Family, the Widgets runtime and leftover provisioned copies. Also turns off Start/lock-screen suggestions, Bing in Start search, and Edge startup boost/background mode/sidebar.
- **Hardening** (`harden.ps1`): Defender back to full real-time, behaviour and download scanning, with network protection, a high cloud block level and PUA blocking. Compatibility-telemetry tasks are disabled, and SSDP/UPnP discovery, geolocation and Maps are switched off. It ends with a quick scan and a reminder to switch tamper protection back on.
- **Performance** (`performance.ps1`): Best performance power mode on AC with Balanced on battery, aggressive CPU boost on AC, hardware-accelerated GPU scheduling, and NVIDIA Control Panel when an NVIDIA GPU is present.
- **Gaming Mode** (`gaming-mode.ps1 -Install`): a taskbar button whose icon lights up when on. ON sets High performance and Windows Game Mode, mutes notifications, pauses Mullvad (lifting lockdown if set) and stops WSL. OFF restores every recorded value exactly. No admin needed.
- **Vault** (`vault.ps1`): `~\Vault`, an owner-only folder with junctions to `~\.ssh` and `~\.aws` plus a `servers\` folder. It gets its own icon, a Start entry and a Quick Access pin, and its README lists hosts from your ssh config at run time.
- **LAN transfer with Linux** (`ssh-transfer.ps1`, `transfer-tools.ps1`): an OpenSSH server with key-only login, `AllowUsers`, admin keys file ACLs and a firewall rule for one LAN IP (the capability's allow-any rule is removed). It also sets Mullvad LAN sharing to allow, adds an `x47` host alias, an Explorer *Send to > Ubuntu X47*, a WinSCP session and a pinned `FromUbuntu` inbox.
- **Clock** (`timesync.ps1`): Windows Time on, synced against Cloudflare and pool.ntp.org every 30 minutes. `timezone-auto.ps1` sets the time zone from the Wi-Fi network you join (network profile name, no location services) through a logon and network-connect task.
- **Screen capture** (`screen-capture.ps1`): the anonymity pass force-denies background apps, which broke Snipping Tool saving and recording. This exempts Snipping Tool, and PrtSc opens the area/window/full-screen, screenshot/record bar.
- **Local account** (`local-account.ps1 -DisplayName`): after leaving a Microsoft account, it sets the sign-in name, hides the email and finishes the anonymity module's account block.
- **Dev rig** (`dev-setup.ps1` + `packages.json`): Python 3.13 with the `py` launcher, uv, pipx, Node LTS, PowerShell 7, GitHub CLI, Rust, Go, C++ Build Tools and WinSCP. It also removes the Store `python` stubs. Optional `-GitName`/`-GitEmail`.
- **Optional WSL2 + Debian** (`wsl.ps1 -Install|-Remove`, `debian-setup.ps1`), not installed by default because the VM costs battery.
- **Mullvad baseline** (`mullvad.ps1`): auto-connect at boot with LAN allowed; optional `-Lockdown` and `-Blockers`.

### Fixes

- **Anonymity pass crashed at the end:** a `$revert` path variable clashed with the `-Revert` switch (PowerShell names are case-insensitive), so the module died before finishing.
- **Wi-Fi MAC randomization did nothing:** many Wi-Fi drivers (e.g. Intel AX2xx) refuse a software override, and `netsh wlan set randomization` needs the interface name. Wi-Fi now gets Windows' per-network random hardware address.
- **Clock could stop syncing:** with Mullvad installed, NTP pointed at `193.138.218.74`, which is Mullvad's old DNS IP, not a time server. It now uses Cloudflare + pool.ntp.org and forces a resync.
- **Microsoft-account lockout risk:** the anonymity pass now detects a Microsoft-account user and holds back the account block and its sign-in hosts until `tools\local-account.ps1`. So the wizard's anonymity box is back on by default.
- **IP-based outbound rules are opt-in** (`-IpRules`): shared CDN IPs blocked unrelated sites. The hosts file does the blocking.
- **Debloat:** OneDrive goes first with both sync policies, each Appx removal is isolated, and background apps and Game DVR are off.
- **Installer:** keeps the window open with the stack trace on failure. `X47-SetReg` logs a warning instead of aborting the module on a protected key.
## 1.1.3

- **Errors stay on screen** — the setup GUI launched the installer with `powershell -File`, so any failure before logging started closed the console instantly, leaving only "exit 1" and an empty `logs\` folder. It now runs through a `-Command` wrapper that keeps the window open (press Enter to close) and the installer exits 0 explicitly on success so stray `netsh`/`w32tm` exit codes cannot fake a failure.
- **Wizard no longer freezes** — the GUI waited on the installer with a blocking `WaitForExit()` on the UI thread, so Windows flagged it "Not Responding" for the whole install. The wait is asynchronous now.
- **GUI launch log** — `logs\setup-gui.log` records the exact PowerShell command and exit code, so there is always evidence even when the installer dies before its own log starts.
- **CRLF batch files** — all `.bat` files are CRLF and pinned that way in `.gitattributes`; `cmd.exe` mishandles `goto` labels in LF-only batch files staged from Linux.

## 1.1.2

- **Rollback actually rolls back** — the snapshot flag was `$script:`-scoped, so every module (run in its own scope via `& modules\NN-*.ps1`) reset it to `$false` and silently journalled nothing. `journal-reg.json`, `journal-services.json` and `journal-tasks.json` were never written, and `Rollback-X47Windows.bat` restored 0 registry values while still reporting success. The flag is now `$global:` with an on-disk fallback (`X47-SnapshotIsActive`), so standalone `Apply-X47Theme` / `Apply-X47Anonymity` runs journal into an existing snapshot too.
- **One log per run** — log dir and file were also `$script:`-scoped, producing a separate timestamped log per module while the installer pointed you at just one of them. Both are `$global:` now.
- **`Install-X47Windows.bat /cli` can self-elevate** — `SHIFT` moves `%0`, so `%~f0` no longer named the batch file by the time the UAC re-launch ran. Path is captured before the argument loop.
- **Desktop entry point is a shim, not a copy** — a copied `X47Setup.exe` resolves its kit root from its own folder, so it only worked when the kit was literally `C:\X47`.
- **Themes download before the network drops** — `06-themes` now runs before `08-anonymity`, which randomizes every physical NIC MAC and forces Wi-Fi re-association. Open-Shell / ExplorerPatcher were failing to download on the XP, Vista and Win10 looks.
- **Staging** — refuses to write a hibernated volume, detects Windows profiles instead of hardcoding one, and drops a dead wallpaper source path left over from the monorepo split.

## 1.1.1

- **Installer snapshot fallback** — fixed exit 1 error when System Restore point creation fails on Windows 11; installer now proceeds cleanly with registry and configuration rollback journaling without blocking.
- **Log pathing fix** — dynamic log resolution to `<KitRoot>\logs\` across all setup GUIs and scripts so logs are always created and reported accurately.

## 1.1.0

- **Setup GUI** — `X47Setup.exe` wizard (Welcome → default look → feature checkboxes → Install). First run compiles it with Windows `csc.exe`. BitLocker and MachineGuid stay off until you check them. `-Quiet` skips the console YES/SPOOF prompts when the GUI already confirmed.
- **Docs: features** — site and README list snapshot/rollback, all-NIC MACs, optional encryption, optional MachineGuid spoof, and point disk reclaim at Ubuntu X47 Ark.
- **Optional MachineGuid spoof** — `-SpoofMachineGuid` then type `SPOOF`. Warns that activation breaks. Does not change SMBIOS UUID or TPM. Reversible from the snapshot.
- **MAC randomization** — software override on every physical NIC (Wi-Fi + Ethernet). VPN/virtual adapters skipped. Factory MAC stays in firmware; rollback restores it.
- **Safe install + rollback** — snapshot (restore point + `C:\X47\rollback`) before changes. Undo with `Rollback-X47Windows.bat` (type `ROLLBACK`). Does not delete user files or turn BitLocker off.
- Encryption is **advised, not required**. Default install skips BitLocker. Opt in with `-EnableBitLocker`. Docs cover VeraCrypt (DIY from veracrypt.fr) as an alternative — do not stack both on one volume.

## 1.0.0

- Initial public split from Ubuntu X47.
- Windows 11 Pro kit: wallpaper, debloat, privacy, ID rotation, BitLocker TPM+PIN, themes, security, max-offline anonymity.
- Standalone docs site (Overview, Install, Security) with theme screenshot placeholders.
