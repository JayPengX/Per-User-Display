@echo off
rem Saves the screen's current resolution and refresh rate as YOUR setting (only this account).
set "PUD=%LOCALAPPDATA%\PerUserDisplay\Set-Display.ps1"
if not exist "%PUD%" (
  echo Per-user display isn't installed for %USERNAME% yet. Run Install.cmd first.
  pause
  exit /b 1
)
echo Saving the screen as it is now for %USERNAME%.
echo (Change it in Settings ^> Display first if you haven't.)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PUD%" -Save
echo.
pause
