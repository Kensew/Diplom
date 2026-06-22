@echo off
title Flutter on Android phone

call "%~dp0_config.bat"
call "%~dp0_get-lan-ip.bat"

set "PB_URL=http://%LAN_IP%:%POCKETBASE_PORT%"

echo ========================================
echo  Flutter run on Android (USB)
echo  POCKETBASE_URL=%PB_URL%
echo  1. Run start-server.bat on PC
echo  2. Enable USB debugging on phone
echo  3. Same WiFi network
echo ========================================
echo.

cd /d "%PROJECT_DIR%"
flutter devices
echo.
flutter run --dart-define=POCKETBASE_URL=%PB_URL%

pause
