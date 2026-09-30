@echo off
title Starting Toolkit...
rem Launches system_inspect.ps1 from this same folder as Administrator,
rem bypassing the execution policy for this session only.
if not exist "%~dp0system_inspect.ps1" (
    echo system_inspect.ps1 was not found next to this file.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0system_inspect.ps1\"'"