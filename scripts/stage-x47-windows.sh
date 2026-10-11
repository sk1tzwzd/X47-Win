#!/usr/bin/env bash
# Copy the X47 Windows kit onto a mounted Windows NTFS volume (C:\X47).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/windows"
DEST="${1:-}"

if [[ -z "$DEST" ]]; then
  for cand in /run/media/"$USER"/*/Windows /media/"$USER"/*/Windows; do
    [[ -d "$cand" ]] || continue
    DEST="$(dirname "$cand")/X47"
    break
  done
fi

[[ -n "$DEST" ]] || { echo "usage: $0 /path/to/WindowsDrive/X47" >&2; exit 2; }
[[ -d "$SRC" ]] || { echo "missing $SRC" >&2; exit 1; }

win_root="$(dirname "$DEST")"

# Fast Startup / hibernation leaves the NTFS volume in a dirty state. Writing to it then
# means Windows discards our files on resume, or worse, corrupts the filesystem.
if [[ -f "$win_root/hiberfil.sys" ]]; then
  echo "refusing to write: $win_root/hiberfil.sys exists — Windows is hibernated or Fast Startup is on." >&2
  echo "Boot Windows and do a full Shut down (Shift+Restart -> Shut down), then retry." >&2
  exit 1
fi

[[ -w "$win_root" ]] || { echo "not writable: $win_root (is the volume mounted rw?)" >&2; exit 1; }

mkdir -p "$DEST"
# --delete keeps the destination honest. Note X47Setup.exe is deliberately NOT excluded:
# it is a build artifact of windows/setup/X47Setup.cs, so removing it forces
# Launch-X47Setup.bat to recompile the wizard from the sources we just copied.
rsync -a --delete \
  --exclude 'logs/' \
  --exclude 'rollback/' \
  --exclude 'rollback-archive-*/' \
  --exclude 'BitLocker-Recovery.txt' \
  --exclude 'X47-BitLocker-Recovery-*.txt' \
  "$SRC/" "$DEST/"

# Desktop shortcuts, for whichever real user profiles exist on that volume.
# Often read-only through a Linux NTFS mount — best effort, never fatal.
kit_win="$(basename "$DEST")"
shopt -s nullglob
for desk in "$win_root"/Users/*/Desktop; do
  profile="$(basename "$(dirname "$desk")")"
  case "$profile" in
    Public|Default|"Default User"|"All Users") continue ;;
  esac
  [[ -w "$desk" ]] || { echo "skip shortcuts: $desk is not writable"; continue; }
  # A stale copy of the exe resolves its kit root from its own folder — drop it.
  rm -f "$desk/X47-Win Setup.exe"
  cp -f "$SRC/START-HERE.txt" "$desk/START-HERE-X47.txt" || true
  for name in "X47-Win Setup" "Install X47-Win"; do
    printf '%s\r\n' '@echo off' "call C:\\$kit_win\\Launch-X47Setup.bat" >"$desk/$name.bat" || true
  done
  printf '%s\r\n' '@echo off' "C:\\$kit_win\\Rollback-X47Windows.bat" >"$desk/X47 Rollback.bat" || true
  echo "shortcuts → $desk"
done

echo "staged → $DEST"
echo "boot Windows and run: C:\\$kit_win\\Launch-X47Setup.bat  (first run compiles the GUI)"
