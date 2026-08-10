@echo off
if not "%1"=="h" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%0' -ArgumentList 'h' -WindowStyle Hidden"
    exit
)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "uninstall.ps1"
exit
