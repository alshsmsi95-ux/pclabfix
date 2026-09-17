@echo off
setlocal
title ApexCare Engine (Beast Edition)

:: ApexCare.ps1 requests Administrator through a visible UAC prompt.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ApexCare.ps1"
endlocal
