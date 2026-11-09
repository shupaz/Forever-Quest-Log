local ADDON_NAME, FQL = ...

local SafeNum                = FQL.SafeNum
local SafeStr                = FQL.SafeStr
local SetBackdrop            = FQL.SetBackdrop
local PlayClickSound         = FQL.PlayClickSound
local DB_DEFAULTS            = FQL.DB_DEFAULTS
local SuppressMapQuestLog    = FQL.SuppressMapQuestLog
local UpdateKeybindOverrides = FQL.UpdateKeybindOverrides

local MIN_SCALE              = FQL.MIN_SCALE or 0.6
local MAX_SCALE              = FQL.MAX_SCALE or 1.6

-- ============================================================
-- Settings Panel (Options -> AddOns -> Forever Quest Log)
-- ============================================================

function FQL:CreateOptionsPanel()
    if self.optionsPanel then
        return self.optionsPanel
    end

    local panel = CreateFrame("Frame", "shupaz_ForeverQuestLogOptionsPanel")
    panel.name = "shupaz ForeverQuestLog"
    self.optionsPanel = panel

    -- Subtle dark card background inside Settings canvas
    local bg = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
    SetBackdrop(bg, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    bg:SetBackdropColor(0.05, 0.05, 0.07, 0.85)
    bg:SetBackdropBorderColor(0.35, 0.30, 0.18, 0.75)

    -- Header Bar
    local icon = bg:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("TOPLEFT", bg, "TOPLEFT", 18, -16)
    icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")

    local title = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    title:SetText("|cffffd200shupaz ForeverQuestLog|r")

    local subtitle = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Standalone Dual-Pane Quest Log & Zone-Grouped Objective Tracker  |cff888888(v" .. tostring(FQL.VERSION or "1.0.1") .. ")|r")

    -- Top-Right Action Button
    local resetDefaultsBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    resetDefaultsBtn:SetSize(130, 24)
    resetDefaultsBtn:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -18, -18)
    resetDefaultsBtn:SetText("Reset Defaults")

    local headerSep = bg:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT", bg, "TOPLEFT", 16, -60)
    headerSep:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -16, -60)
    headerSep:SetColorTexture(0.45, 0.38, 0.20, 0.55)

    -- Helper: Create Section Header
    local function CreateSectionHeader(parent, text, yOffset)
        local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        hdr:SetText("|cffffd200" .. text .. "|r")

        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -4)
        line:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
        line:SetColorTexture(0.35, 0.30, 0.18, 0.45)
        return hdr
    end

    -- Helper: Custom CheckButton (no deprecated template dependencies)
    local checkboxes = {}
    local function CreateOptionCheckbox(parent, yOffset, labelText, descText, dbKey, onChanged)
        local cb = CreateFrame("CheckButton", nil, parent)
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, yOffset)
        cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
        cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")

        local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", cb, "RIGHT", 6, 1)
        lbl:SetText(labelText)
        cb.label = lbl

        local desc = cb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        desc:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
        desc:SetPoint("RIGHT", parent, "RIGHT", -28, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText(descText or "")
        cb.desc = desc

        -- Make label clickable too
        cb:SetHitRectInsets(0, -320, 0, -14)

        cb.dbKey = dbKey
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked() and true or false
            if PlaySound and SOUNDKIT then
                PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            end
            if shupazForeverQuestLogDB then
                shupazForeverQuestLogDB[dbKey] = checked
            end
            if onChanged then
                onChanged(checked)
            end
            if panel.RefreshControls then
                panel:RefreshControls()
            end
        end)

        table.insert(checkboxes, cb)
        return cb
    end

    -- ========================================================
    -- Section 1: Standalone Quest Log Window
    -- ========================================================
    CreateSectionHeader(bg, "Standalone Quest Log Window", -64)

    -- Window Scale Slider + Buttons
    local scaleLabel = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleLabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 26, -88)
    scaleLabel:SetText("Window Scale:")

    local scaleValueText = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleValueText:SetPoint("LEFT", scaleLabel, "RIGHT", 8, 0)
    scaleValueText:SetText("100%")

    local scaleSlider = CreateFrame("Slider", nil, bg, BackdropTemplateMixin and "BackdropTemplate" or nil)
    scaleSlider:SetSize(200, 16)
    scaleSlider:SetPoint("LEFT", scaleLabel, "RIGHT", 58, 0)
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetMinMaxValues(0.60, 1.60)
    scaleSlider:SetValueStep(0.05)
    if scaleSlider.SetObeyStepOnDrag then
        scaleSlider:SetObeyStepOnDrag(true)
    end
    SetBackdrop(scaleSlider, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 8, 2)
    scaleSlider:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
    scaleSlider:SetBackdropBorderColor(0.45, 0.40, 0.25, 0.85)

    local thumb = scaleSlider:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(28, 28)
    scaleSlider:SetThumbTexture(thumb)

    local scaleMinusBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    scaleMinusBtn:SetSize(26, 22)
    scaleMinusBtn:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
    scaleMinusBtn:SetText("-")
    scaleMinusBtn:SetScript("OnClick", function()
        local cur = (shupazForeverQuestLogDB and shupazForeverQuestLogDB.scale) or 1.0
        FQL:SetScale(cur - 0.05)
    end)

    local scalePlusBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    scalePlusBtn:SetSize(26, 22)
    scalePlusBtn:SetPoint("LEFT", scaleMinusBtn, "RIGHT", 4, 0)
    scalePlusBtn:SetText("+")
    scalePlusBtn:SetScript("OnClick", function()
        local cur = (shupazForeverQuestLogDB and shupazForeverQuestLogDB.scale) or 1.0
        FQL:SetScale(cur + 0.05)
    end)

    local scaleResetBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    scaleResetBtn:SetSize(52, 22)
    scaleResetBtn:SetPoint("LEFT", scalePlusBtn, "RIGHT", 6, 0)
    scaleResetBtn:SetText("100%")
    scaleResetBtn:SetScript("OnClick", function()
        FQL:SetScale(1.0)
    end)

    local resetPosBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(116, 22)
    resetPosBtn:SetPoint("LEFT", scaleResetBtn, "RIGHT", 8, 0)
    resetPosBtn:SetText("Default Position")
    resetPosBtn:SetScript("OnClick", function()
        if shupazForeverQuestLogDB then
            shupazForeverQuestLogDB.pos = nil
            shupazForeverQuestLogDB.useDefaultPosition = true
        end
        FQL:CreateMainFrame()
        FQL:RestorePosition()
        FQL:Open()
    end)

    local updatingSlider = false
    scaleSlider:SetScript("OnValueChanged", function(_, value)
        if updatingSlider then return end
        local rounded = math.floor((value / 0.05) + 0.5) * 0.05
        scaleValueText:SetText(string.format("%d%%", math.floor(rounded * 100 + 0.5)))
        FQL:SetScale(rounded)
    end)

    -- Wowhead URL Bar Position Row
    local whBarLabel = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    whBarLabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 26, -114)
    whBarLabel:SetText("Wowhead URL Bar:")

    local whPosButtons = {}
    local whPosOptions = {
        { id = "TOP",    label = "Top" },
        { id = "BOTTOM", label = "Bottom" },
        { id = "HIDE",   label = "Hidden" },
    }
    for i, opt in ipairs(whPosOptions) do
        local btn = CreateFrame("Button", nil, bg, BackdropTemplateMixin and "BackdropTemplate" or nil)
        btn:SetSize(84, 20)
        if i == 1 then
            btn:SetPoint("LEFT", whBarLabel, "RIGHT", 36, 0)
        else
            btn:SetPoint("LEFT", whPosButtons[i - 1], "RIGHT", 6, 0)
        end
        SetBackdrop(btn, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 8, 2)
        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("CENTER", 0, 0)
        btn.text:SetText(opt.label)
        btn.posID = opt.id
        btn:SetScript("OnClick", function(self)
            PlayClickSound()
            if FQL.SetWowheadBarPosition then
                FQL:SetWowheadBarPosition(self.posID)
            end
        end)
        whPosButtons[i] = btn
    end

    CreateOptionCheckbox(
        bg, -140,
        "Show Quest Levels & Type Tags",
        "Prefixes quest titles with their level and tag indicator (e.g. [60D] for Dungeon, [60G] for Group, [60R] for Raid).",
        "showQuestLevels",
        function()
            FQL:Refresh()
        end
    )

    CreateOptionCheckbox(
        bg, -174,
        "Show Quest Row Hover Tooltips",
        "Displays a quick summary tooltip with objectives, zone, and click shortcuts when hovering over a quest in the list.",
        "showTooltips",
        function()
            FQL:Refresh()
        end
    )

    CreateOptionCheckbox(
        bg, -208,
        "Lock to Default UIPanel Placement",
        "Locks the Quest Log to Blizzard's default window slot (side-by-side with Character, Gossip, Quest Giver, etc.). Uncheck to drag freely.",
        "lockWindow",
        function(checked)
            if checked and shupazForeverQuestLogDB then
                shupazForeverQuestLogDB.pos = nil
                shupazForeverQuestLogDB.useDefaultPosition = true
                FQL:RestorePosition()
            end
        end
    )

    -- ========================================================
    -- Section 2: World Map Integration
    -- ========================================================
    CreateSectionHeader(bg, "World Map Integration", -246)

    CreateOptionCheckbox(
        bg, -268,
        "Remove Embedded Quest Log from World Map",
        "Hides the default Quest Log panel attached to the right side of the World Map and redirects Quest Log keybindings (L) to the standalone Forever Quest Log window.",
        "hideMapQuestLog",
        function()
            SuppressMapQuestLog()
            UpdateKeybindOverrides()
        end
    )

    -- ========================================================
    -- Section 3: Objective Tracker (Scale, Font & Zone Grouping)
    -- ========================================================
    CreateSectionHeader(bg, "Objective Tracker (Scale, Font & Zone Grouping)", -308)

    -- Objective Tracker Scale Row
    local tScaleLabel = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tScaleLabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 26, -332)
    tScaleLabel:SetText("Tracker Scale:")

    local tScaleValueText = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tScaleValueText:SetPoint("LEFT", tScaleLabel, "RIGHT", 8, 0)
    tScaleValueText:SetText("100%")

    local tScaleSlider = CreateFrame("Slider", nil, bg, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tScaleSlider:SetSize(200, 16)
    tScaleSlider:SetPoint("LEFT", tScaleLabel, "RIGHT", 58, 0)
    tScaleSlider:SetOrientation("HORIZONTAL")
    tScaleSlider:SetMinMaxValues(0.60, 1.60)
    tScaleSlider:SetValueStep(0.05)
    if tScaleSlider.SetObeyStepOnDrag then
        tScaleSlider:SetObeyStepOnDrag(true)
    end
    SetBackdrop(tScaleSlider, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 8, 2)
    tScaleSlider:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
    tScaleSlider:SetBackdropBorderColor(0.45, 0.40, 0.25, 0.85)

    local tThumb = tScaleSlider:CreateTexture(nil, "ARTWORK")
    tThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    tThumb:SetSize(28, 28)
    tScaleSlider:SetThumbTexture(tThumb)

    local tScaleMinusBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    tScaleMinusBtn:SetSize(26, 22)
    tScaleMinusBtn:SetPoint("LEFT", tScaleSlider, "RIGHT", 10, 0)
    tScaleMinusBtn:SetText("-")
    tScaleMinusBtn:SetScript("OnClick", function()
        local cur = (shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerScale) or 1.0
        FQL:SetTrackerScale(cur - 0.05)
    end)

    local tScalePlusBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    tScalePlusBtn:SetSize(26, 22)
    tScalePlusBtn:SetPoint("LEFT", tScaleMinusBtn, "RIGHT", 4, 0)
    tScalePlusBtn:SetText("+")
    tScalePlusBtn:SetScript("OnClick", function()
        local cur = (shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerScale) or 1.0
        FQL:SetTrackerScale(cur + 0.05)
    end)

    local tScaleResetBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    tScaleResetBtn:SetSize(52, 22)
    tScaleResetBtn:SetPoint("LEFT", tScalePlusBtn, "RIGHT", 6, 0)
    tScaleResetBtn:SetText("100%")
    tScaleResetBtn:SetScript("OnClick", function()
        FQL:SetTrackerScale(1.0)
    end)

    local updatingTrackerSlider = false
    tScaleSlider:SetScript("OnValueChanged", function(_, value)
        if updatingTrackerSlider then return end
        local rounded = math.floor((value / 0.05) + 0.5) * 0.05
        tScaleValueText:SetText(string.format("%d%%", math.floor(rounded * 100 + 0.5)))
        FQL:SetTrackerScale(rounded)
    end)

    -- Objective Tracker Font Type Row
    local tFontLabel = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tFontLabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 26, -356)
    tFontLabel:SetText("Tracker Font:")

    local fontDropdownBtn = CreateFrame("Button", nil, bg, BackdropTemplateMixin and "BackdropTemplate" or nil)
    fontDropdownBtn:SetSize(248, 22)
    fontDropdownBtn:SetPoint("LEFT", tFontLabel, "RIGHT", 62, 0)
    SetBackdrop(fontDropdownBtn, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    fontDropdownBtn:SetBackdropColor(0.08, 0.07, 0.05, 0.95)
    fontDropdownBtn:SetBackdropBorderColor(0.55, 0.45, 0.22, 0.90)
    fontDropdownBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local fontDropdownText = fontDropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontDropdownText:SetPoint("LEFT", 10, 0)
    fontDropdownText:SetPoint("RIGHT", -22, 0)
    fontDropdownText:SetJustifyH("LEFT")
    fontDropdownText:SetWordWrap(false)
    fontDropdownText:SetText("Friz Quadrata (Default)")

    local fontDropdownArrow = fontDropdownBtn:CreateTexture(nil, "ARTWORK")
    fontDropdownArrow:SetSize(12, 12)
    fontDropdownArrow:SetPoint("RIGHT", -6, 0)
    fontDropdownArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    -- Popup Dropdown Menu for Font Selection (supports mousewheel scrolling)
    local fontMenu = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    fontMenu:SetFrameStrata("TOOLTIP")
    fontMenu:SetToplevel(true)
    fontMenu:SetPoint("TOPLEFT", fontDropdownBtn, "BOTTOMLEFT", 0, -2)
    fontMenu:SetWidth(248)
    fontMenu:EnableMouse(true)
    fontMenu:EnableMouseWheel(true)
    SetBackdrop(fontMenu, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    fontMenu:SetBackdropColor(0.06, 0.05, 0.04, 0.98)
    fontMenu:SetBackdropBorderColor(0.65, 0.52, 0.24, 0.95)
    fontMenu:Hide()
    fontMenu.rows = {}
    fontMenu.scrollOffset = 0

    local function RenderFontMenuPage()
        local fonts = fontMenu.cachedFonts or FQL:GetTrackerFonts()
        local activeEntry = FQL:GetTrackerFontEntry((shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerFont) or "DEFAULT")
        local currentID = activeEntry and activeEntry.id or "DEFAULT"
        local rowH = 22
        local maxVisible = 12
        local visibleCount = math.min(#fonts, maxVisible)
        local maxOffset = math.max(0, #fonts - visibleCount)

        if fontMenu.scrollOffset > maxOffset then fontMenu.scrollOffset = maxOffset end
        if fontMenu.scrollOffset < 0 then fontMenu.scrollOffset = 0 end

        for i = 1, visibleCount do
            local fEntry = fonts[i + fontMenu.scrollOffset]
            local r = fontMenu.rows[i]
            if not r then
                r = CreateFrame("Button", nil, fontMenu)
                r:SetHeight(rowH)
                r:SetPoint("TOPLEFT", fontMenu, "TOPLEFT", 4, -4 - (i - 1) * rowH)
                r:SetPoint("TOPRIGHT", fontMenu, "TOPRIGHT", -4, -4 - (i - 1) * rowH)
                r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                r:EnableMouseWheel(true)
                r:SetScript("OnMouseWheel", function(_, delta)
                    local fn = fontMenu:GetScript("OnMouseWheel")
                    if fn then fn(fontMenu, delta) end
                end)

                r.check = r:CreateTexture(nil, "ARTWORK")
                r.check:SetSize(14, 14)
                r.check:SetPoint("LEFT", 4, 0)
                r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

                r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                r.text:SetPoint("LEFT", 22, 0)
                r.text:SetPoint("RIGHT", -6, 0)
                r.text:SetJustifyH("LEFT")
                r.text:SetWordWrap(false)

                fontMenu.rows[i] = r
            end
            r.fontID = fEntry.id
            r.text:SetText(fEntry.label)
            pcall(r.text.SetFont, r.text, fEntry.path, 12, "")
            if fEntry.id == currentID then
                r.check:Show()
                r.text:SetTextColor(1.0, 0.82, 0.18)
            else
                r.check:Hide()
                r.text:SetTextColor(0.92, 0.92, 0.92)
            end
            r:SetScript("OnClick", function(self)
                PlayClickSound()
                fontMenu:Hide()
                FQL:SetTrackerFont(self.fontID)
            end)
            r:Show()
        end
        for i = visibleCount + 1, #fontMenu.rows do
            fontMenu.rows[i]:Hide()
        end
        fontMenu:SetHeight(visibleCount * rowH + 8)
    end

    fontMenu:SetScript("OnMouseWheel", function(_, delta)
        if not fontMenu:IsShown() then return end
        fontMenu.scrollOffset = (fontMenu.scrollOffset or 0) - (delta > 0 and 1 or -1)
        RenderFontMenuPage()
    end)

    local function PopulateAndToggleFontMenu()
        if fontMenu:IsShown() then
            fontMenu:Hide()
            return
        end
        fontMenu.cachedFonts = FQL:GetTrackerFonts()
        fontMenu.scrollOffset = 0
        RenderFontMenuPage()
        fontMenu:Show()
    end

    fontDropdownBtn:EnableMouseWheel(true)
    fontDropdownBtn:SetScript("OnMouseWheel", function(_, delta)
        local _, idx, fonts = FQL:GetTrackerFontEntry()
        if not fonts or #fonts == 0 then return end
        local nextIdx
        if delta > 0 then
            nextIdx = (idx - 2) % #fonts + 1
        else
            nextIdx = (idx % #fonts) + 1
        end
        FQL:SetTrackerFont(fonts[nextIdx].id)
        if fontMenu:IsShown() then
            RenderFontMenuPage()
        end
    end)
    fontDropdownBtn:SetScript("OnClick", function()
        PlayClickSound()
        PopulateAndToggleFontMenu()
    end)

    local fontPrevBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    fontPrevBtn:SetSize(26, 22)
    fontPrevBtn:SetPoint("LEFT", fontDropdownBtn, "RIGHT", 6, 0)
    fontPrevBtn:SetText("<")
    fontPrevBtn:SetScript("OnClick", function()
        fontMenu:Hide()
        local _, idx, fonts = FQL:GetTrackerFontEntry()
        local prevIdx = (idx - 2) % #fonts + 1
        FQL:SetTrackerFont(fonts[prevIdx].id)
    end)

    local fontNextBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    fontNextBtn:SetSize(26, 22)
    fontNextBtn:SetPoint("LEFT", fontPrevBtn, "RIGHT", 4, 0)
    fontNextBtn:SetText(">")
    fontNextBtn:SetScript("OnClick", function()
        fontMenu:Hide()
        local _, idx, fonts = FQL:GetTrackerFontEntry()
        local nextIdx = (idx % #fonts) + 1
        FQL:SetTrackerFont(fonts[nextIdx].id)
    end)

    local fontResetBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    fontResetBtn:SetSize(64, 22)
    fontResetBtn:SetPoint("LEFT", fontNextBtn, "RIGHT", 6, 0)
    fontResetBtn:SetText("Default")
    fontResetBtn:SetScript("OnClick", function()
        fontMenu:Hide()
        FQL:SetTrackerFont("DEFAULT")
    end)

    local cbTrackerByZone = CreateOptionCheckbox(
        bg, -388,
        "Group & Collapse Quests by Zone in Objective Tracker",
        "Organizes tracked quests under collapsible [-]/[+] zone header buttons in the Objective Tracker on the right side of the screen.",
        "trackerByZone",
        function()
            FQL:RefreshObjectiveTracker()
        end
    )

    local cbTrackerCurrentZone = CreateOptionCheckbox(
        bg, -424,
        "Prioritize Current Player Zone at Top of Tracker",
        "Automatically places the zone you are currently standing in at the top of the Objective Tracker above alphabetical zones.",
        "trackerCurrentZoneFirst",
        function()
            FQL:RefreshObjectiveTracker()
        end
    )

    local cbTrackerZoneCount = CreateOptionCheckbox(
        bg, -460,
        "Show Active Quest Count on Tracker Zone Headers",
        "Displays the number of tracked quests in each zone on the right side of the Objective Tracker zone header bar.",
        "trackerShowZoneCount",
        function()
            FQL:RefreshObjectiveTracker()
        end
    )

    -- Quick Action Buttons for Tracker & Log Zones
    local expandTrackerBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    expandTrackerBtn:SetSize(165, 24)
    expandTrackerBtn:SetPoint("TOPLEFT", bg, "TOPLEFT", 24, -502)
    expandTrackerBtn:SetText("Expand Tracker Zones")
    expandTrackerBtn:SetScript("OnClick", function()
        if FQL.SetAllTrackerZonesCollapsed then
            FQL:SetAllTrackerZonesCollapsed(false)
        end
    end)

    local collapseTrackerBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    collapseTrackerBtn:SetSize(165, 24)
    collapseTrackerBtn:SetPoint("LEFT", expandTrackerBtn, "RIGHT", 10, 0)
    collapseTrackerBtn:SetText("Collapse Tracker Zones")
    collapseTrackerBtn:SetScript("OnClick", function()
        if FQL.SetAllTrackerZonesCollapsed then
            FQL:SetAllTrackerZonesCollapsed(true)
        end
    end)

    local expandLogBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    expandLogBtn:SetSize(165, 24)
    expandLogBtn:SetPoint("LEFT", collapseTrackerBtn, "RIGHT", 10, 0)
    expandLogBtn:SetText("Expand Quest Log Zones")
    expandLogBtn:SetScript("OnClick", function()
        if FQL.SetAllHeadersCollapsed then
            FQL:SetAllHeadersCollapsed(false)
        end
    end)

    -- Slash Command Hint Footer
    local footerText = bg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 22, 12)
    footerText:SetText("Slash Commands:  |cffffd200/fql|r (toggle window)   |cffffd200/fql options|r (open settings)   |cffffd200/fql tracker|r (toggle tracker zones)   |cffffd200/fql reset|r (reset window)")

    function panel:RefreshControls()
        if not shupazForeverQuestLogDB then return end
        local scale = shupazForeverQuestLogDB.scale or 1.0
        updatingSlider = true
        scaleSlider:SetValue(scale)
        scaleValueText:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
        updatingSlider = false

        local tScale = shupazForeverQuestLogDB.trackerScale or 1.0
        updatingTrackerSlider = true
        tScaleSlider:SetValue(tScale)
        tScaleValueText:SetText(string.format("%d%%", math.floor(tScale * 100 + 0.5)))
        updatingTrackerSlider = false

        local fontEntry = FQL:GetTrackerFontEntry(shupazForeverQuestLogDB.trackerFont)
        if fontEntry then
            fontDropdownText:SetText(fontEntry.label)
            pcall(fontDropdownText.SetFont, fontDropdownText, fontEntry.path, 12, "")
        end

        for _, cb in ipairs(checkboxes) do
            local val = shupazForeverQuestLogDB[cb.dbKey]
            cb:SetChecked(val ~= false and val ~= nil)
        end

        local curWhPos = shupazForeverQuestLogDB.wowheadBarPosition or "HIDE"
        for _, btn in ipairs(whPosButtons) do
            if btn.posID == curWhPos then
                btn:SetBackdropColor(0.22, 0.16, 0.08, 0.98)
                btn:SetBackdropBorderColor(0.95, 0.78, 0.28, 1)
                btn.text:SetTextColor(1.0, 0.85, 0.20)
            else
                btn:SetBackdropColor(0.08, 0.07, 0.05, 0.92)
                btn:SetBackdropBorderColor(0.42, 0.34, 0.18, 0.85)
                btn.text:SetTextColor(0.75, 0.72, 0.65)
            end
        end

        local trackerEnabled = (shupazForeverQuestLogDB.trackerByZone ~= false)
        cbTrackerCurrentZone:SetEnabled(trackerEnabled)
        cbTrackerCurrentZone:SetAlpha(trackerEnabled and 1.0 or 0.45)
        cbTrackerZoneCount:SetEnabled(trackerEnabled)
        cbTrackerZoneCount:SetAlpha(trackerEnabled and 1.0 or 0.45)
        expandTrackerBtn:SetEnabled(trackerEnabled)
        collapseTrackerBtn:SetEnabled(trackerEnabled)
    end

    resetDefaultsBtn:SetScript("OnClick", function()
        if not shupazForeverQuestLogDB then return end
        fontMenu:Hide()
        for k, v in pairs(DB_DEFAULTS) do
            shupazForeverQuestLogDB[k] = v
        end
        shupazForeverQuestLogDB.pos = nil
        if shupazForeverQuestLogCharDB and shupazForeverQuestLogCharDB.collapsedTrackerZones then
            wipe(shupazForeverQuestLogCharDB.collapsedTrackerZones)
        end
        FQL:SetScale(DB_DEFAULTS.scale or 1.0)
        FQL:SetTrackerScale(DB_DEFAULTS.trackerScale or 1.0)
        FQL:SetTrackerFont(DB_DEFAULTS.trackerFont or "DEFAULT")
        if FQL.UpdateWowheadBarLayout then
            FQL:UpdateWowheadBarLayout()
        end
        FQL:RestorePosition()
        SuppressMapQuestLog()
        UpdateKeybindOverrides()
        FQL:Refresh()
        FQL:RefreshObjectiveTracker()
        panel:RefreshControls()
        print("|cffffd200shupaz ForeverQuestLog:|r All settings restored to defaults.")
    end)

    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function(self)
        if self.RefreshControls then
            self:RefreshControls()
        end
    end

    panel:SetScript("OnShow", function(self)
        fontMenu:Hide()
        self:RefreshControls()
    end)
    panel:SetScript("OnHide", function()
        fontMenu:Hide()
    end)

    panel:RefreshControls()

    -- Register in Modern Settings API (Options -> AddOns) with Legacy Fallback
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

function FQL:OpenOptions()
    local panel = self:CreateOptionsPanel()
    if panel and panel.RefreshControls then
        panel:RefreshControls()
    end
    if Settings and Settings.OpenToCategory and self.settingsCategory then
        local catID = self.settingsCategory.GetID and self.settingsCategory:GetID() or self.settingsCategory.ID
        pcall(Settings.OpenToCategory, catID)
    elseif InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end

