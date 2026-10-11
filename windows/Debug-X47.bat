@echo off
setlocal
cd /d "%~dp0"
title X47-Win debug
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Requesting Administrator rights...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
if not exist "%~dp0logs" mkdir "%~dp0logs"
echo.
echo Debloat, remove OneDrive, X47 wallpaper, privacy, and security.
echo Anonymity stays off so your Microsoft account still works.
echo Log: %~dp0logs\debug-transcript.txt
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Transcript -Path '%~dp0logs\debug-transcript.txt' -Force; $ErrorActionPreference='Continue'; & '%~dp0Install-X47Windows.ps1' -Quiet -Theme x47 -SkipAnonymity; $code = 0; if (-not $?) { $code = 1 }; Stop-Transcript; exit $code"
echo.
echo Exit code %ERRORLEVEL%
echo Open logs\debug-transcript.txt if something failed.
pause
