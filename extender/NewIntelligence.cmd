@echo off
rem New Intelligence extender: double-click opens the menu, or pass a command (status, apply, factory...)
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0NewIntelligence.ps1" %*
if "%~1"=="" pause
