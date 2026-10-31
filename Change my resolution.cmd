@echo off
rem Changes YOUR resolution setting (only this account) to what the screen is showing right now.
set "PUD=%LOCALAPPDATA%\PerUserDisplay"
if not exist "%PUD%\PerUserDisplay.exe" (
  echo Per-user display isn't installed for %USERNAME% yet. Run Install.cmd first.
  pause
  exit /b 1
)
echo Changing %USERNAME%'s resolution to what the screen is showing now.
echo (Pick the resolution in Settings ^> Display first if you haven't.)
echo.
start "" /wait "%PUD%\PerUserDisplay.exe" save
findstr /b "Width Height RefreshRate" "%PUD%\settings.txt"
echo.
pause
