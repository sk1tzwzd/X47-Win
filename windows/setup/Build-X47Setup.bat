@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "OUT=%~dp0..\X47Setup.exe"
set "SRC=%~dp0X47Setup.cs"
set "MAN=%~dp0app.manifest"
set "ICO=%~dp0x47.ico"

set "CSC="
if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC (
  echo Could not find csc.exe ^(part of .NET Framework on Windows^).
  exit /b 1
)

echo Compiling X47-Win Setup...
if exist "%ICO%" (
  "%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /win32manifest:"%MAN%" /win32icon:"%ICO%" /out:"%OUT%" /r:System.Windows.Forms.dll /r:System.Drawing.dll "%SRC%"
) else (
  "%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /win32manifest:"%MAN%" /out:"%OUT%" /r:System.Windows.Forms.dll /r:System.Drawing.dll "%SRC%"
)
if errorlevel 1 (
  echo Compile failed.
  exit /b 1
)
echo Built %OUT%
exit /b 0
