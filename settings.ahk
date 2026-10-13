; Settings are stored beside the script, never in the repository.
LocaleId(tag) {
    if RegExMatch(tag, "i)^[0-9a-f]{4}$")
        return Integer("0x" tag)
    id := DllCall("LocaleNameToLCID", "Str", tag, "UInt", 0, "UInt") & 0xFFFF
    ; Custom/unspecified locales cannot identify an installed keyboard profile.
    return id = 0x1000 || id = 0x007F ? 0 : id
}

InitSettings() {
    global languageSettings, settingsPath, registeredKeys, settingsWindow
    settingsPath := A_ScriptDir "\settings.ini"
    registeredKeys := [], settingsWindow := 0
    languageSettings := {Mode: "AltShift", Color: "14271F", TextColor: "FFFFFF", Entries: [
        {Tag: "ar-SY", Key: "A", Label: "العربية"},
        {Tag: "tr-TR", Key: "T", Label: "Türkçe"},
        {Tag: "tr-TR", Key: "E", Label: "Türkçe"}]}
    if FileExist(settingsPath) {
        try {
            mode := IniRead(settingsPath, "Appearance", "Mode", "AltShift")
            color := IniRead(settingsPath, "Appearance", "Color", "14271F")
            textColor := IniRead(settingsPath, "Appearance", "TextColor", "FFFFFF")
            entries := []
            count := Integer(IniRead(settingsPath, "Languages", "Count", 0))
            if count < 1 || count > 50
                throw Error("عدد اللغات غير صالح")
            Loop count {
                section := "Language" A_Index
                entries.Push({Tag: IniRead(settingsPath, section, "Tag"), Key: IniRead(settingsPath, section, "Key"), Label: IniRead(settingsPath, section, "Label")})
            }
            ValidateSettings(mode, color, textColor, entries)
            languageSettings := {Mode: mode, Color: color, TextColor: textColor, Entries: entries}
        } catch as err {
            MsgBox("تعذر قراءة الإعدادات. ستُستخدم الإعدادات الافتراضية.`n" err.Message)
        }
    }
    ApplySettings()
    A_TrayMenu.Add("إعدادات اللغة / Settings", OpenSettings)
    A_TrayMenu.Default := "إعدادات اللغة / Settings"
    if !FileExist(settingsPath)
        SetTimer(OpenSettings, -300)
}

WinSpaceHeld(*) {
    return GetKeyState("Space", "P")
}

ApplySettings() {
    global registeredKeys, languageSettings, languageBadge, languageBadgeText
    for item in registeredKeys {
        HotIf(item.Context)
        Hotkey(item.Name, "Off")
    }
    registeredKeys := []
    HotIf()
    if languageSettings.Mode = "WinSpace" {
        ; Reserve Win+Space so Windows does not cycle before the letter arrives.
        Hotkey("#Space", (*) => 0, "On")
        registeredKeys.Push({Name: "#Space", Context: ""})
        HotIf(WinSpaceHeld)
    }
    for entry in languageSettings.Entries {
        name := (languageSettings.Mode = "WinSpace" ? "#" : "!+") StrLower(entry.Key)
        Hotkey(name, SelectLanguage.Bind(entry.Tag), "On")
        registeredKeys.Push({Name: name, Context: languageSettings.Mode = "WinSpace" ? WinSpaceHeld : ""})
    }
    HotIf()
    languageBadge.BackColor := languageSettings.Color
    languageBadgeText.SetFont("c" languageSettings.TextColor)
}

SelectLanguage(tag, *) {
    SwitchKeyboardLayout(tag)
}

WriteSettings(path, m, bg, fg, entries) {
    ValidateSettings(m, bg, fg, entries)
    pending := path ".tmp"
    if FileExist(pending)
        FileDelete(pending)
    IniWrite(m, pending, "Appearance", "Mode")
    IniWrite(bg, pending, "Appearance", "Color")
    IniWrite(fg, pending, "Appearance", "TextColor")
    IniWrite(entries.Length, pending, "Languages", "Count")
    for entry in entries {
        section := "Language" A_Index
        IniWrite(entry.Tag, pending, section, "Tag")
        IniWrite(entry.Key, pending, section, "Key")
        IniWrite(entry.Label, pending, section, "Label")
    }
    FileMove(pending, path, 1)
}

ValidateSettings(mode, color, textColor, entries) {
    if mode != "AltShift" && mode != "WinSpace"
        throw Error("نوع الاختصار غير صالح")
    if !RegExMatch(color, "i)^[0-9a-f]{6}$") || !RegExMatch(textColor, "i)^[0-9a-f]{6}$")
        throw Error("اللون يجب أن يتكون من ست خانات، مثال: 14271F")
    if !entries.Length
        throw Error("أضف لغة واحدة على الأقل")
    used := Map()
    for entry in entries {
        if !RegExMatch(entry.Key, "i)^[a-z]$")
            throw Error("الاختصار حرف لاتيني واحد من A إلى Z")
        key := StrUpper(entry.Key)
        if used.Has(key)
            throw Error("الحرف مكرر: " key)
        used[key] := true
        if !LocaleId(entry.Tag)
            throw Error("رمز اللغة غير معروف لويندوز: " entry.Tag)
        if !Trim(entry.Label) || StrLen(entry.Label) > 16 || InStr(entry.Label, "`n")
            throw Error("اسم المؤشر يجب أن يكون بين حرف و16 حرفاً")
    }
}

OpenSettings(*) {
    global settingsWindow, languageSettings
    if IsObject(settingsWindow) {
        settingsWindow.Show()
        return
    }
    g := Gui(, "إعدادات مؤشر اللغة — Keyboard Language Hotkeys")
    settingsWindow := g
    g.SetFont("s10", "Segoe UI")
    g.AddText("xm w620 Right", "اختر الاختصار، ثم أضف اللغات والحرف المخصص لكل لغة")
    mode := g.AddDropDownList("xm w300 Choose" (languageSettings.Mode = "AltShift" ? 1 : 2), ["Alt + Shift + حرف", "Win + Space + حرف"])
    g.AddText("xm w620 Right", "في وضع Win+Space: اضغط ويندوز ثم المسطرة، وأبقِهما مضغوطين واضغط الحرف. يُحجز Win+Space للبرنامج.")
    g.AddText("xm", "لون الخلفية HEX")
    color := g.AddEdit("x+12 w100", languageSettings.Color)
    g.AddText("x+20", "لون النص HEX")
    textColor := g.AddEdit("x+12 w100", languageSettings.TextColor)
    preview := g.AddText("xm w260 h35 Center +0x200 Background" languageSettings.Color, "العربية / Türkçe")
    preview.SetFont("c" languageSettings.TextColor)
    g.AddButton("x+15 w120", "معاينة اللون").OnEvent("Click", PreviewColors)
    lv := g.AddListView("xm w620 r7", ["رمز اللغة", "الحرف", "اسم المؤشر"])
    for entry in languageSettings.Entries
        lv.Add(, entry.Tag, entry.Key, entry.Label)
    lv.ModifyCol(1, 210), lv.ModifyCol(2, 100), lv.ModifyCol(3, 270)
    presets := ["ar-SY", "en-US", "tr-TR", "fr-FR", "de-DE", "es-ES", "ar-EG", "ar-SA", "ar-AE", "ar-JO", "ar-LB", "ar-IQ", "ar-MA", "ar-DZ", "ar-TN", "ar-KW", "ar-QA", "ar-BH", "ar-OM", "ar-YE", "ar-LY"]
    names := ["العربية — سوريا", "English — US", "Türkçe", "Français", "Deutsch", "Español", "العربية — مصر", "العربية — السعودية", "العربية — الإمارات", "العربية — الأردن", "العربية — لبنان", "العربية — العراق", "العربية — المغرب", "العربية — الجزائر", "العربية — تونس", "العربية — الكويت", "العربية — قطر", "العربية — البحرين", "العربية — عمان", "العربية — اليمن", "العربية — ليبيا"]
    preset := g.AddDropDownList("xm w310 Choose1", names)
    g.AddButton("x+10 w150", "استخدام المثال").OnEvent("Click", UsePreset)
    g.AddText("xm", "رمز اللغة (مثل ar-EG)")
    tag := g.AddEdit("x+10 w110", "ar-SY")
    g.AddText("x+15", "الحرف")
    letter := g.AddEdit("x+10 w45 Limit1", "A")
    g.AddText("xm", "الاسم الذي يظهر")
    label := g.AddEdit("x+10 w220", "العربية")
    g.AddButton("xm w145", "إضافة لغة").OnEvent("Click", AddEntry)
    g.AddButton("x+10 w145", "تعديل المحدد").OnEvent("Click", UpdateEntry)
    g.AddButton("x+10 w145", "حذف المحدد").OnEvent("Click", DeleteEntry)
    lv.OnEvent("ItemSelect", ReadEntry)
    g.AddText("xm w620 Right", "هذه القائمة تحدد اختصارات البرنامج فقط. يجب تثبيت اللغات في Windows. يمكنك إدخال رمز آخر أو LANGID من أربع خانات سداسية.")
    g.AddButton("xm w190", "إعدادات لغة Windows").OnEvent("Click", (*) => Run("ms-settings:regionlanguage"))
    g.AddButton("x+10 w190 Default", "حفظ وتطبيق").OnEvent("Click", Save)
    g.AddButton("x+10 w150", "إغلاق").OnEvent("Click", Close)
    g.OnEvent("Close", Close)
    g.Show()

    Close(*) {
        global settingsWindow
        g.Destroy()
        settingsWindow := 0
    }
    PreviewColors(*) {
        bg := LTrim(Trim(color.Value), "#"), fg := LTrim(Trim(textColor.Value), "#")
        if RegExMatch(bg, "i)^[0-9a-f]{6}$") && RegExMatch(fg, "i)^[0-9a-f]{6}$") {
            preview.Opt("Background" bg)
            preview.SetFont("c" fg)
            preview.Redraw()
        } else
            MsgBox("اكتب ست خانات لكل لون، مثل 14271F وFFFFFF")
    }
    UsePreset(*) {
        tag.Value := presets[preset.Value]
        label.Value := StrSplit(names[preset.Value], " — ")[1]
    }
    ReadEntry(control, row, selected) {
        if selected {
            tag.Value := lv.GetText(row, 1)
            letter.Value := lv.GetText(row, 2)
            label.Value := lv.GetText(row, 3)
        }
    }
    AddEntry(*) {
        lv.Add(, Trim(tag.Value), StrUpper(Trim(letter.Value)), Trim(label.Value))
    }
    UpdateEntry(*) {
        row := lv.GetNext()
        if row
            lv.Modify(row, , Trim(tag.Value), StrUpper(Trim(letter.Value)), Trim(label.Value))
    }
    DeleteEntry(*) {
        row := lv.GetNext()
        if row
            lv.Delete(row)
    }
    Save(*) {
        global settingsPath, languageSettings
        entries := []
        Loop lv.GetCount()
            entries.Push({Tag: lv.GetText(A_Index, 1), Key: lv.GetText(A_Index, 2), Label: lv.GetText(A_Index, 3)})
        m := mode.Value = 1 ? "AltShift" : "WinSpace"
        bg := LTrim(Trim(color.Value), "#"), fg := LTrim(Trim(textColor.Value), "#")
        try {
            WriteSettings(settingsPath, m, bg, fg, entries)
            languageSettings := {Mode: m, Color: bg, TextColor: fg, Entries: entries}
            ApplySettings()
            MsgBox("تم حفظ الإعدادات وتطبيقها.")
        } catch as err {
            MsgBox(err.Message, "تعذر الحفظ")
        }
    }
}
