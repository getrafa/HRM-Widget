@echo off
title Uninstall HRM Live Widget
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "uninstall.ps1"
exit
