@echo off
title Reset Spider-Man V2 Theme Lock
echo ===================================================
echo     RESETTING SPIDER-MAN V2 THEME TO LOCKED
echo ===================================================
echo.
python "%~dp0reset_lock.py" 2>nul
if %errorlevel% neq 0 (
    powershell -ExecutionPolicy Bypass -NoProfile -Command "$p=Join-Path $env:LOCALAPPDATA 'HRM_Widget\config.json'; if(Test-Path $p){$c=Get-Content $p|ConvertFrom-Json;$c.SpidermanV2Unlocked=$false;$c.SpidermanV2LicenseKey='';if($c.GlassTheme -eq 'spiderman_v2'){$c.GlassTheme='spiderman'};$c|ConvertTo-Json|Set-Content $p}; Get-Process -Name HRM_Widget -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep -m 400; if(Test-Path 'C:\HRM_Widget\HRM_Widget.exe'){Start-Process 'C:\HRM_Widget\HRM_Widget.exe'}"
)
echo.
echo ===================================================
echo   Done! You can now test the unlock flow in Settings.
echo ===================================================
timeout /t 3
