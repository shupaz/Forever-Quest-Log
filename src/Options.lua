local ADDON_NAME, FQL = ...

local SafeNum                = FQL.SafeNum
local SafeStr                = FQL.SafeStr
local DB_DEFAULTS            = FQL.DB_DEFAULTS
local SuppressMapQuestLog    = FQL.SuppressMapQuestLog
local UpdateKeybindOverrides = FQL.UpdateKeybindOverrides

local MIN_SCALE              = FQL.MIN_SCALE or 0.6
local MAX_SCALE              = FQL.MAX_SCALE or 1.6

-- ============================================================
-- PageMixin for native SettingsListTemplate integration
-- Identical to Blizzard's modern Dragonflight / TWW Settings engine.
-- Using SettingsListTemplate embeds Blizzard's authentic scrollbox,
-- row element templates, hover highlights, slider steppers,
-- and section headers inside the AddOns options pane.
-- ============================================================
local PageMixin = {}

function PageMixin:AddInitializer(initializer)
    self.layout:AddInitializer(initializer)
    self.onPage[initializer] = true
    initializer.IsParentInitializerInLayout = self.isParentOnPage
    return initializer
end

function PageMixin:GetInitializers()
    return self.layout:GetInitializers()
end

function PageMixin:OnRefresh()
    self:Redisplay()
end

function PageMixin:UpdateControlStates()
    if self:IsShown() and self.List and self.List.ScrollBox and self.List.ScrollBox.ForEachFrame then
        pcall(self.List.ScrollBox.ForEachFrame, self.List.ScrollBox, function(frame)
            if frame and frame.EvaluateState then
                pcall(frame.EvaluateState, frame)
            end
        end)
    end
end

function PageMixin:Redisplay()
    if self:IsShown() and self.List and self.layout then
        self.List:Display(self.layout:GetInitializers())
        self:UpdateControlStates()
    end
end

function FQL:CreateOptionsPanel()
    if self.optionsPanel then
        return self.optionsPanel
    end

    -- 1. Modern Dragonflight / The War Within Settings Engine
    if Settings and Settings.RegisterCanvasLayoutCategory and CreateVerticalLayout and Settings.CreateCheckboxInitializer then
        local success, result = pcall(function()
            local page = Mixin(CreateFrame("Frame"), PageMixin)
            page:Hide()
            page.layout = CreateVerticalLayout()
            page.onPage = {}
            page.isParentOnPage = function(initializer)
                local parent = initializer:GetParentInitializer()
                return parent ~= nil and page.onPage[parent] == true
            end

            page.List = CreateFrame("Frame", nil, page, "SettingsListTemplate")
            page.List:SetAllPoints()
            page.List.Header.Title:SetText("shupaz ForeverQuestLog")
            if page.List.Header.DefaultsButton then
                local defBtn = page.List.Header.DefaultsButton
                defBtn:Show()
                defBtn:SetText(_G.DEFAULTS or "Defaults")
                defBtn:SetScript("OnClick", function()
                    FQL:ResetToDefaults()
                end)
                defBtn:SetScript("OnEnter", function(btn)
                    if GameTooltip then
                        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                        GameTooltip:SetText(_G.DEFAULTS or "Defaults", 1, 1, 1)
                        GameTooltip:AddLine("Reset all shupaz ForeverQuestLog options and window positions back to their default values.", nil, nil, nil, true)
                        GameTooltip:Show()
                    end
                end)
                defBtn:SetScript("OnLeave", function()
                    if GameTooltip then
                        GameTooltip:Hide()
                    end
                end)
            end

            page:SetScript("OnShow", function(self)
                self:Redisplay()
            end)

            page.category = Settings.RegisterCanvasLayoutCategory(page, "shupaz ForeverQuestLog")
            self.settingsCategory = page.category

            local regSettings = {}
            FQL.registeredSettings = regSettings

            -- Helper: Add Checkbox Row
            local function AddCheckbox(key, varName, label, tooltip, callback)
                local setting = Settings.RegisterAddOnSetting(
                    page.category,
                    varName,
                    key,
                    shupazForeverQuestLogDB,
                    Settings.VarType.Boolean,
                    label,
                    DB_DEFAULTS[key] ~= false
                )
                setting:SetValueChangedCallback(function(_, val)
                    if callback then callback(val) end
                end)
                local init = Settings.CreateCheckboxInitializer(setting, nil, tooltip)
                page:AddInitializer(init)
                regSettings[key] = setting
                return setting, init
            end

            -- ========================================================
            -- Section 1: Quest Log Window
            -- ========================================================
            if CreateSettingsListSectionHeaderInitializer then
                page:AddInitializer(CreateSettingsListSectionHeaderInitializer("Quest Log Window"))
            end

            -- Window Scale Slider
            local scaleOptions = Settings.CreateSliderOptions(0.60, 1.60, 0.05)
            if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                    return string.format("%d%%", math.floor(value * 100 + 0.5))
                end)
            end
            local scaleSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_SCALE",
                "scale",
                shupazForeverQuestLogDB,
                Settings.VarType.Number,
                "Window Scale",
                DB_DEFAULTS.scale or 1.0
            )
            scaleSetting:SetValueChangedCallback(function(_, val)
                FQL:SetScale(val)
            end)
            local scaleInit = Settings.CreateSliderInitializer(scaleSetting, scaleOptions, "Adjusts the overall display scale of the standalone Quest Log window.")
            page:AddInitializer(scaleInit)
            regSettings["scale"] = scaleSetting

            -- Quest Log Font Size Slider
            local qlFontOptions = Settings.CreateSliderOptions(0.80, 1.60, 0.05)
            if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                qlFontOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                    return string.format("%d%%", math.floor(value * 100 + 0.5))
                end)
            end
            local qlFontSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_QUEST_LOG_FONT_SCALE",
                "questLogFontScale",
                shupazForeverQuestLogDB,
                Settings.VarType.Number,
                "Font Size",
                DB_DEFAULTS.questLogFontScale or 1.0
            )
            qlFontSetting:SetValueChangedCallback(function(_, val)
                FQL:SetQuestLogFontScale(val)
            end)
            local qlFontInit = Settings.CreateSliderInitializer(qlFontSetting, qlFontOptions, "Scales the font size of quest titles, zone headers, and objectives throughout the Quest Log.")
            page:AddInitializer(qlFontInit)
            regSettings["questLogFontScale"] = qlFontSetting

            -- Wowhead URL Bar Dropdown
            local function GetWowheadOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add("TOP", "Top of Details")
                container:Add("BOTTOM", "Bottom of Details")
                container:Add("HIDE", "Hidden")
                return container:GetData()
            end
            local whSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_WOWHEAD_BAR_POS",
                "wowheadBarPosition",
                shupazForeverQuestLogDB,
                Settings.VarType.String,
                "Wowhead URL Bar",
                DB_DEFAULTS.wowheadBarPosition or "HIDE"
            )
            whSetting:SetValueChangedCallback(function(_, val)
                if FQL.SetWowheadBarPosition then
                    FQL:SetWowheadBarPosition(val)
                end
            end)
            local whInit = Settings.CreateDropdownInitializer(whSetting, GetWowheadOptions, "Position of the copyable Wowhead quest URL bar inside the quest detail pane.")
            page:AddInitializer(whInit)
            regSettings["wowheadBarPosition"] = whSetting

            -- Checkboxes
            AddCheckbox(
                "showQuestLevels",
                "FQL_SHOW_QUEST_LEVELS",
                "Show Quest Levels & Type Tags",
                "Prefixes quest titles with their level and tag indicator (e.g. [60D] for Dungeon, [60G] for Group).",
                function() FQL:Refresh() end
            )

            AddCheckbox(
                "showTooltips",
                "FQL_SHOW_TOOLTIPS",
                "Show Quest Row Hover Tooltips",
                "Displays a quick summary tooltip with objectives, zone, and click shortcuts when hovering over a quest in the list.",
                function() FQL:Refresh() end
            )

            AddCheckbox(
                "lockWindow",
                "FQL_LOCK_WINDOW",
                "Lock to Default UIPanel Placement",
                "Locks the Quest Log to Blizzard's default side-by-side window slot (Character, Gossip, etc.). Uncheck to drag freely.",
                function(val)
                    if val and shupazForeverQuestLogDB then
                        shupazForeverQuestLogDB.pos = nil
                        shupazForeverQuestLogDB.useDefaultPosition = true
                        FQL:RestorePosition()
                    end
                end
            )

            -- ========================================================
            -- Section 2: Objective Tracker
            -- ========================================================
            if CreateSettingsListSectionHeaderInitializer then
                page:AddInitializer(CreateSettingsListSectionHeaderInitializer("Objective Tracker"))
            end

            -- Tracker Scale Slider
            local trkScaleOptions = Settings.CreateSliderOptions(0.60, 1.60, 0.05)
            if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                trkScaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                    return string.format("%d%%", math.floor(value * 100 + 0.5))
                end)
            end
            local trkScaleSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_TRACKER_SCALE",
                "trackerScale",
                shupazForeverQuestLogDB,
                Settings.VarType.Number,
                "Tracker Scale",
                DB_DEFAULTS.trackerScale or 1.0
            )
            trkScaleSetting:SetValueChangedCallback(function(_, val)
                FQL:SetTrackerScale(val)
            end)
            local trkScaleInit = Settings.CreateSliderInitializer(trkScaleSetting, trkScaleOptions, "Adjusts the display scale of the Objective Tracker on the right side of the screen.")
            page:AddInitializer(trkScaleInit)
            regSettings["trackerScale"] = trkScaleSetting

            -- Tracker Font Size Slider
            local trkFontScaleOptions = Settings.CreateSliderOptions(0.80, 1.60, 0.05)
            if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                trkFontScaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                    return string.format("%d%%", math.floor(value * 100 + 0.5))
                end)
            end
            local trkFontScaleSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_TRACKER_FONT_SCALE",
                "trackerFontScale",
                shupazForeverQuestLogDB,
                Settings.VarType.Number,
                "Font Size",
                DB_DEFAULTS.trackerFontScale or 1.0
            )
            trkFontScaleSetting:SetValueChangedCallback(function(_, val)
                FQL:SetTrackerFontScale(val)
            end)
            local trkFontScaleInit = Settings.CreateSliderInitializer(trkFontScaleSetting, trkFontScaleOptions, "Scales the font size of quest titles, zone headers, and objectives in the Objective Tracker.")
            page:AddInitializer(trkFontScaleInit)
            regSettings["trackerFontScale"] = trkFontScaleSetting

            -- Tracker Font Dropdown
            local function GetTrackerFontOptions()
                local container = Settings.CreateControlTextContainer()
                local fonts = FQL:GetTrackerFonts()
                for _, f in ipairs(fonts) do
                    container:Add(f.id, f.label)
                end
                return container:GetData()
            end
            local fontSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_TRACKER_FONT",
                "trackerFont",
                shupazForeverQuestLogDB,
                Settings.VarType.String,
                "Tracker Font",
                DB_DEFAULTS.trackerFont or "DEFAULT"
            )
            fontSetting:SetValueChangedCallback(function(_, val)
                FQL:SetTrackerFont(val)
            end)
            local fontInit = Settings.CreateDropdownInitializer(fontSetting, GetTrackerFontOptions, "Changes the typeface used for all quest headers and objective text in the tracker.")
            page:AddInitializer(fontInit)
            regSettings["trackerFont"] = fontSetting

            -- Tracker Grouping & Sorting Dropdown
            local function GetTrackerSortModeOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add("AUTO", "Automatic")
                container:Add("ZONE", "Group by Zone")
                container:Add("COMPLETION", "Group by Completion Status")
                container:Add("LEVEL", "List by Level")
                container:Add("LEVEL_DESC", "List by Level (High to Low)")
                container:Add("ALPHA", "List Alphabetically")
                return container:GetData()
            end
            local sortModeSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_TRACKER_SORT_MODE",
                "trackerSortMode",
                shupazForeverQuestLogDB,
                Settings.VarType.String,
                "Grouping & Sorting",
                DB_DEFAULTS.trackerSortMode or "AUTO"
            )
            sortModeSetting:SetValueChangedCallback(function(_, val)
                if FQL.SetTrackerSortMode then
                    FQL:SetTrackerSortMode(val)
                else
                    FQL:RefreshObjectiveTracker()
                end
            end)
            local sortModeTooltip = table.concat({
                "|cffffffffAutomatic:|r Default zone grouping with Current Zone First support.",
                "|cffffffffGroup by Zone:|r Zones sorted alphabetically (A-Z), quests ordered by level inside each zone.",
                "|cffffffffGroup by Completion Status:|r Grouped into Complete and In Progress, ordered by level.",
                "|cffffffffList by Level:|r No headers, quests ordered by level (Low to High).",
                "|cffffffffList by Level (High to Low):|r No headers, quests ordered by level (High to Low).",
                "|cffffffffList Alphabetically:|r No headers, quests ordered A-Z by title.",
            }, "\n\n")
            local sortModeInit = Settings.CreateDropdownInitializer(
                sortModeSetting,
                GetTrackerSortModeOptions,
                sortModeTooltip
            )
            page:AddInitializer(sortModeInit)
            regSettings["trackerSortMode"] = sortModeSetting

            -- Tracker Checkboxes
            local function IsCurrentZoneFirstAvailable()
                local mode = (FQL.GetTrackerSortMode and FQL:GetTrackerSortMode()) or (shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerSortMode) or "AUTO"
                return mode == "AUTO" or mode == "ZONE"
            end

            local _, curZoneFirstInit = AddCheckbox(
                "trackerCurrentZoneFirst",
                "FQL_TRACKER_CURRENT_ZONE_FIRST",
                "Current Zone First",
                "Automatically places the zone you are currently standing in at the top of the Objective Tracker (available in Automatic and Group by Zone modes).",
                function() FQL:RefreshObjectiveTracker() end
            )
            if curZoneFirstInit then
                if curZoneFirstInit.SetParentInitializer then
                    pcall(curZoneFirstInit.SetParentInitializer, curZoneFirstInit, sortModeInit, IsCurrentZoneFirstAvailable)
                elseif curZoneFirstInit.AddModifyPredicate then
                    pcall(curZoneFirstInit.AddModifyPredicate, curZoneFirstInit, IsCurrentZoneFirstAvailable)
                end
            end

            AddCheckbox(
                "trackerShowZoneCount",
                "FQL_TRACKER_SHOW_ZONE_COUNT",
                "Show Zone Quest Count",
                "Displays the number of tracked quests next to each zone name in the Objective Tracker header bar.",
                function() FQL:RefreshObjectiveTracker() end
            )

            -- ========================================================
            -- Section 3: World Map Integration
            -- ========================================================
            if CreateSettingsListSectionHeaderInitializer then
                page:AddInitializer(CreateSettingsListSectionHeaderInitializer("World Map"))
            end

            AddCheckbox(
                "hideMapQuestLog",
                "FQL_HIDE_MAP_QUEST_LOG",
                "Remove Embedded Quest Log from Map",
                "Hides the default Quest Log panel attached to the World Map and redirects Quest Log keybindings (L) to the standalone window.",
                function()
                    SuppressMapQuestLog()
                    UpdateKeybindOverrides()
                end
            )

            local function RefreshMapAndSearch()
                if FQL.RefreshMapQuestPins then
                    FQL:RefreshMapQuestPins()
                end
                if FQL.searchFrame and FQL.searchFrame:IsShown() and FQL.RunQuestSearch then
                    FQL:RunQuestSearch()
                end
            end

            AddCheckbox(
                "showMapAvailableQuests",
                "FQL_SHOW_MAP_AVAILABLE_QUESTS",
                "Show Available Quests on World Map (!)",
                "Displays available quest pickup icons (!) on the open World Map using Forever Quest Log's built-in Classic & Forever database.",
                RefreshMapAndSearch
            )

            AddCheckbox(
                "showLowLevelMapQuests",
                "FQL_SHOW_LOW_LEVEL_MAP_QUESTS",
                "Show Low-Level (Trivial) Quests",
                "When enabled, displays quests that are below your Low-Level Threshold on the World Map and in the Quest DB Search (tinted silver).",
                RefreshMapAndSearch
            )

            -- Low-Level Threshold Slider (0 to 60 levels below player)
            local minLvlOptions = Settings.CreateSliderOptions(0, 60, 1)
            if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                minLvlOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                    return string.format("-%d Lv", math.floor(value + 0.5))
                end)
            end
            local minLvlSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_MAP_QUEST_MIN_LEVEL_OFFSET",
                "mapQuestMinLevelOffset",
                shupazForeverQuestLogDB,
                Settings.VarType.Number,
                "Low-Level Threshold (Below Player)",
                DB_DEFAULTS.mapQuestMinLevelOffset or 7
            )
            minLvlSetting:SetValueChangedCallback(function()
                RefreshMapAndSearch()
            end)
            local minLvlInit = Settings.CreateSliderInitializer(
                minLvlSetting,
                minLvlOptions,
                "Quests more than this many levels below your character level are considered low-level (trivial) and hidden unless 'Show Low-Level Quests' is enabled."
            )
            page:AddInitializer(minLvlInit)
            regSettings["mapQuestMinLevelOffset"] = minLvlSetting

            -- High-Level Threshold Slider (0 to 15 levels above player)
            local maxLvlOptions = Settings.CreateSliderOptions(0, 15, 1)
            if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                maxLvlOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                    return string.format("+%d Lv", math.floor(value + 0.5))
                end)
            end
            local maxLvlSetting = Settings.RegisterAddOnSetting(
                page.category,
                "FQL_MAP_QUEST_MAX_LEVEL_OFFSET",
                "mapQuestMaxLevelOffset",
                shupazForeverQuestLogDB,
                Settings.VarType.Number,
                "High-Level Threshold (Above Player)",
                DB_DEFAULTS.mapQuestMaxLevelOffset or 5
            )
            maxLvlSetting:SetValueChangedCallback(function()
                RefreshMapAndSearch()
            end)
            local maxLvlInit = Settings.CreateSliderInitializer(
                maxLvlSetting,
                maxLvlOptions,
                "Maximum number of levels above your character level to show quests on the World Map and in level-filtered searches."
            )
            page:AddInitializer(maxLvlInit)
            regSettings["mapQuestMaxLevelOffset"] = maxLvlSetting

            AddCheckbox(
                "showUpcomingHighLevelQuests",
                "FQL_SHOW_UPCOMING_HIGH_LEVEL_QUESTS",
                "Show Upcoming High-Level Quests",
                "Shows quests within your High-Level Threshold even if your character has not yet reached the quest's minimum required level (highlighted in red).",
                RefreshMapAndSearch
            )

            AddCheckbox(
                "showMapEventQuests",
                "FQL_SHOW_MAP_EVENT_QUESTS",
                "Show World Event & Holiday Quests on Map",
                "Displays seasonal holiday, Darkmoon Faire, Stranglethorn Fishing Extravaganza, Ahn'Qiraj War Effort, and Scourge Invasion quests on the World Map.",
                RefreshMapAndSearch
            )

            -- Register category with Blizzard Settings
            Settings.RegisterAddOnCategory(page.category)

            page.RefreshControls = function(self)
                self:Redisplay()
            end

            return page
        end)

        if success and result then
            self.optionsPanel = result
            return result
        else
            if shupazForeverQuestLogDB then
                shupazForeverQuestLogDB._lastOptionsError = tostring(result)
            end
            print("|cffff0000shupaz ForeverQuestLog Options Error:|r", tostring(result))
        end
    end

    -- 2. Legacy Fallback (InterfaceOptions_AddCategory)
    local panel = CreateFrame("Frame", "shupaz_ForeverQuestLogOptionsPanel")
    panel.name = "shupaz ForeverQuestLog"
    self.optionsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Forever Quest Log")

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    return panel
end

function FQL:OpenOptions()
    if not self.settingsCategory then
        self:CreateOptionsPanel()
    end
    if Settings and Settings.OpenToCategory and self.settingsCategory then
        local catID = self.settingsCategory.GetID and self.settingsCategory:GetID() or self.settingsCategory.ID
        pcall(Settings.OpenToCategory, catID)
    elseif InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end

function FQL:ResetToDefaults()
    if not shupazForeverQuestLogDB then return end

    local defaults = DB_DEFAULTS or {}
    for k, v in pairs(defaults) do
        shupazForeverQuestLogDB[k] = v
    end
    shupazForeverQuestLogDB.pos = nil
    shupazForeverQuestLogDB.useDefaultPosition = true

    if self.registeredSettings then
        for k, s in pairs(self.registeredSettings) do
            if defaults[k] ~= nil and s.SetValue then
                pcall(s.SetValue, s, defaults[k])
            end
        end
    end

    if self.SetScale then self:SetScale(defaults.scale or 1.0) end
    if self.SetQuestLogFontScale then self:SetQuestLogFontScale(defaults.questLogFontScale or 1.0) end
    if self.SetTrackerScale then self:SetTrackerScale(defaults.trackerScale or 1.0) end
    if self.SetTrackerFontScale then self:SetTrackerFontScale(defaults.trackerFontScale or 1.0) end
    if self.SetTrackerFont then self:SetTrackerFont(defaults.trackerFont or "DEFAULT") end
    if self.SetTrackerSortMode then self:SetTrackerSortMode(defaults.trackerSortMode or "AUTO") end
    if self.SetWowheadBarPosition then self:SetWowheadBarPosition(defaults.wowheadBarPosition or "HIDE") end

    SuppressMapQuestLog()
    UpdateKeybindOverrides()

    if self.RestorePosition then self:RestorePosition() end
    if self.ResetHiddenMapQuests then self:ResetHiddenMapQuests() end
    if self.Refresh then self:Refresh() end
    if self.RefreshObjectiveTracker then self:RefreshObjectiveTracker() end
    if self.RefreshMapQuestPins then self:RefreshMapQuestPins() end
    if self.searchFrame and self.searchFrame:IsShown() and self.RunQuestSearch then
        self:RunQuestSearch()
    end

    if self.optionsPanel and self.optionsPanel.Redisplay then
        self.optionsPanel:Redisplay()
    end

    print("|cffffd200shupaz ForeverQuestLog:|r Settings have been reset to defaults.")
end
