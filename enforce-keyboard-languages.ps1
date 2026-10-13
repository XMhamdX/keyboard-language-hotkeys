$languageList = Get-WinUserLanguageList
$changed = $false

# Remove the English (United States) language entry if Windows adds it again.
@($languageList | Where-Object { $_.LanguageTag -like 'en-*' -or $_.LanguageTag -eq 'ar-SA' }) | ForEach-Object {
    [void]$languageList.Remove($_)
    $changed = $true
}

# Also remove the US keyboard if it is attached to another language entry.
foreach ($language in @($languageList)) {
    @($language.InputMethodTips | Where-Object { $_ -match ':00000409$' }) | ForEach-Object {
        [void]$language.InputMethodTips.Remove($_)
        $changed = $true
    }
}

if ($changed) {
    Set-WinUserLanguageList $languageList -Force
}

# Phantom layouts can remain loaded even when absent from the saved list.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class KeyboardProfileCleanup {
 [DllImport("user32.dll")] public static extern int GetKeyboardLayoutList(int n, [Out] IntPtr[] list);
 [DllImport("user32.dll")] public static extern bool UnloadKeyboardLayout(IntPtr hkl);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wp, IntPtr lp);
}
'@
$count = [KeyboardProfileCleanup]::GetKeyboardLayoutList(0, $null)
$handles = New-Object IntPtr[] $count
[void][KeyboardProfileCleanup]::GetKeyboardLayoutList($count, $handles)
$arabic = $handles | Where-Object { ($_.ToInt64() -band 0xFFFF) -eq 0x2801 } | Select-Object -First 1
$extra = @($handles | Where-Object {
    $lang = $_.ToInt64() -band 0xFFFF
    $lang -eq 0x0401 -or ($lang -band 0x3FF) -eq 9
})
if ($arabic -and $extra.Count -gt 0) {
    # Release unwanted layouts in applications before unloading them.
    [void][KeyboardProfileCleanup]::PostMessage([IntPtr]0xFFFF, 0x50, [IntPtr]::Zero, $arabic)
    Start-Sleep -Milliseconds 300
    foreach ($layout in $extra) {
        [void][KeyboardProfileCleanup]::UnloadKeyboardLayout($layout)
    }
}
