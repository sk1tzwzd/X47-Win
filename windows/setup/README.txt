X47-Win Setup (GUI)
===================

X47Setup.cs is a Windows Forms wizard. On Windows 11 it compiles with the
built-in C# compiler (csc.exe) — no Visual Studio required:

  C:\X47\setup\Build-X47Setup.bat

That writes C:\X47\X47Setup.exe (requires Administrator via the manifest).

Usual launch:

  C:\X47\Launch-X47Setup.bat
  C:\X47\Install-X47Windows.bat          (opens the GUI)
  C:\X47\Install-X47Windows.bat /cli     (old YES prompt, no GUI)

The wizard default look is X47 circuit. Page 3 has a checkbox for every
installer feature. BitLocker and MachineGuid spoof stay off until you
check them (and confirm a warning). Snapshot stays on unless you uncheck it.
