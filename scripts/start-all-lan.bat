@echo off
title Start all (LAN)

call "%~dp0_config.bat"
call "%~dp0_get-lan-ip.bat"

echo Starting PocketBase and Flutter Web...
echo LAN IP: %LAN_IP%
echo.

start "PocketBase LAN" cmd /k "%~dp0start-server.bat"
timeout /t 3 /nobreak >nul
start "Flutter Web LAN" cmd /k "%~dp02-start-flutter-web-lan.bat"

echo.
echo For phone use: 3-run-on-phone.bat or 4-build-apk-lan.bat
echo.

pause
