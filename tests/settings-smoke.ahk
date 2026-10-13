#Requires AutoHotkey v2.0
#Include ../settings.ahk
try {
    Assert(LocaleId("ar-SY") = 0x2801, "Syrian Arabic")
    Assert(LocaleId("ar-EG") = 0x0C01, "Egyptian Arabic")
    Assert(LocaleId("tr-TR") = 0x041F, "Turkish")
    Assert(LocaleId("041F") = 0x041F, "Hex LANGID")
    Assert(!LocaleId("not-a-language"), "Unknown locale")
    entries := [{Tag: "ar-SY", Key: "A", Label: "العربية"}, {Tag: "tr-TR", Key: "T", Label: "Türkçe"}]
    ValidateSettings("AltShift", "14271F", "FFFFFF", entries)
    rejected := false
    try ValidateSettings("AltShift", "oops", "FFFFFF", entries)
    catch
        rejected := true
    Assert(rejected, "Invalid color rejected")
    rejected := false
    try ValidateSettings("AltShift", "14271F", "FFFFFF", [entries[1], entries[1]])
    catch
        rejected := true
    Assert(rejected, "Duplicate key rejected")
    languageSettings := {Mode: "AltShift", Color: "14271F", TextColor: "FFFFFF", Entries: entries}
    registeredKeys := [], settingsWindow := 0
    languageBadge := Gui()
    languageBadgeText := languageBadge.AddText(, "Test")
    ApplySettings()
    languageSettings.Mode := "WinSpace"
    ApplySettings()
    Assert(registeredKeys.Length = 3, "WinSpace bindings")
    languageSettings.Mode := "AltShift"
    ApplySettings()
    Assert(registeredKeys.Length = 2, "AltShift bindings restored")
    OpenSettings()
    Assert(IsObject(settingsWindow), "Settings window created")
    settingsWindow.Destroy()
    testPath := A_Temp "\language-settings-test-" DllCall("GetCurrentProcessId") ".ini"
    try {
        WriteSettings(testPath, "WinSpace", "123456", "ABCDEF", entries)
        Assert(IniRead(testPath, "Appearance", "Mode") = "WinSpace", "Saved mode")
        Assert(IniRead(testPath, "Language1", "Label") = "العربية", "Unicode round trip")
        Assert(IniRead(testPath, "Language2", "Tag") = "tr-TR", "Saved language")
        WriteSettings(testPath, "AltShift", "14271F", "FFFFFF", [entries[1]])
        Assert(IniRead(testPath, "Languages", "Count") = 1, "Deleted rows stay deleted")
        Assert(IniRead(testPath, "Language2", "Tag", "absent") = "absent", "No stale sections")
    } finally {
        if FileExist(testPath)
            FileDelete(testPath)
    }
    FileAppend("PASS: locale resolution, validation, both hotkey modes, settings GUI, Unicode save/load`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message " at " err.Line "`n", "*")
    ExitApp(1)
}
Assert(value, message) {
    if !value
        throw Error(message)
}
SwitchKeyboardLayout(*) {
}
