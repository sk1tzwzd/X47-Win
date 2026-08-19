@echo off
setlocal EnableExtensions
title X47-Win Setup
cd /d "%~dp0"

if /i "%~1"=="/cli" goto :cli
if /i "%~1"=="-cli" goto :cli
if /i "%~1"=="/nogui" goto :cli

REM Default: setup GUI (theme + feature checkboxes). First run compiles X47Setup.exe.
call "%~dp0Launch-X47Setup.bat"
exit /b %ERRORLEVEL%

:cli
setlocal EnableDelayedExpansion
set "ARGS="
:collect
shift
if "%~1"=="" goto runcli
set "ARGS=!ARGS! %1"
goto collect

:runcli
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Requesting Administrator rights...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '/cli !ARGS!' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-X47Windows.ps1" !ARGS!
if errorlevel 1 (
  echo.
  echo The kit reported an error. Scroll up or open logs\*.log
  pause
  exit /b 1
)
echo.
pause
