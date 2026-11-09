local ADDON_NAME, FQL = ...
if type(FQL) ~= "table" then
    FQL = {}
end
_G.shupaz_ForeverQuestLog = FQL

FQL.ADDON_NAME = ADDON_NAME or "shupaz_ForeverQuestLog"
FQL.VERSION = "1.0.1"

-- Keybinding label in Options > Keybindings > AddOns
BINDING_HEADER_SHUPAZ_FOREVERQUESTLOG = "shupaz ForeverQuestLog"
BINDING_NAME_SHUPAZ_FOREVERQUESTLOG_TOGGLE = "Toggle Quest Log"
_G["BINDING_HEADER_SHUPAZ_FOREVERQUESTLOG"] = "shupaz ForeverQuestLog"
_G["BINDING_NAME_SHUPAZ_FOREVERQUESTLOG_TOGGLE"] = "Toggle Quest Log"
_G["BINDING_HEADER_FOREVERQUESTLOG"] = "shupaz ForeverQuestLog"
_G["BINDING_NAME_FOREVERQUESTLOG_TOGGLE"] = "Toggle Quest Log"

local MIN_SCALE, MAX_SCALE = 0.6, 1.6
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 730, 520
FQL.MIN_SCALE = MIN_SCALE
FQL.MAX_SCALE = MAX_SCALE
FQL.DEFAULT_WIDTH = DEFAULT_WIDTH
FQL.DEFAULT_HEIGHT = DEFAULT_HEIGHT

local DB_DEFAULTS = {
    scale = 1.0,
    lockWindow = false,
    useDefaultPosition = true,
    hideMapQuestLog = true,
    showQuestLevels = true,
    showTooltips = true,
    trackerByZone = true,
    trackerCurrentZoneFirst = true,
    trackerShowZoneCount = true,
    trackerScale = 1.0,
    trackerFont = "DEFAULT",
}
FQL.DB_DEFAULTS = DB_DEFAULTS

local CHAR_DEFAULTS = {
    collapsedHeaders = {},
    collapsedTrackerZones = {},
    selectedQuestID = nil,
}
FQL.CHAR_DEFAULTS = CHAR_DEFAULTS

-- ============================================================
-- Public Window Controls & Addon Compartment / Slash Commands
-- ============================================================

function FQL:Open()
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
        frame:Show()
    end
end

function FQL:OpenToQuest(questID)
    questID = SafeNum(questID)
    self:CreateMainFrame()
    if questID and questID > 0 then
        self.selectedQuestID = questID
        if shupazForeverQuestLogCharDB then
            shupazForeverQuestLogCharDB.selectedQuestID = questID
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

_G["BINDING_HEADER_SHUPAZ_FOREVERQUESTLOG"] = "shupaz ForeverQuestLog"
_G["BINDING_NAME_SHUPAZ_FOREVERQUESTLOG_TOGGLE"] = "Toggle Quest Log"
_G["BINDING_HEADER_FOREVERQUESTLOG"] = "shupaz ForeverQuestLog"
_G["BINDING_NAME_FOREVERQUESTLOG_TOGGLE"] = "Toggle Quest Log"

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
    if msg == "fixmenu" then
        InitializeMicroMenuButtons()
        print("|cff00ff00[Forever Quest Log]|r Re-registered Micro Menu buttons.")
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

local function SetupObjectiveTrackerHooks(...)
    if FQL.SetupObjectiveTrackerHooks then
        return FQL.SetupObjectiveTrackerHooks(...)
    end
end

local function SetupMapAndBindingHooks(...)
    if FQL.SetupMapAndBindingHooks then
        return FQL.SetupMapAndBindingHooks(...)
    end
end

local function UpdateKeybindOverrides(...)
    if FQL.UpdateKeybindOverrides then
        return FQL.UpdateKeybindOverrides(...)
    end
end

local function InitializeMicroMenuButtons(...)
    if FQL.InitializeMicroMenuButtons then
        return FQL.InitializeMicroMenuButtons(...)
    end
end

local function SuppressMapQuestLog(...)
    if FQL.SuppressMapQuestLog then
        return FQL.SuppressMapQuestLog(...)
    end
end

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
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_ObjectiveTracker" then
            SetupObjectiveTrackerHooks()
            ScheduleTrackerRefresh()
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
        InitializeMicroMenuButtons()
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
