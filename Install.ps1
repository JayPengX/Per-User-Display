# One-time setup for the person signed in right now. Each person runs Install.cmd from their own account.
$ErrorActionPreference = 'Stop'
$src  = $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'PerUserDisplay'
$me   = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$taskName = "Per-user display ($env:USERNAME)"

New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item (Join-Path $src 'Set-Display.ps1') $dest -Force
Get-ChildItem $dest -File | Unblock-File

# Remember the screen exactly as it is now: set it the normal way in Settings first.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'Set-Display.ps1') -Save
if ($LASTEXITCODE -ne 0) { Write-Host 'Could not read the screen, so nothing was installed. Send a screenshot of this window to Claude.'; exit 1 }

# "Apply now.cmd" next to the settings, for after you edit them.
"@powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0Set-Display.ps1`"`r`n@type `"%~dp0log.txt`" 2>nul`r`n@pause" |
  Set-Content -Path (Join-Path $dest 'Apply now.cmd') -Encoding ASCII

$run = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest\Set-Display.ps1`""
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $run
$principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
               -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew

# Sign-in, plus coming back to this account by fast user switching (console connect) or unlock.
$triggers = @(New-ScheduledTaskTrigger -AtLogOn -User $me)
try {
  $cls = Get-CimClass -Namespace 'Root/Microsoft/Windows/TaskScheduler' -ClassName 'MSFT_TaskSessionStateChangeTrigger'
  foreach ($state in 1, 8) {   # 1 = TASK_CONSOLE_CONNECT, 8 = TASK_SESSION_UNLOCK
    $t = New-CimInstance -CimClass $cls -ClientOnly
    $t.StateChange = $state
    $t.UserId = $me
    $t.Enabled = $true
    $triggers += $t
  }
} catch { Write-Host 'Note: could not add the switch-user trigger; sign-in still works.' }

$how = $null
try {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings `
    -Description 'Sets the screen to this user''s resolution and refresh rate (PerUserDisplay).' | Out-Null
  $how = 'a scheduled task (runs at sign-in and when you switch back to this account)'
} catch {
  # Fallback: a shortcut in this user's Startup folder (sign-in only).
  $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Per-user display.lnk'
  $sh = New-Object -ComObject WScript.Shell
  $s = $sh.CreateShortcut($lnk)
  $s.TargetPath = 'powershell.exe'
  $s.Arguments = $run
  $s.WindowStyle = 7
  $s.Save()
  $how = 'a Startup shortcut (runs at sign-in; after a switch-user, double-click "Apply now.cmd")'
}

Write-Host ''
Write-Host "Done for $env:USERNAME, using $how."
Write-Host "Your setting: $(Join-Path $dest 'settings.txt')"
Write-Host 'To change it later: edit that file, then double-click "Apply now.cmd" in the same folder.'
