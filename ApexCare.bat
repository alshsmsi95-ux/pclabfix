@echo off
setlocal
title ApexCare Engine (Beast Edition)

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [*] Elevating privileges to Administrator...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0ApexCare.ps1\"' -Verb RunAs"
    exit /b
)

:: Already elevated, run ApexCare
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ApexCare.ps1"
endlocal
