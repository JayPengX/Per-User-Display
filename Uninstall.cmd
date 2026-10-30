@echo off
echo Removing per-user display for %USERNAME% (the screen stays as it is now).
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Unregister-ScheduledTask -TaskName ('Per-user display (' + $env:USERNAME + ')') -Confirm:$false -ErrorAction SilentlyContinue;" ^
  "Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'Per-user display.lnk') -ErrorAction SilentlyContinue;" ^
  "Remove-Item (Join-Path $env:LOCALAPPDATA 'PerUserDisplay') -Recurse -Force -ErrorAction SilentlyContinue"
echo Done.
pause
