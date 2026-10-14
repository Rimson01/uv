using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

// Read only: discovers actual Material ID labels. All writes use documented Unwrap API.
public static class LSYUVFilterBridgeV0112 {
    delegate bool EnumProc(IntPtr hwnd, IntPtr param);
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr param);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr hwnd, EnumProc proc, IntPtr param);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr a, IntPtr b);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr a, StringBuilder b);
    public static long[] Find(int x,int y,int w,int h,int[] ids) {
        var matches = new List<long[]>();
        uint process = (uint)System.Diagnostics.Process.GetCurrentProcess().Id;
        EnumWindows(delegate(IntPtr window,IntPtr arg) {
            uint pid; GetWindowThreadProcessId(window,out pid);
            if(pid!=process) return true;
            Rect r; if(!GetWindowRect(window,out r)) return true;
            // Match dropdown contents, not cached editor bounds (DPI/window state changes them).
            EnumChildWindows(window,delegate(IntPtr child,IntPtr ignored) {
                var type=new StringBuilder(256); GetClassName(child,type,256);
                if(type.ToString().IndexOf("combo",StringComparison.OrdinalIgnoreCase)<0) return true;
                int count=SendMessage(child,0x146,IntPtr.Zero,IntPtr.Zero).ToInt32();
                if(count!=ids.Length+1) return true;
                var slots=new Dictionary<int,int>();
                for(int i=1;i<count;i++) {
                    int length=SendMessage(child,0x149,new IntPtr(i),IntPtr.Zero).ToInt32();
                    if(length<0 || length>1024) return true;
                    var label=new StringBuilder(length+1);
                    SendMessage(child,0x148,new IntPtr(i),label);
                    var numbers=Regex.Matches(label.ToString(),@"\d+");
                    int id;
                    if(numbers.Count!=1 || !Int32.TryParse(numbers[0].Value,out id) || Array.IndexOf(ids,id)<0 || slots.ContainsKey(id)) return true;
                    slots.Add(id,i);
                }
                var result=new long[ids.Length+2]; result[0]=child.ToInt64();
                result[1]=SendMessage(child,0x147,IntPtr.Zero,IntPtr.Zero).ToInt64();
                for(int i=0;i<ids.Length;i++) result[i+2]=slots[ids[i]];
                matches.Add(result); return true;
            },IntPtr.Zero);
            return true;
        },IntPtr.Zero);
        if(matches.Count!=1) throw new InvalidOperationException("Cannot uniquely read the UV Editor Material ID dropdown. Open the native Editor; current filter preserved.");
        return matches[0];
    }
    public static long[] Maps(string[] names,int apiCurrent) {
        var matches=new List<long[]>();
        uint process=(uint)System.Diagnostics.Process.GetCurrentProcess().Id;
        EnumWindows(delegate(IntPtr window,IntPtr arg) {
            uint pid; GetWindowThreadProcessId(window,out pid); if(pid!=process) return true;
            EnumChildWindows(window,delegate(IntPtr child,IntPtr ignored) {
                var type=new StringBuilder(256); GetClassName(child,type,256);
                if(type.ToString().IndexOf("combo",StringComparison.OrdinalIgnoreCase)<0) return true;
                int count=SendMessage(child,0x146,IntPtr.Zero,IntPtr.Zero).ToInt32();
                if(count<1 || count>names.Length+3) return true;
                int selected=Selected(child.ToInt64());
                int offset=apiCurrent==selected ? 0 : apiCurrent==selected+1 ? 1 : -1;
                if(offset<0) return true;
                var result=new long[names.Length]; int found=0;
                for(int i=0;i<count;i++) {
                    int length=SendMessage(child,0x149,new IntPtr(i),IntPtr.Zero).ToInt32();
                    if(length<0 || length>2048) return true;
                    var text=new StringBuilder(length+1); SendMessage(child,0x148,new IntPtr(i),text);
                    string label=text.ToString().Trim(); int match=-1;
                    for(int j=0;j<names.Length;j++) {
                        string name=names[j];
                        if(String.IsNullOrEmpty(name)) continue;
                        if(label.Equals(name,StringComparison.OrdinalIgnoreCase) ||
                            (label.StartsWith(name,StringComparison.OrdinalIgnoreCase) && label.Length>name.Length && !Char.IsLetterOrDigit(label[name.Length]))) {
                            if(match>=0) return true;
                            match=j;
                        }
                    }
                    if(match>=0) {
                        if(result[match]!=0 || i+offset<1) return true;
                        result[match]=i+offset; found++;
                    }
                }
                if(found>0) matches.Add(result);
                return true;
            },IntPtr.Zero); return true;
        },IntPtr.Zero);
        if(matches.Count!=1) throw new InvalidOperationException("Cannot uniquely read native texture dropdown; current background preserved.");
        return matches[0];
    }
    public static int Selected(long hwnd) {
        return SendMessage(new IntPtr(hwnd),0x147,IntPtr.Zero,IntPtr.Zero).ToInt32();
    }
}
