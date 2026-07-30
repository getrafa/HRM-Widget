@echo off
title HRM Live Widget Setup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "setup.ps1"
exit
