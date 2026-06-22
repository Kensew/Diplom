@echo off
title Flutter Web LAN

call "%~dp0_config.bat"
call "%~dp0_get-lan-ip.bat"

set "PB_URL=http://%LAN_IP%:%POCKETBASE_PORT%"

echo ========================================
echo  Flutter Web + PocketBase (WiFi)
echo  POCKETBASE_URL=%PB_URL%
echo  Run start-server.bat first
echo ========================================
echo.

cd /d "%PROJECT_DIR%"
flutter run -d edge --web-hostname=0.0.0.0 --web-port=8080 --dart-define=POCKETBASE_URL=%PB_URL%

pause
