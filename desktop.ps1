param([Parameter(Mandatory=$true)][string]$Payload)
$ErrorActionPreference = 'Stop'
$request = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Payload)) | ConvertFrom-Json
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class DesktopNative {
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public UNION u; }
 [StructLayout(LayoutKind.Explicit)] public struct UNION { [FieldOffset(0)] public KEYBDINPUT k; [FieldOffset(0)] public MOUSEINPUT m; }
 [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public UIntPtr extra; }
 [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int x,y; public uint data, flags, time; public UIntPtr extra; }
 [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
 public static void TypeText(string text) {
  foreach(char c in text) {
   INPUT down = new INPUT(); down.type=1; down.u.k.scan=c; down.u.k.flags=4;
   INPUT up=down; up.u.k.flags=6;
   if(SendInput(2, new INPUT[]{down,up}, Marshal.SizeOf(typeof(INPUT))) != 2) throw new Exception("Windows rejected keyboard input; check application elevation.");
  }
 }
}
'@
[void][DesktopNative]::SetProcessDPIAware()
switch ($request.action) {
 'list_windows' {
  $items = [Collections.Generic.List[object]]::new()
  $cb = [DesktopNative+EnumProc]{ param($h,$p)
   if ([DesktopNative]::IsWindowVisible($h)) {
    $s = [Text.StringBuilder]::new(1024)
    [void][DesktopNative]::GetWindowText($h,$s,1024)
    if ($s.Length -gt 0) { $items.Add(@{handle=$h.ToInt64().ToString(); title=$s.ToString()}) }
   }
   return $true
  }
  [void][DesktopNative]::EnumWindows($cb,[IntPtr]::Zero)
  @{windows=@($items.ToArray())} | ConvertTo-Json -Depth 4 -Compress
 }
 'screenshot' {
  $r = [Windows.Forms.SystemInformation]::VirtualScreen
  $b = [Drawing.Bitmap]::new($r.Width,$r.Height)
  $g = [Drawing.Graphics]::FromImage($b)
  $m = [IO.MemoryStream]::new()
  try {
   $g.CopyFromScreen($r.Left,$r.Top,0,0,$r.Size)
   $b.Save($m,[Drawing.Imaging.ImageFormat]::Png)
   @{bounds=@{x=$r.Left;y=$r.Top;width=$r.Width;height=$r.Height};image=[Convert]::ToBase64String($m.ToArray())} | ConvertTo-Json -Compress
  } finally { $g.Dispose();$b.Dispose();$m.Dispose() }
 }
 'focus_window' {
  $h = [IntPtr]([long]$request.handle)
  if (-not [DesktopNative]::IsWindowVisible($h)) { throw 'Window no longer visible; list windows again.' }
  [void][DesktopNative]::ShowWindow($h,9)
  [void][DesktopNative]::SetForegroundWindow($h)
  if ([DesktopNative]::GetForegroundWindow() -ne $h) { throw 'Windows refused foreground focus.' }
  '{"ok":true}'
 }
 'click' {
  $r = [Windows.Forms.SystemInformation]::VirtualScreen
  if (-not $r.Contains([int]$request.x,[int]$request.y)) { throw 'Coordinates outside virtual desktop.' }
  if (-not [DesktopNative]::SetCursorPos($request.x,$request.y)) { throw 'Cursor movement failed.' }
  if ($request.button -eq 'right') { $down=8;$up=16 } else { $down=2;$up=4 }
  [DesktopNative]::mouse_event($down,0,0,0,[UIntPtr]::Zero)
  [DesktopNative]::mouse_event($up,0,0,0,[UIntPtr]::Zero)
  '{"ok":true}'
 }
 'type_text' { [DesktopNative]::TypeText($request.text); '{"ok":true}' }
 'press_key' {
  $keys=@{ENTER='{ENTER}';TAB='{TAB}';ESC='{ESC}';BACKSPACE='{BACKSPACE}';DELETE='{DELETE}';UP='{UP}';DOWN='{DOWN}';LEFT='{LEFT}';RIGHT='{RIGHT}';HOME='{HOME}';END='{END}';'CTRL+A'='^a';'CTRL+C'='^c';'CTRL+V'='^v';'CTRL+Z'='^z';'ALT+F4'='%{F4}'}
  if (-not $keys.ContainsKey($request.key)) { throw 'Unsupported key.' }
  [Windows.Forms.SendKeys]::SendWait($keys[$request.key]); '{"ok":true}'
 }
 default { throw 'Unknown action.' }
}
