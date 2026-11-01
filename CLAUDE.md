# Notes for the next AI agent

Small Windows tool (C# built on the PC at install, PowerShell installer): each account keeps its own screen resolution and
refresh rate. Windows has one display mode per PC; a per-user scheduled task (logon, console
connect, unlock) re-applies the signed-in user's mode from `%LOCALAPPDATA%\PerUserDisplay\settings.txt`.

- `PerUserDisplay.cs`: all the logic (apply / `save` / `list`). Install.ps1 compiles it with the Windows
  C# compiler (`Add-Type -OutputType WindowsApplication`) to `%LOCALAPPDATA%\PerUserDisplay\PerUserDisplay.exe`,
  so sign-in starts a windowless exe directly (no PowerShell startup, no console). That compiler is C# 5:
  no `$""`, no `out var`, no Linq. Picks only a mode `EnumDisplaySettings` lists, tests with `CDS_TEST`,
  then applies with `CDS_UPDATEREGISTRY`. Main screen only.
  The task runs `PerUserDisplay.exe watch`: it re-checks every 2 s for 60 s and re-applies, because at a cold boot
  the first try often failed (driver not ready / short mode list / Windows restoring its mode afterward, 2026-11-01).
  No argument = retry up to 10 s until it sticks (Apply now.cmd).
- `Install.ps1` (via `Install.cmd`): builds the exe, saves the current mode, registers the task (priority 4;
  falls back to a Startup shortcut). `Change my resolution.cmd` = `PerUserDisplay.exe save`. `Uninstall.cmd` removes all.
- History (2026-10-30/31): a PowerShell version showed a console for 10-20 s at a fresh sign-in (PowerShell
  start + Add-Type compile on a busy desktop); the owner signs in fresh every time, so speed at sign-in matters.
  Also: PowerShell passes `$null` to a `string` P/Invoke parameter as `""`, which `EnumDisplaySettings` rejects.
- The PowerShell version worked on the owner's PC (1920x1080 @ 144 Hz; dad 4K); the exe version is new 2026-10-31. Keep files ASCII (Windows PowerShell 5.1
  reads BOM-less .ps1 as ANSI) and `.cmd` files CRLF (`.gitattributes`).
