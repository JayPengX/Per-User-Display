# One-time setup for the person signed in right now. Each person runs Install.cmd from their own account.
$ErrorActionPreference = 'Stop'
$src  = $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'PerUserDisplay'
$exe  = Join-Path $dest 'PerUserDisplay.exe'
$me   = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$taskName = "Per-user display ($env:USERNAME)"

New-Item -ItemType Directory -Force -Path $dest | Out-Null
# Files from earlier versions (the PowerShell script and its compiled code).
Remove-Item (Join-Path $dest 'Set-Display.ps1'), (Join-Path $dest 'headless-check.txt') -ErrorAction SilentlyContinue
Get-ChildItem $dest -Filter 'PerUserDisplay-*.dll' | Remove-Item -ErrorAction SilentlyContinue

# Build the small windowless program with the C# compiler that comes with Windows.
# At sign-in the task starts it directly: no PowerShell, no console window.
Remove-Item $exe -ErrorAction SilentlyContinue
Add-Type -TypeDefinition (Get-Content (Join-Path $src 'PerUserDisplay.cs') -Raw) -OutputAssembly $exe -OutputType WindowsApplication

# Remember the screen exactly as it is now: set it the normal way in Settings first.
$p = Start-Process $exe -ArgumentList 'save' -Wait -PassThru
if ($p.ExitCode -ne 0) {
  Write-Host "Could not read the screen, so nothing was installed. Send a screenshot of this window and $dest\log.txt to Claude."
  exit 1
}
$s = @{}
Get-Content (Join-Path $dest 'settings.txt') | ForEach-Object { if ($_ -match '^(\w+)=(\d+)$') { $s[$Matches[1]] = $Matches[2] } }
Write-Host "Saved: $($s.Width) x $($s.Height) at $($s.RefreshRate) Hz"

# "Apply now.cmd" next to the settings, for after you edit them by hand.
"@start `"`" /wait `"%~dp0PerUserDisplay.exe`"`r`n@powershell.exe -NoProfile -Command `"Get-Content -Tail 3 -LiteralPath '%~dp0log.txt'`"`r`n@pause" |
  Set-Content -Path (Join-Path $dest 'Apply now.cmd') -Encoding ASCII

$action    = New-ScheduledTaskAction -Execute $exe
$principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
# Priority 4 instead of the default 7 (below normal), so it isn't kept waiting behind everything else at sign-in.
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
               -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -Priority 4

# Sign-in (the first moment Windows knows who it is), plus coming back to this account
# by fast user switching (console connect) or unlock.
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
  $sc = $sh.CreateShortcut($lnk)
  $sc.TargetPath = $exe
  $sc.Save()
  $how = 'a Startup shortcut (runs at sign-in; after a switch-user, double-click "Apply now.cmd")'
}

Write-Host ''
Write-Host "Done for $env:USERNAME, using $how."
Write-Host 'To change your resolution later: pick it in Settings, then double-click "Change my resolution.cmd".'
