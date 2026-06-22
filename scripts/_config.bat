@echo off
rem Shared paths - PocketBase lives inside the repo
for %%I in ("%~dp0..") do set "PROJECT_DIR=%%~fI"
set "POCKETBASE_DIR=%PROJECT_DIR%\pocketbase"
set "POCKETBASE_PORT=8090"
