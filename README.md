# Per-User-Display

**[Download (zip)](https://github.com/JayPengX/Per-User-Display/archive/refs/heads/main.zip)**


Windows keeps one resolution and refresh rate for the whole PC, so whoever changed it last wins.
This little tool gives each account its own: when you sign in, or switch back to your account,
it puts the main screen at *your* resolution and refresh rate.

## Install (each person, once, from their own account)

1. Download the zip above. Right-click it > **Properties** > tick **Unblock** > OK, then **Extract All**.
   Put the folder somewhere both accounts can reach, for example `C:\Users\Public\per-user-display`.
   (After both accounts have installed you can delete it, since the install copies what it needs into each account. Keep it if you want **Change my resolution.cmd** handy.)
2. Sign in as yourself and set the screen the way you want it:
   **Settings > System > Display** (resolution) and **Advanced display** (refresh rate).
3. Double-click **Install.cmd**. It remembers what the screen is set to right now. No admin needed.
4. Switch to the other account and do steps 2 and 3 there (dad: 3840 x 2160; Jay: 1920 x 1080 at 144 Hz, or whatever you like).

That's it. Sign out and back in to see it work.

## Change your setting later

Pick the resolution in Settings, then double-click **Change my resolution.cmd** in this folder.
From then on that is your resolution, for whoever is signed in only. (Running Install.cmd again does the same.)

You can also edit the numbers by hand: open `%LOCALAPPDATA%\PerUserDisplay\` (paste that into the
File Explorer address bar), edit **settings.txt**, save, and double-click **Apply now.cmd** there.

```
Width=1920
Height=1080
RefreshRate=144
```

`RefreshRate=0` means "the highest this resolution allows". To see every mode your screen
supports, press Win+R, run `%LOCALAPPDATA%\PerUserDisplay\PerUserDisplay.exe list`, and open
`modes.txt` in that folder.

## Safety

- It only uses a mode the screen itself lists, and asks the graphics driver to test it before switching.
- If your resolution isn't supported (say a different monitor is plugged in), it leaves the screen alone.
- If your refresh rate isn't offered, it uses the closest one below it.
- It only changes the main screen. Every run writes what it did to `%LOCALAPPDATA%\PerUserDisplay\log.txt`.
- Right after Windows starts, the screen often isn't ready yet at sign-in (or Windows puts its own mode
  back a few seconds later), so for the first minute after you sign in it keeps checking and sets your
  mode again if needed. If you change the resolution in Settings during that minute, it may switch back:
  wait a minute, then change it.

## Fast user switching

If both of you stay signed in and switch with **Switch user**, the tool also runs when you come back
to your account (and when you unlock it), so the screen follows whoever is at the keyboard.
On the rare PC where Windows won't allow that trigger, Install.cmd uses a Startup shortcut instead:
it still works at sign-in, and after a switch you double-click **Apply now.cmd**.
It runs a tiny windowless program (built on your PC by Install.cmd from `PerUserDisplay.cs`),
so it starts the moment you sign in, with nothing on screen.

## Undo

Double-click **Uninstall.cmd** from each account that installed it. It removes that account's task
and settings. The screen stays as it is; change it in Settings if you want.

(By hand: open Task Scheduler, delete "Per-user display (your name)", and delete the folder
`%LOCALAPPDATA%\PerUserDisplay`.)
