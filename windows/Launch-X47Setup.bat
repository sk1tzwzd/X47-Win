@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title X47-Win Setup

if not exist "%~dp0X47Setup.exe" (
  echo Building X47-Win Setup ^(one-time, uses built-in csc.exe^)...
  call "%~dp0setup\Build-X47Setup.bat"
  echo.
)

if exist "%~dp0X47Setup.exe" (
  if exist "%USERPROFILE%\Desktop\" copy /y "%~dp0X47Setup.exe" "%USERPROFILE%\Desktop\X47-Win Setup.exe" >nul 2>&1
  start "" "%~dp0X47Setup.exe"
  exit /b 0
)

echo Compile failed — opening the same setup GUI in PowerShell.
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0X47Setup.ps1"
exit /b %ERRORLEVEL%
