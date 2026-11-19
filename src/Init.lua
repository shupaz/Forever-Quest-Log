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
        self._scrollSelectedQuestIntoView = true
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
        if FQL.ResetToDefaults then
            FQL:ResetToDefaults()
        else
            shupazForeverQuestLogDB.pos = nil
            shupazForeverQuestLogDB.useDefaultPosition = true
            FQL:SetScale(1.0)
            FQL:RestorePosition()
            FQL:Open()
        end
        return
    end
    if msg == "tracker" then
        local order = { "AUTO", "ZONE", "COMPLETION", "LEVEL", "LEVEL_DESC", "ALPHA" }
        local cur = (FQL.GetTrackerSortMode and FQL:GetTrackerSortMode()) or (shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerSortMode) or "AUTO"
        local nextMode = "AUTO"
        for i, m in ipairs(order) do
            if m == cur then
                nextMode = order[(i % #order) + 1]
                break
            end
        end
        if FQL.SetTrackerSortMode then
            FQL:SetTrackerSortMode(nextMode)
        else
            shupazForeverQuestLogDB.trackerSortMode = nextMode
            shupazForeverQuestLogDB.trackerByZone = true
            FQL:RefreshObjectiveTracker()
        end
        local labels = {
            AUTO = "Automatic",
            ZONE = "Group by Zone",
            COMPLETION = "Group by Completion Status",
            LEVEL = "List by Level",
            LEVEL_DESC = "List by Level (High to Low)",
            ALPHA = "List Alphabetically",
        }
        print("|cffffd200shupaz ForeverQuestLog:|r Objective Tracker grouping & sorting set to " .. (labels[nextMode] or nextMode) .. ".")
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

local function ScheduleQuestLogRefresh()
    if refreshQueued then return end
    if not FQL.frame or not FQL.frame:IsShown() then return end
    refreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            refreshQueued = false
            if FQL.frame and FQL.frame:IsShown() then
                FQL:Refresh()
            end
        end)
    else
        refreshQueued = false
        FQL:Refresh()
    end
end

local function ScheduleRefresh(forceTrackerRebuild)
    ScheduleTrackerRefresh(forceTrackerRebuild)
    ScheduleQuestLogRefresh()
end

FQL.ScheduleTrackerRefresh = ScheduleTrackerRefresh
FQL.ScheduleRefresh = ScheduleRefresh

local function AutoTrackAcceptedQuest(arg1, arg2)
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.autoTrackQuests == false then
        return
    end
    if not FQL.SetQuestWatchedByID or not FQL.IsQuestWatchedByID then
        return
    end

    -- Support both modern (questID) and legacy (questLogIndex, questID) QUEST_ACCEPTED payloads
    local questID = SafeNum(arg2)
    local logIndex
    if questID and questID > 0 then
        logIndex = SafeNum(arg1)
    else
        questID = SafeNum(arg1)
    end
    if not questID or questID <= 0 then
        return
    end

    local function TryTrackQuest()
        local idx = logIndex or (FQL.GetLogIndexForQuest and FQL.GetLogIndexForQuest(questID))
        if idx and FQL.GetLogEntryInfo then
            local info = FQL.GetLogEntryInfo(idx)
            if info and (info.isHidden or info.isBounty or info.isHeader) then
                return true
            end
        end
        if FQL.IsQuestWatchedByID(questID, idx) then
            return true
        end
        FQL.SetQuestWatchedByID(questID, idx, true)
        if C_QuestLog and C_QuestLog.SortQuestWatches then
            pcall(C_QuestLog.SortQuestWatches)
        end
        return FQL.IsQuestWatchedByID(questID, idx)
    end

    if not TryTrackQuest() and C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if TryTrackQuest() then
                ScheduleTrackerRefresh(true)
            end
        end)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
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
        shupazForeverQuestLogDB.trackerByZone = true

        shupazForeverQuestLogCharDB = shupazForeverQuestLogCharDB or {}
        for k, v in pairs(CHAR_DEFAULTS) do
            if shupazForeverQuestLogCharDB[k] == nil then
                shupazForeverQuestLogCharDB[k] = type(v) == "table" and {} or v
            end
        end
        if FQL.SyncTrackedQuestsWithLog then
            FQL.SyncTrackedQuestsWithLog()
        end

        FQL.selectedQuestID = shupazForeverQuestLogCharDB.selectedQuestID
        SetupMapAndBindingHooks()
        SetupObjectiveTrackerHooks()
        FQL:CreateMainFrame()
        pcall(FQL.CreateOptionsPanel, FQL)
        ScheduleTrackerRefresh()
        return
    end

    if event == "UPDATE_BINDINGS" then
        UpdateKeybindOverrides()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        -- Item info arrives frequently during gear swaps / bag updates; only refresh the
        -- Quest Log UI if it is open, never rebuild the Objective Tracker.
        ScheduleQuestLogRefresh()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if FQL._needsBindingUpdate then
            UpdateKeybindOverrides()
        end
        if FQL._needsTrackerCombatRefresh then
            FQL._needsTrackerCombatRefresh = false
        end
        SuppressMapQuestLog()
        SetupObjectiveTrackerHooks()
        ScheduleRefresh()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if FQL._needsBindingUpdate then
            UpdateKeybindOverrides()
        end
        if FQL._needsTrackerCombatRefresh then
            FQL._needsTrackerCombatRefresh = false
            ScheduleTrackerRefresh()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        ScheduleQuestLogRefresh()
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        ScheduleTrackerRefresh()
        return
    end

    if event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then
        if type(arg1) == "string" and arg1:match("^party%d+$") and FQL.frame and FQL.frame:IsShown() then
            FQL:Refresh()
        end
        return
    end

    if event == "QUEST_ACCEPTED" then
        AutoTrackAcceptedQuest(arg1, arg2)
    elseif event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
        local removedID = SafeNum(arg1)
        if removedID and shupazForeverQuestLogCharDB and shupazForeverQuestLogCharDB.trackedQuests then
            shupazForeverQuestLogCharDB.trackedQuests[removedID] = nil
        end
        if FQL.PromoteTrackedQuestToNative then
            FQL.PromoteTrackedQuestToNative()
        end
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
