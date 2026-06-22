@echo off
title PocketBase LAN Server

for %%I in ("%~dp0..") do set "PROJECT_DIR=%%~fI"
set "POCKETBASE_DIR=%PROJECT_DIR%\pocketbase"
set "POCKETBASE_PORT=8090"

call "%~dp0_get-lan-ip.bat"

if not exist "%POCKETBASE_DIR%\pocketbase.exe" (
  echo.
  echo ERROR: pocketbase.exe not found:
  echo   %POCKETBASE_DIR%\pocketbase.exe
  echo.
  echo Edit POCKETBASE_DIR in scripts\start-server.bat
  echo Or place pocketbase.exe in the pocketbase\ folder.
  pause
  exit /b 1
)

echo.
echo ========================================
echo   PocketBase - PC and phone (same WiFi)
echo ========================================
echo.
echo   On this PC:
echo     http://127.0.0.1:%POCKETBASE_PORT%
echo     http://127.0.0.1:%POCKETBASE_PORT%/_
echo.
echo   From phone on same WiFi:
echo     http://%LAN_IP%:%POCKETBASE_PORT%
echo     http://%LAN_IP%:%POCKETBASE_PORT%/_
echo.
echo   Phone test in browser:
echo     http://%LAN_IP%:%POCKETBASE_PORT%/api/health
echo.
echo   Flutter on PC:
echo     --dart-define=POCKETBASE_URL=http://127.0.0.1:%POCKETBASE_PORT%
echo   Phone APK:
echo     --dart-define=POCKETBASE_URL=http://%LAN_IP%:%POCKETBASE_PORT%
echo.
echo   If phone cannot connect, run as admin once:
echo     scripts\5-open-firewall-pocketbase.bat
echo.
echo   Keep this window open while using the app.
echo ========================================
echo.

cd /d "%POCKETBASE_DIR%"
"%POCKETBASE_DIR%\pocketbase.exe" serve --http=0.0.0.0:%POCKETBASE_PORT%

pause
