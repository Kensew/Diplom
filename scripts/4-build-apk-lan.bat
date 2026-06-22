@echo off
title Build APK for phone (LAN)

call "%~dp0_config.bat"
call "%~dp0_get-lan-ip.bat"

set "PB_URL=http://%LAN_IP%:%POCKETBASE_PORT%"

echo ========================================
echo  Build APK with LAN server URL
echo  POCKETBASE_URL=%PB_URL%
echo  Run start-server.bat before using APK
echo ========================================
echo.

cd /d "%PROJECT_DIR%"
flutter build apk --release --dart-define=POCKETBASE_URL=%PB_URL%

if errorlevel 1 (
  echo.
  echo BUILD FAILED
  pause
  exit /b 1
)

echo.
echo APK ready:
echo %PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk
echo Server: %PB_URL%
echo.

pause
