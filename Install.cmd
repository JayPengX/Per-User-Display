@echo off
echo Per-user display: remembers YOUR resolution and refresh rate for this account.
echo Set the screen the way you like it in Settings ^> Display first.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
echo.
pause
