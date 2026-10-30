<#
  Per-user display: puts the main screen at THIS user's resolution and refresh rate.

  Windows keeps one display setting for the whole PC, so when two people share it
  the last one to change it wins. This script runs when you sign in (and when you
  switch back to your account) and sets the screen to what is in your settings.txt.

  Your settings live in  %LOCALAPPDATA%\PerUserDisplay\settings.txt  (only yours).

  Set-Display.ps1            apply settings.txt (what the scheduled task runs)
  Set-Display.ps1 -Save      write the screen's current mode into settings.txt
  Set-Display.ps1 -List      show every mode the main screen supports
#>
param([switch]$Save, [switch]$List)

$ErrorActionPreference = 'Stop'
$Home_   = Join-Path $env:LOCALAPPDATA 'PerUserDisplay'
$Config  = Join-Path $Home_ 'settings.txt'
$LogFile = Join-Path $Home_ 'log.txt'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace PerUserDisplay {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
    public int dmFields;
    public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
    public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
    public int dmDisplayFlags; public int dmDisplayFrequency;
    public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
    public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
  }

  public static class Native {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, int flags, IntPtr lParam);

    public static DEVMODE NewMode() {
      DEVMODE dm = new DEVMODE();
      dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
      return dm;
    }

    // The device name is passed as a real null (= the main screen) from here,
    // because PowerShell turns $null into "" for string parameters, which Windows rejects.
    public static bool GetMode(int modeNum, out DEVMODE dm) {
      dm = NewMode();
      return EnumDisplaySettings(null, modeNum, ref dm);
    }
    public static int SetMode(DEVMODE dm, int flags) {
      return ChangeDisplaySettingsEx(null, ref dm, IntPtr.Zero, flags, IntPtr.Zero);
    }
  }
}
'@

$ENUM_CURRENT_SETTINGS = -1
$CDS_UPDATEREGISTRY    = 0x1   # remember it (stored in this user's profile, not for everyone)
$CDS_TEST              = 0x2   # ask the driver first, change nothing
$DM_PELSWIDTH          = 0x80000
$DM_PELSHEIGHT         = 0x100000
$DM_DISPLAYFREQUENCY   = 0x400000

function Write-Log([string]$text) {
  New-Item -ItemType Directory -Force -Path $Home_ | Out-Null
  if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 100KB) { Remove-Item $LogFile }
  Add-Content -Path $LogFile -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $text)
}

function Get-CurrentMode {
  $dm = New-Object PerUserDisplay.DEVMODE
  if (-not [PerUserDisplay.Native]::GetMode($ENUM_CURRENT_SETTINGS, [ref]$dm)) { throw 'Could not read the current display mode.' }
  $dm
}

function Get-SupportedModes {
  $modes = @{}
  $i = 0
  while ($true) {
    $dm = New-Object PerUserDisplay.DEVMODE
    if (-not [PerUserDisplay.Native]::GetMode($i, [ref]$dm)) { break }
    $key = "$($dm.dmPelsWidth)x$($dm.dmPelsHeight)@$($dm.dmDisplayFrequency)"
    if (-not $modes.ContainsKey($key)) {
      $modes[$key] = [pscustomobject]@{ Width = $dm.dmPelsWidth; Height = $dm.dmPelsHeight; RefreshRate = $dm.dmDisplayFrequency }
    }
    $i++
  }
  $modes.Values | Sort-Object Width, Height, RefreshRate
}

function Read-Settings {
  if (-not (Test-Path $Config)) { throw "No settings file at $Config. Run Install.cmd first." }
  $s = @{}
  foreach ($line in Get-Content $Config) {
    if ($line -match '^\s*(Width|Height|RefreshRate)\s*=\s*(\d+)\s*$') { $s[$Matches[1]] = [int]$Matches[2] }
  }
  foreach ($k in 'Width', 'Height') { if (-not $s.ContainsKey($k)) { throw "settings.txt has no $k= line." } }
  if (-not $s.ContainsKey('RefreshRate')) { $s['RefreshRate'] = 0 }   # 0 = highest the screen allows
  $s
}

function Save-Settings($w, $h, $hz) {
  New-Item -ItemType Directory -Force -Path $Home_ | Out-Null
  @"
# Display setting for $env:USERNAME on this PC.
# Change the numbers, save this file, then sign out and back in
# (or double-click "Apply now.cmd") to use them.
# RefreshRate is in Hz. RefreshRate=0 means "the highest this resolution allows".
Width=$w
Height=$h
RefreshRate=$hz
"@ | Set-Content -Path $Config -Encoding UTF8
}

if ($List) {
  Get-SupportedModes | ForEach-Object { '{0} x {1}  {2} Hz' -f $_.Width, $_.Height, $_.RefreshRate }
  return
}

if ($Save) {
  $cur = Get-CurrentMode
  Save-Settings $cur.dmPelsWidth $cur.dmPelsHeight $cur.dmDisplayFrequency
  "Saved: $($cur.dmPelsWidth) x $($cur.dmPelsHeight) at $($cur.dmDisplayFrequency) Hz -> $Config"
  return
}

# ---- Apply ----
try {
  $want = Read-Settings
  $cur  = Get-CurrentMode
  $modes = @(Get-SupportedModes | Where-Object { $_.Width -eq $want.Width -and $_.Height -eq $want.Height })

  if ($modes.Count -eq 0) {
    Write-Log "Skipped: the screen does not support $($want.Width)x$($want.Height). Left it at $($cur.dmPelsWidth)x$($cur.dmPelsHeight)@$($cur.dmDisplayFrequency)."
    return
  }

  # Exact refresh rate if the screen has it; otherwise the highest one below it; otherwise the lowest there is.
  $pick = $modes | Where-Object { $_.RefreshRate -eq $want.RefreshRate } | Select-Object -First 1
  if (-not $pick -and $want.RefreshRate -gt 0) { $pick = $modes | Where-Object { $_.RefreshRate -lt $want.RefreshRate } | Sort-Object RefreshRate | Select-Object -Last 1 }
  if (-not $pick -and $want.RefreshRate -gt 0) { $pick = $modes | Sort-Object RefreshRate | Select-Object -First 1 }
  if (-not $pick) { $pick = $modes | Sort-Object RefreshRate | Select-Object -Last 1 }
  if ($want.RefreshRate -gt 0 -and $pick.RefreshRate -ne $want.RefreshRate) {
    Write-Log "$($want.RefreshRate) Hz is not offered at $($want.Width)x$($want.Height); using $($pick.RefreshRate) Hz."
  }

  if ($cur.dmPelsWidth -eq $pick.Width -and $cur.dmPelsHeight -eq $pick.Height -and $cur.dmDisplayFrequency -eq $pick.RefreshRate) {
    Write-Log "Already $($pick.Width)x$($pick.Height)@$($pick.RefreshRate)."
    return
  }

  $dm = $cur
  $dm.dmPelsWidth = $pick.Width
  $dm.dmPelsHeight = $pick.Height
  $dm.dmDisplayFrequency = $pick.RefreshRate
  $dm.dmFields = $DM_PELSWIDTH -bor $DM_PELSHEIGHT -bor $DM_DISPLAYFREQUENCY

  $test = [PerUserDisplay.Native]::SetMode($dm, $CDS_TEST)
  if ($test -ne 0) {
    Write-Log "Skipped: the driver refused $($pick.Width)x$($pick.Height)@$($pick.RefreshRate) in a test (code $test). Nothing changed."
    return
  }
  $result = [PerUserDisplay.Native]::SetMode($dm, $CDS_UPDATEREGISTRY)
  if ($result -eq 0) { Write-Log "Set $($pick.Width)x$($pick.Height)@$($pick.RefreshRate) (was $($cur.dmPelsWidth)x$($cur.dmPelsHeight)@$($cur.dmDisplayFrequency))." }
  else { Write-Log "Change failed (code $result). Nothing changed." }
}
catch {
  Write-Log "Error: $($_.Exception.Message)"
}
