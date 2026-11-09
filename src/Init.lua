local ADDON_NAME, FQL = ...

local SafeNum                    = FQL.SafeNum
local DB_DEFAULTS                = FQL.DB_DEFAULTS
local CHAR_DEFAULTS              = FQL.CHAR_DEFAULTS
local SuppressMapQuestLog        = FQL.SuppressMapQuestLog
local UpdateKeybindOverrides     = FQL.UpdateKeybindOverrides
local SetupMapAndBindingHooks    = FQL.SetupMapAndBindingHooks
local SetupObjectiveTrackerHooks = FQL.SetupObjectiveTrackerHooks

-- ============================================================
-- Public Window Controls & Addon Compartment / Slash Commands
-- ============================================================

function FQL:IsBlockingMenuOpen()
    if _G.GameMenuFrame and type(_G.GameMenuFrame.IsShown) == "function" then
        local ok, shown = pcall(_G.GameMenuFrame.IsShown, _G.GameMenuFrame)
        if ok and shown then return true end
    end
    if _G.SettingsPanel and type(_G.SettingsPanel.IsShown) == "function" then
        local ok, shown = pcall(_G.SettingsPanel.IsShown, _G.SettingsPanel)
        if ok and shown then return true end
    end
    return false
end

function FQL:Open()
    if self:IsBlockingMenuOpen() then return end
    local frame = self:CreateMainFrame()
    if not frame:IsShown() then
        frame:Show()
    else
        self:Refresh()
    end
end

function FQL:Close()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
end

function FQL:Toggle()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        if self:IsBlockingMenuOpen() then return end
        frame:Show()
    end
end

function FQL:OpenToQuest(questID)
    if self:IsBlockingMenuOpen() then return end
    questID = SafeNum(questID)
    self:CreateMainFrame()
    if questID and questID > 0 then
        self.selectedQuestID = questID
        if shupazForeverQuestLogCharDB then
            shupazForeverQuestLogCharDB.selectedQuestID = questID
            if shupazForeverQuestLogCharDB.collapsedHeaders and self.GetQuestZoneLookup then
                local questToZone = self:GetQuestZoneLookup()
                local zoneInfo = questToZone and questToZone[questID]
                if zoneInfo and zoneInfo.zone then
                    shupazForeverQuestLogCharDB.collapsedHeaders[zoneInfo.zone] = nil
                end
            end
        end
        local logIndex = FQL.GetLogIndexForQuest and FQL.GetLogIndexForQuest(questID)
        if FQL.SelectLogQuest then
            FQL.SelectLogQuest(questID, logIndex)
        end
    end
    self:Open()
end

function _G.shupaz_ForeverQuestLog_Toggle()
    FQL:Toggle()
end
_G.ForeverQuestLog_Toggle = _G.shupaz_ForeverQuestLog_Toggle

function _G.shupaz_ForeverQuestLog_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        FQL:OpenOptions()
    else
        FQL:Toggle()
    end
end
_G.ForeverQuestLog_OnAddonCompartmentClick = _G.shupaz_ForeverQuestLog_OnAddonCompartmentClick

function _G.shupaz_ForeverQuestLog_OnAddonCompartmentEnter(_, menuButtonFrame)
    if not GameTooltip then return end
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText("shupaz ForeverQuestLog", 1, 0.82, 0)
    GameTooltip:AddLine("Left-Click: Toggle standalone Quest Log window", 1, 1, 1, true)
    GameTooltip:AddLine("Right-Click: Open AddOn Settings", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end
_G.ForeverQuestLog_OnAddonCompartmentEnter = _G.shupaz_ForeverQuestLog_OnAddonCompartmentEnter

function _G.shupaz_ForeverQuestLog_OnAddonCompartmentLeave()
    if GameTooltip then GameTooltip:Hide() end
end
_G.ForeverQuestLog_OnAddonCompartmentLeave = _G.shupaz_ForeverQuestLog_OnAddonCompartmentLeave

SLASH_FOREVERQUESTLOG1 = "/fql"
SLASH_FOREVERQUESTLOG2 = "/questlog"
SlashCmdList["FOREVERQUESTLOG"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "options" or msg == "config" or msg == "settings" or msg == "opt" then
        FQL:OpenOptions()
        return
    end
    if msg == "reset" then
        shupazForeverQuestLogDB.pos = nil
        shupazForeverQuestLogDB.useDefaultPosition = true
        FQL:SetScale(1.0)
        FQL:RestorePosition()
        FQL:Open()
        print("|cffffd200shupaz ForeverQuestLog:|r Window position and scale reset to default.")
        return
    end
    if msg == "tracker" then
        shupazForeverQuestLogDB.trackerByZone = not (shupazForeverQuestLogDB.trackerByZone ~= false)
        FQL:RefreshObjectiveTracker()
        if FQL.optionsPanel and FQL.optionsPanel:IsShown() and FQL.optionsPanel.RefreshControls then
            FQL.optionsPanel:RefreshControls()
        end
        print("|cffffd200shupaz ForeverQuestLog:|r Objective Tracker zone headers " .. (shupazForeverQuestLogDB.trackerByZone and "enabled." or "disabled."))
        return
    end
    local scaleArg = msg:match("^scale%s+([%d%.]+)$")
    if scaleArg then
        FQL:CreateMainFrame()
        FQL:SetScale(tonumber(scaleArg) or 1.0)
        print(string.format("|cffffd200shupaz ForeverQuestLog:|r Scale set to %.2f.", shupazForeverQuestLogDB.scale or 1.0))
        return
    end
    FQL:Toggle()
end


-- ============================================================
-- Event Handling & Refresh Schedulers
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
eventFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
eventFrame:RegisterEvent("QUEST_LOG_CRITERIA_UPDATE")
eventFrame:RegisterEvent("QUEST_POI_UPDATE")

local refreshQueued = false
local trackerRefreshQueued = false
local trackerForceRebuildPending = false

local function ScheduleTrackerRefresh(forceRebuild)
    if forceRebuild then
        trackerForceRebuildPending = true
    end
    if trackerRefreshQueued then return end
    trackerRefreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            trackerRefreshQueued = false
            local doForce = trackerForceRebuildPending
            trackerForceRebuildPending = false
            FQL:RefreshObjectiveTracker(doForce)
        end)
    else
        trackerRefreshQueued = false
        local doForce = trackerForceRebuildPending
        trackerForceRebuildPending = false
        FQL:RefreshObjectiveTracker(doForce)
    end
end

local function ScheduleRefresh(forceTrackerRebuild)
    ScheduleTrackerRefresh(forceTrackerRebuild)
    if refreshQueued then return end
    if not FQL.frame or not FQL.frame:IsShown() then return end
    refreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            refreshQueued = false
            FQL:Refresh()
        end)
    else
        refreshQueued = false
        FQL:Refresh()
    end
end

FQL.ScheduleTrackerRefresh = ScheduleTrackerRefresh
FQL.ScheduleRefresh = ScheduleRefresh

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if FQL._isRefreshing and (event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED") then
        return
    end

    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_ObjectiveTracker" then
            SetupObjectiveTrackerHooks()
            ScheduleTrackerRefresh()
        end
        if FQL.HookKnownPanels then
            FQL:HookKnownPanels()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        shupazForeverQuestLogDB = shupazForeverQuestLogDB or {}
        for k, v in pairs(DB_DEFAULTS) do
            if shupazForeverQuestLogDB[k] == nil then
                shupazForeverQuestLogDB[k] = v
            end
        end
        if not shupazForeverQuestLogDB._placementV2 then
            shupazForeverQuestLogDB._placementV2 = true
            shupazForeverQuestLogDB.lockWindow = true
            shupazForeverQuestLogDB.useDefaultPosition = true
            shupazForeverQuestLogDB.pos = nil
        end
        if not shupazForeverQuestLogDB._wowheadHideDefaultV1 then
            shupazForeverQuestLogDB._wowheadHideDefaultV1 = true
            shupazForeverQuestLogDB.wowheadBarPosition = "HIDE"
        end

        shupazForeverQuestLogCharDB = shupazForeverQuestLogCharDB or {}
        for k, v in pairs(CHAR_DEFAULTS) do
            if shupazForeverQuestLogCharDB[k] == nil then
                shupazForeverQuestLogCharDB[k] = type(v) == "table" and {} or v
            end
        end

        FQL.selectedQuestID = shupazForeverQuestLogCharDB.selectedQuestID
        SetupMapAndBindingHooks()
        SetupObjectiveTrackerHooks()
        FQL:CreateMainFrame()
        FQL:CreateOptionsPanel()
        ScheduleTrackerRefresh()
        return
    end

    if event == "UPDATE_BINDINGS" then
        UpdateKeybindOverrides()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        if FQL._needsBindingUpdate then
            UpdateKeybindOverrides()
        end
        if FQL._needsTrackerCombatRefresh then
            FQL._needsTrackerCombatRefresh = false
            FQL:RefreshObjectiveTracker()
        end
        SuppressMapQuestLog()
        SetupObjectiveTrackerHooks()
        ScheduleRefresh()
        return
    end

    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        ScheduleTrackerRefresh()
        return
    end

    if event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then
        return
    end

    local isWatchOrQuestChange = (
        event == "QUEST_WATCH_UPDATE" or
        event == "QUEST_LOG_UPDATE" or
        event == "QUEST_LOG_CRITERIA_UPDATE" or
        event == "QUEST_POI_UPDATE" or
        event == "UNIT_QUEST_LOG_CHANGED" or
        event == "QUEST_WATCH_LIST_CHANGED" or
        event == "QUEST_ACCEPTED" or
        event == "QUEST_REMOVED" or
        event == "QUEST_TURNED_IN"
    )
    ScheduleRefresh(isWatchOrQuestChange)
end)
