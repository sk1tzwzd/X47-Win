# Changelog

## Unreleased

- **Optional MachineGuid spoof** — `-SpoofMachineGuid` then type `SPOOF`. Warns that activation breaks. Does not change SMBIOS UUID or TPM. Reversible from the snapshot.
- **MAC randomization** — software override on every physical NIC (Wi-Fi + Ethernet). VPN/virtual adapters skipped. Factory MAC stays in firmware; rollback restores it.
- **Safe install + rollback** — snapshot (restore point + `C:\X47\rollback`) before changes. Undo with `Rollback-X47Windows.bat` (type `ROLLBACK`). Does not delete user files or turn BitLocker off.
- Encryption is **advised, not required**. Default install skips BitLocker. Opt in with `-EnableBitLocker`. Docs cover VeraCrypt (DIY from veracrypt.fr) as an alternative — do not stack both on one volume.

## 1.0.0

- Initial public split from Ubuntu X47.
- Windows 11 Pro kit: wallpaper, debloat, privacy, ID rotation, BitLocker TPM+PIN, themes, security, max-offline anonymity.
- Standalone docs site (Overview, Install, Security) with theme screenshot placeholders.
