# Notes for the next AI agent

Small Windows tool (PowerShell, no build step): each account keeps its own screen resolution and
refresh rate. Windows has one display mode per PC; a per-user scheduled task (logon, console
connect, unlock) re-applies the signed-in user's mode from `%LOCALAPPDATA%\PerUserDisplay\settings.txt`.

- `Set-Display.ps1`: the only code that changes the screen. Picks only a mode `EnumDisplaySettings`
  lists, tests with `CDS_TEST`, then applies with `CDS_UPDATEREGISTRY`. Main screen only.
- Speed: the C# is compiled once to `%LOCALAPPDATA%\PerUserDisplay\PerUserDisplay-<hash>.dll` (Add-Type takes seconds); the task runs under `conhost --headless` when an install-time probe shows it works, so nothing shows at sign-in.
- `Install.ps1` (via `Install.cmd`): copies the script into the user's LocalAppData, saves the current
  mode, registers the task (falls back to a Startup shortcut). `Uninstall.cmd` removes both.
- Gotcha (cost a round trip, 2026-10-30): PowerShell passes `$null` to a `string` P/Invoke parameter
  as `""`, and `EnumDisplaySettings("")` fails. The C# wrappers `GetMode`/`SetMode` pass a real null.
  Keep device-name nulls inside C#.
- Tested by the owner on a real PC (1920x1080 @ 144 Hz saved). Keep files ASCII (Windows PowerShell 5.1
  reads BOM-less .ps1 as ANSI) and `.cmd` files CRLF (`.gitattributes`).
