// Per-user display: puts the main screen at THIS user's resolution and refresh rate.
//
// Windows keeps one display setting for the whole PC, so when two people share it the last
// one to change it wins. Install.cmd compiles this file into PerUserDisplay.exe in
// %LOCALAPPDATA%\PerUserDisplay, and a scheduled task runs it when you sign in (and when you
// switch back to your account). It is a small windowless program, so it starts in a moment
// even while Windows is still busy loading your desktop.
//
//   PerUserDisplay.exe          apply settings.txt (what the scheduled task runs)
//   PerUserDisplay.exe save     write the screen's current mode into settings.txt
//   PerUserDisplay.exe list     write every mode the main screen supports into modes.txt
//
// Written for the C# compiler built into Windows (C# 5): no string interpolation, no Linq.

using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

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

  public class Mode {
    public int Width, Height, RefreshRate;
    public Mode(int w, int h, int hz) { Width = w; Height = h; RefreshRate = hz; }
    public override string ToString() { return Width + "x" + Height + "@" + RefreshRate; }
  }

  public static class Program {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, int flags, IntPtr lParam);

    const int ENUM_CURRENT_SETTINGS = -1;
    const int CDS_UPDATEREGISTRY = 0x1;   // remember it (stored in this user's profile, not for everyone)
    const int CDS_TEST = 0x2;             // ask the driver first, change nothing
    const int DM_PELSWIDTH = 0x80000, DM_PELSHEIGHT = 0x100000, DM_DISPLAYFREQUENCY = 0x400000;

    static readonly string Dir = Path.Combine(
      Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PerUserDisplay");
    static readonly string SettingsFile = Path.Combine(Dir, "settings.txt");
    static readonly string LogFile = Path.Combine(Dir, "log.txt");

    public static int Main(string[] args) {
      try {
        Directory.CreateDirectory(Dir);
        string command = args.Length > 0 ? args[0].ToLowerInvariant() : "apply";
        if (command == "save") return Save();
        if (command == "list") return List();
        return Apply();
      } catch (Exception e) {
        Log("Error: " + e.Message);
        return 1;
      }
    }

    // A null device name means the main screen.
    static DEVMODE NewMode() {
      DEVMODE dm = new DEVMODE();
      dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
      return dm;
    }

    static DEVMODE Current() {
      DEVMODE dm = NewMode();
      if (!EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, ref dm)) throw new Exception("Could not read the current display mode.");
      return dm;
    }

    static List<Mode> SupportedModes() {
      List<Mode> modes = new List<Mode>();
      Dictionary<string, bool> seen = new Dictionary<string, bool>();
      for (int i = 0; ; i++) {
        DEVMODE dm = NewMode();
        if (!EnumDisplaySettings(null, i, ref dm)) break;
        Mode m = new Mode(dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency);
        if (seen.ContainsKey(m.ToString())) continue;
        seen[m.ToString()] = true;
        modes.Add(m);
      }
      modes.Sort(delegate (Mode a, Mode b) {
        if (a.Width != b.Width) return a.Width.CompareTo(b.Width);
        if (a.Height != b.Height) return a.Height.CompareTo(b.Height);
        return a.RefreshRate.CompareTo(b.RefreshRate);
      });
      return modes;
    }

    static int Save() {
      DEVMODE cur = Current();
      File.WriteAllText(SettingsFile,
        "# Display setting for " + Environment.UserName + " on this PC.\r\n" +
        "# Change the numbers, save this file, then sign out and back in\r\n" +
        "# (or double-click \"Apply now.cmd\") to use them.\r\n" +
        "# RefreshRate is in Hz. RefreshRate=0 means \"the highest this resolution allows\".\r\n" +
        "Width=" + cur.dmPelsWidth + "\r\n" +
        "Height=" + cur.dmPelsHeight + "\r\n" +
        "RefreshRate=" + cur.dmDisplayFrequency + "\r\n");
      Log("Saved " + cur.dmPelsWidth + "x" + cur.dmPelsHeight + "@" + cur.dmDisplayFrequency + " as this account's setting.");
      return 0;
    }

    static int List() {
      StringBuilder sb = new StringBuilder();
      foreach (Mode m in SupportedModes()) sb.AppendLine(m.Width + " x " + m.Height + "  " + m.RefreshRate + " Hz");
      File.WriteAllText(Path.Combine(Dir, "modes.txt"), sb.ToString());
      return 0;
    }

    static Dictionary<string, int> ReadSettings() {
      if (!File.Exists(SettingsFile)) throw new Exception("No settings file at " + SettingsFile + ". Run Install.cmd first.");
      Dictionary<string, int> s = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
      foreach (string raw in File.ReadAllLines(SettingsFile)) {
        string line = raw.Trim();
        if (line.StartsWith("#")) continue;
        int eq = line.IndexOf('=');
        if (eq < 0) continue;
        int value;
        if (int.TryParse(line.Substring(eq + 1).Trim(), out value)) s[line.Substring(0, eq).Trim()] = value;
      }
      if (!s.ContainsKey("Width") || !s.ContainsKey("Height")) throw new Exception("settings.txt needs a Width= and a Height= line.");
      if (!s.ContainsKey("RefreshRate")) s["RefreshRate"] = 0;   // 0 = highest the screen allows
      return s;
    }

    static int Apply() {
      Dictionary<string, int> want = ReadSettings();
      int w = want["Width"], h = want["Height"], hz = want["RefreshRate"];
      DEVMODE cur = Current();
      string was = cur.dmPelsWidth + "x" + cur.dmPelsHeight + "@" + cur.dmDisplayFrequency;

      List<Mode> modes = new List<Mode>();
      foreach (Mode m in SupportedModes()) if (m.Width == w && m.Height == h) modes.Add(m);   // sorted by refresh rate
      if (modes.Count == 0) {
        Log("Skipped: the screen does not support " + w + "x" + h + ". Left it at " + was + ".");
        return 0;
      }

      // Exact refresh rate if the screen has it; otherwise the highest one below it; otherwise the lowest there is.
      // RefreshRate=0 takes the highest.
      Mode pick = null;
      if (hz > 0) {
        foreach (Mode m in modes) if (m.RefreshRate <= hz) pick = m;
        if (pick == null) pick = modes[0];
        if (pick.RefreshRate != hz) Log(hz + " Hz is not offered at " + w + "x" + h + "; using " + pick.RefreshRate + " Hz.");
      } else {
        pick = modes[modes.Count - 1];
      }

      if (cur.dmPelsWidth == pick.Width && cur.dmPelsHeight == pick.Height && cur.dmDisplayFrequency == pick.RefreshRate) {
        Log("Already " + pick + ".");
        return 0;
      }

      DEVMODE dm = cur;
      dm.dmPelsWidth = pick.Width;
      dm.dmPelsHeight = pick.Height;
      dm.dmDisplayFrequency = pick.RefreshRate;
      dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY;

      int test = ChangeDisplaySettingsEx(null, ref dm, IntPtr.Zero, CDS_TEST, IntPtr.Zero);
      if (test != 0) {
        Log("Skipped: the driver refused " + pick + " in a test (code " + test + "). Nothing changed.");
        return 0;
      }
      int result = ChangeDisplaySettingsEx(null, ref dm, IntPtr.Zero, CDS_UPDATEREGISTRY, IntPtr.Zero);
      if (result == 0) Log("Set " + pick + " (was " + was + ").");
      else Log("Change failed (code " + result + "). Nothing changed.");
      return result == 0 ? 0 : 1;
    }

    static void Log(string text) {
      try {
        Directory.CreateDirectory(Dir);
        if (File.Exists(LogFile) && new FileInfo(LogFile).Length > 100 * 1024) File.Delete(LogFile);
        File.AppendAllText(LogFile, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + text + "\r\n");
      } catch { }
    }
  }
}
