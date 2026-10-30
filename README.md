# Per-User-Display

**[Download (zip)](https://github.com/JayPengX/Per-User-Display/archive/refs/heads/main.zip)**


Windows keeps one resolution and refresh rate for the whole PC, so whoever changed it last wins.
This little tool gives each account its own: when you sign in, or switch back to your account,
it puts the main screen at *your* resolution and refresh rate.

## Install (each person, once, from their own account)

1. Download the zip above. Right-click it > **Properties** > tick **Unblock** > OK, then **Extract All**.
   Put the folder somewhere both accounts can reach, for example `C:\Users\Public\per-user-display`.
   (After both accounts have installed, you can delete it: the install copies what it needs into each account.)
2. Sign in as yourself and set the screen the way you want it:
   **Settings > System > Display** (resolution) and **Advanced display** (refresh rate).
3. Double-click **Install.cmd**. It remembers what the screen is set to right now. No admin needed.
4. Switch to the other account and do steps 2 and 3 there (dad: 3840 x 2160; Jay: 1920 x 1080 at 144 Hz, or whatever you like).

That's it. Sign out and back in to see it work.

## Change your setting later

Open `%LOCALAPPDATA%\PerUserDisplay\` (paste that into the File Explorer address bar), edit
**settings.txt**, save, and double-click **Apply now.cmd**. Or just set the screen in Settings
and run Install.cmd again.

```
Width=1920
Height=1080
RefreshRate=144
```

`RefreshRate=0` means "the highest this resolution allows". To see every mode your screen
supports, run in PowerShell: `& "$env:LOCALAPPDATA\PerUserDisplay\Set-Display.ps1" -List`

## Safety

- It only uses a mode the screen itself lists, and asks the graphics driver to test it before switching.
- If your resolution isn't supported (say a different monitor is plugged in), it leaves the screen alone.
- If your refresh rate isn't offered, it uses the closest one below it.
- It only changes the main screen. Every run writes one line to `%LOCALAPPDATA%\PerUserDisplay\log.txt`.

## Fast user switching

If both of you stay signed in and switch with **Switch user**, the tool also runs when you come back
to your account (and when you unlock it), so the screen follows whoever is at the keyboard.
On the rare PC where Windows won't allow that trigger, Install.cmd uses a Startup shortcut instead:
it still works at sign-in, and after a switch you double-click **Apply now.cmd**.
A small PowerShell window may flash for a moment when it runs.

## Undo

Double-click **Uninstall.cmd** from each account that installed it. It removes that account's task
and settings. The screen stays as it is; change it in Settings if you want.

(By hand: open Task Scheduler, delete "Per-user display (your name)", and delete the folder
`%LOCALAPPDATA%\PerUserDisplay`.)
