# Changelog

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
