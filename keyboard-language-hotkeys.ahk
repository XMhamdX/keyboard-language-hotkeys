#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
#Include settings.ahk
CoordMode("Caret", "Screen")
CoordMode("Mouse", "Screen")

languageBadge := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
languageBadge.BackColor := "14271F"
languageBadge.MarginX := 14
languageBadge.MarginY := 8
languageBadge.SetFont("s14 Bold", "Segoe UI")
languageBadgeText := languageBadge.AddText("cFFFFFF Center w145 h30", "")

InitSettings()
; Language removal is no longer automatic: users may select any installed language.

taskbarSearchBounds := []
taskbarSearchPressed := false
SetTimer(RefreshTaskbarSearchBounds, -12000)
SetTimer(RefreshTaskbarSearchBounds, 30000)

SwitchKeyboardLayout(layoutId) {
    ; Select an installed language profile by Windows locale name or LANGID.
    wanted := LocaleId(layoutId)
    count := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0)
    layouts := Buffer(count * A_PtrSize)
    DllCall("GetKeyboardLayoutList", "Int", count, "Ptr", layouts)
    hkl := 0
    Loop count {
        candidate := NumGet(layouts, (A_Index - 1) * A_PtrSize, "Ptr")
        if (candidate & 0xFFFF) = wanted {
            hkl := candidate
            break
        }
    }
    if !hkl {
        TrayTip("أضف اللغة من إعدادات لغة Windows أولاً: " layoutId, "اللغة غير مثبتة")
        return
    }

    activeWindow := WinExist("A")
    if activeWindow {
        ; WM_INPUTLANGCHANGEREQUEST: apply the selected layout to the focused window.
        PostMessage(0x50, 0, hkl, , "ahk_id " activeWindow)
        SetTimer(ShowLanguageBadge, -80)
    }
}


; Capture the taskbar Search button before Windows replaces it with SearchHost.
~LButton::RecordMouseDownTarget()

; Pass the click through normally, then inspect the newly focused app.
~LButton Up::SetTimer(ShowLanguageBadgeAfterClick, -80)

ShowLanguageBadgeAfterClick() {
    global taskbarSearchPressed
    if taskbarSearchPressed || IsTaskbarSearchClick() {
        taskbarSearchPressed := false
        SetTimer(RetryWritingTarget, 0)
        SetTimer(ShowTaskbarSearchBadge, -420)
        return
    }
    if IsWritingTarget() {
        if GetFocusedSearchRect(&searchLeft, &searchTop, &searchRight, &searchBottom)
            ShowTaskbarSearchBadge()
        else
            ShowLanguageBadge()
    }
    else {
        HideLanguageBadge()
        ; Explorer may create its address editor after the first focus update.
        SetTimer(RetryWritingTarget, -160)
    }
}

RecordMouseDownTarget() {
    global taskbarSearchPressed
    taskbarSearchPressed := IsTaskbarSearchPoint()
}

ShowTaskbarSearchBadge() {
    DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    if GetFocusedSearchRect(&left, &top, &right, &bottom) {
        GetSearchBadgePosition(left, top, right, bottom, &x, &y)
        ShowLanguageBadge(false, x, y)
    } else {
        ; Avoid placing a fallback inside the Search popup while it opens.
        SetTimer(RetrySearchBadge, -150)
    }
}

RetrySearchBadge() {
    if GetFocusedSearchRect(&left, &top, &right, &bottom) {
        GetSearchBadgePosition(left, top, right, bottom, &x, &y)
        ShowLanguageBadge(false, x, y)
    }
}

GetSearchBadgePosition(fieldLeft, fieldTop, fieldRight, fieldBottom, &x, &y) {
    popupLeft := fieldLeft, popupTop := fieldTop
    popupRight := fieldRight, popupBottom := fieldBottom
    if GetSearchPopupRect(&panelLeft, &panelTop, &panelRight, &panelBottom) {
        popupLeft := panelLeft, popupTop := panelTop
        popupRight := panelRight, popupBottom := panelBottom
    }
    smallestArea := 0
    for window in WinGetList("ahk_exe SearchHost.exe") {
        if !DllCall("IsWindowVisible", "Ptr", window)
            continue
        rect := Buffer(16, 0)
        if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", window, "UInt", 9, "Ptr", rect, "UInt", 16, "Int") != 0
            continue
        l := NumGet(rect, 0, "Int"), t := NumGet(rect, 4, "Int")
        r := NumGet(rect, 8, "Int"), b := NumGet(rect, 12, "Int")
        area := (r - l) * (b - t)
        if l <= fieldLeft && t <= fieldTop && r >= fieldRight && b >= fieldBottom && area > 0 && (!smallestArea || area < smallestArea) {
            popupLeft := l, popupTop := t, popupRight := r, popupBottom := b
            smallestArea := area
        }
    }
    midX := (fieldLeft + fieldRight) // 2
    midY := (fieldTop + fieldBottom) // 2
    MonitorGetWorkArea(MonitorGetPrimary(), &workLeft, &workTop, &workRight, &workBottom)
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if midX >= l && midX < r && midY >= t && midY < b {
            workLeft := l, workTop := t, workRight := r, workBottom := b
            break
        }
    }
    ; Keep the whole badge clear of the shell popup, with an 8-pixel gap.
    if popupRight + 181 <= workRight {
        x := popupRight + 8
        y := Max(workTop + 4, Min(fieldTop, workBottom - 50))
    } else if popupLeft - 181 >= workLeft {
        x := popupLeft - 181
        y := Max(workTop + 4, Min(fieldTop, workBottom - 50))
    } else if popupTop - 54 >= workTop {
        x := Max(workLeft + 4, Min(fieldRight - 173, workRight - 177))
        y := popupTop - 54
    } else {
        x := Max(workLeft + 4, Min(fieldRight - 173, workRight - 177))
        y := popupBottom + 8
    }
}

GetSearchPopupRect(&left, &top, &right, &bottom) {
    element := 0, walker := 0
    found := false
    try {
        static automation := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        ComCall(8, automation, "Ptr*", &element)
        if !element
            return false
        processId := UIAInt(element, 30002)
        if !processId || ProcessGetName(processId) != "SearchHost.exe"
            return false
        ComCall(14, automation, "Ptr*", &walker)
        Loop 6 {
            parent := 0
            ComCall(3, walker, "Ptr", element, "Ptr*", &parent)
            ObjRelease(element)
            element := parent
            if !element || UIAInt(element, 30002) != processId
                break
            rect := Buffer(16, 0)
            ComCall(43, element, "Ptr", rect)
            left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
            right := NumGet(rect, 8, "Int"), bottom := NumGet(rect, 12, "Int")
            found := right > left && bottom > top
        }
        return found
    } catch {
        return false
    } finally {
        if element
            ObjRelease(element)
        if walker
            ObjRelease(walker)
    }
}

GetFocusedSearchRect(&left, &top, &right, &bottom) {
    element := 0
    try {
        static automation := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        ComCall(8, automation, "Ptr*", &element)
        if !element
            return false
        processId := UIAInt(element, 30002)
        processName := processId ? ProcessGetName(processId) : ""
        automationId := UIAString(element, 30011)
        className := UIAString(element, 30012)
        if processName != "SearchHost.exe" || (automationId != "SearchTextBox" && className != "RichEditBox")
            return false
        rect := Buffer(16, 0)
        ComCall(43, element, "Ptr", rect)
        left := NumGet(rect, 0, "Int")
        top := NumGet(rect, 4, "Int")
        right := NumGet(rect, 8, "Int")
        bottom := NumGet(rect, 12, "Int")
        return right > left && bottom > top
    } catch {
        return false
    } finally {
        if element
            ObjRelease(element)
    }
}

IsTaskbarSearchPoint() {
    element := 0
    walker := 0
    try {
        static automation := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        point := Buffer(8, 0)
        if !DllCall("GetPhysicalCursorPos", "Ptr", point)
            return false
        x := NumGet(point, 0, "Int")
        y := NumGet(point, 4, "Int")
        ComCall(7, automation, "Int64", (x & 0xFFFFFFFF) | (y << 32), "Ptr*", &element)
        ComCall(14, automation, "Ptr*", &walker)
        Loop 6 {
            if !element
                break
            automationId := UIAString(element, 30011)
            if automationId = "SearchButton" || automationId = "SearchBoxTextBlock"
                return true
            parent := 0
            ComCall(3, walker, "Ptr", element, "Ptr*", &parent)
            ObjRelease(element)
            element := parent
        }
        return false
    } catch {
        return false
    } finally {
        if element
            ObjRelease(element)
        if walker
            ObjRelease(walker)
    }
}

RefreshTaskbarSearchBounds() {
    global taskbarSearchBounds
    fresh := []
    root := 0, condition := 0, elements := 0
    try {
        static automation := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        taskbar := WinExist("ahk_class Shell_TrayWnd")
        if !taskbar
            return
        ComCall(6, automation, "Ptr", taskbar, "Ptr*", &root)
        ComCall(21, automation, "Ptr*", &condition)
        ComCall(6, root, "Int", 4, "Ptr", condition, "Ptr*", &elements)
        count := 0
        ComCall(3, elements, "Int*", &count)
        Loop count {
            element := 0
            ComCall(4, elements, "Int", A_Index - 1, "Ptr*", &element)
            try {
                if UIAString(element, 30011) = "SearchButton" {
                    rect := Buffer(16, 0)
                    ComCall(43, element, "Ptr", rect)
                    fresh.Push([NumGet(rect, 0, "Int"), NumGet(rect, 4, "Int"), NumGet(rect, 8, "Int"), NumGet(rect, 12, "Int")])
                }
            } finally {
                ObjRelease(element)
            }
        }
        taskbarSearchBounds := fresh
    } catch {
        return
    } finally {
        if elements
            ObjRelease(elements)
        if condition
            ObjRelease(condition)
        if root
            ObjRelease(root)
    }
}

IsTaskbarSearchClick() {
    global taskbarSearchBounds
    DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    MouseGetPos(&x, &y, &window)
    try {
        processName := WinGetProcessName("ahk_id " window)
        if !RegExMatch(processName, "i)^(explorer|SearchHost)\.exe$")
            return false
        for rect in taskbarSearchBounds {
            if x >= rect[1] && y >= rect[2] && x < rect[3] && y < rect[4]
                return true
        }
    }
    return false
}

RetryWritingTarget() {
    if IsWritingTarget() {
        if GetFocusedSearchRect(&left, &top, &right, &bottom)
            ShowTaskbarSearchBadge()
        else
            ShowLanguageBadge()
    }
}

IsWritingTarget() {
    ; UI Automation returns physical pixels. Match that coordinate system on
    ; scaled displays before comparing mouse positions with element bounds.
    DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    ; A text-shaped pointer alone also occurs over non-editable web text.
    if A_Cursor = "IBeam" && CaretGetPos(&cx, &cy)
        return true

    MouseGetPos(&mx, &my, &window, &control, 2)
    if !window
        return false
    try {
        className := WinGetClass("ahk_id " (control ? control : window))
        if RegExMatch(className, "i)^(Edit|RichEdit)") {
            ; ES_READONLY means selectable text, not an input field.
            return !(WinGetStyle("ahk_id " (control ? control : window)) & 0x800)
        }
        if className = "ConsoleWindowClass" {
            ; Only the console client area, excluding its title bar and frame.
            WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " window)
            return mx >= clientX && mx < clientX + clientW && my >= clientY && my < clientY + clientH
        }
    }

    ; Modern Explorer exposes the focused editor beneath a XAML wrapper.
    ; Require the pointer inside its bounds so stale focus cannot trigger it.
    element := 0
    try {
        static automation := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        if IsSpecialWritingSurface(automation, mx, my, window)
            return true
        ComCall(8, automation, "Ptr*", &element)
        if !element
            return false
        rect := Buffer(16, 0)
        ComCall(43, element, "Ptr", rect)
        if mx < NumGet(rect, 0, "Int") || my < NumGet(rect, 4, "Int") || mx >= NumGet(rect, 8, "Int") || my >= NumGet(rect, 12, "Int")
            return false
        value := Buffer(24, 0)
        ; UIA_ControlTypePropertyId: Edit = 50004.
        ComCall(10, element, "Int", 30003, "Ptr", value)
        kind := NumGet(value, 8, "Int")
        DllCall("oleaut32\VariantClear", "Ptr", value)
        ; Windows Terminal exposes its focused text surface as a Document.
        ; The bounding rectangle above excludes its tabs and toolbar.
        processName := WinGetProcessName("ahk_id " window)
        if kind = 50030 && RegExMatch(processName, "i)^(WindowsTerminal|OpenConsole|conhost)\.exe$")
            return true
        ; Editable combo boxes can also represent Explorer's address field.
        if kind != 50004 && kind != 50003
            return false
        ; UIA_ValueIsReadOnlyPropertyId.
        ComCall(10, element, "Int", 30046, "Ptr", value)
        hasReadOnlyValue := NumGet(value, 0, "UShort") = 11
        readOnly := hasReadOnlyValue && NumGet(value, 8, "Short") != 0
        DllCall("oleaut32\VariantClear", "Ptr", value)
        return !readOnly && (kind = 50004 || hasReadOnlyValue)
    } catch {
        return false
    } finally {
        if element
            ObjRelease(element)
    }
}

UIAString(element, propertyId) {
    value := Buffer(24, 0)
    ComCall(10, element, "Int", propertyId, "Ptr", value)
    result := NumGet(value, 0, "UShort") = 8 ? StrGet(NumGet(value, 8, "Ptr")) : ""
    DllCall("oleaut32\VariantClear", "Ptr", value)
    return result
}

UIAInt(element, propertyId) {
    value := Buffer(24, 0)
    ComCall(10, element, "Int", propertyId, "Ptr", value)
    result := NumGet(value, 0, "UShort") = 3 ? NumGet(value, 8, "Int") : 0
    DllCall("oleaut32\VariantClear", "Ptr", value)
    return result
}

IsSpecialWritingSurface(automation, x, y, window) {
    element := 0
    walker := 0
    try {
        processName := WinGetProcessName("ahk_id " window)
        if !RegExMatch(processName, "i)^(WindowsTerminal|explorer|SearchHost)\.exe$")
            return false
        ComCall(7, automation, "Int64", (x & 0xFFFFFFFF) | (y << 32), "Ptr*", &element)
        ComCall(14, automation, "Ptr*", &walker)
        Loop 4 {
            if !element
                break
            className := UIAString(element, 30012)
            automationId := UIAString(element, 30011)
            if processName = "WindowsTerminal.exe" && className = "TermControl"
                return true
            if processName = "explorer.exe" && (automationId = "SearchButton" || automationId = "SearchBoxTextBlock")
                return true
            parent := 0
            ComCall(3, walker, "Ptr", element, "Ptr*", &parent)
            ObjRelease(element)
            element := parent
        }
        return false
    } finally {
        if element
            ObjRelease(element)
        if walker
            ObjRelease(walker)
    }
}

ShowLanguageBadge(nearMouse := false, fixedX := "", fixedY := "") {
    global languageBadge, languageBadgeText, languageSettings
    DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    activeWindow := WinExist("A")
    if !activeWindow
        return
    ; Use the same outside-popup placement when switching language in Search.
    if fixedX = "" && GetFocusedSearchRect(&fieldLeft, &fieldTop, &fieldRight, &fieldBottom) {
        GetSearchBadgePosition(fieldLeft, fieldTop, fieldRight, fieldBottom, &badgeX, &badgeY)
        fixedX := badgeX, fixedY := badgeY
    }
    threadId := DllCall("GetWindowThreadProcessId", "Ptr", activeWindow, "Ptr", 0, "UInt")
    layout := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
    languageId := layout & 0xFFFF
    primaryLanguage := languageId & 0x3FF
    label := primaryLanguage = 1 ? "العربية  AR" : primaryLanguage = 31 ? "Türkçe  TR" : primaryLanguage = 9 ? "English  EN" : Format("LANG {:04X}", languageId)
    for entry in languageSettings.Entries {
        if LocaleId(entry.Tag) = languageId {
            label := entry.Label
            break
        }
    }
    languageBadgeText.Text := label

    MouseGetPos(&mouseX, &mouseY)
    if fixedX != "" {
        x := fixedX
        y := fixedY
    } else {
        x := mouseX
        y := mouseY
        ; Apps exposing a native caret get a badge directly below it.
        if !nearMouse && CaretGetPos(&caretX, &caretY) {
            x := caretX
            y := caretY
        }
        x += 12
        y += 26
    }
    monitorX := fixedX != "" ? fixedX : mouseX
    monitorY := fixedY != "" ? fixedY : mouseY
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
        if monitorX >= left && monitorX < right && monitorY >= top && monitorY < bottom {
            x := Max(left + 4, Min(x, right - 177))
            y := Max(top + 4, Min(y, bottom - 50))
            break
        }
    }
    ; NA preserves typing focus; E0x20 lets clicks pass through the badge.
    languageBadge.Show("NA x" x " y" y " w173 h46")
    SetTimer(HideLanguageBadge, -500)
}

HideLanguageBadge() {
    global languageBadge
    languageBadge.Hide()
}
