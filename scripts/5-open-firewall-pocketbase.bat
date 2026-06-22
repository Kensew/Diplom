@echo off
title Open firewall for PocketBase

call "%~dp0_config.bat"

echo Adding firewall rule for port %POCKETBASE_PORT%...
echo Run as Administrator.
echo.

net session >nul 2>&1
if errorlevel 1 (
  echo Run this file as Administrator.
  pause
  exit /b 1
)

netsh advfirewall firewall delete rule name="PocketBase LAN" >nul 2>&1
netsh advfirewall firewall add rule name="PocketBase LAN" dir=in action=allow protocol=TCP localport=%POCKETBASE_PORT%

if errorlevel 1 (
  echo FAILED to add firewall rule.
  pause
  exit /b 1
)

echo Done. Port %POCKETBASE_PORT% is open.
pause
