local _, FQL = ...

local pinPool = {}
local activePins = {}
local mapPinTooltip = nil
local highlightPin = nil
local highlightedQuestID = nil
local highlightExpireTime = 0

local ROLE_LABELS = {
    [1] = "|cff66ccffStarts Quest|r",
    [2] = "|cff88ff88Provided|r",
    [3] = "|cffffd100Objective|r",
    [4] = "|cffffaa44Required|r",
    [5] = "|cffb080ffReward|r",
}

local function GetMapPinTooltip()
    if mapPinTooltip then return mapPinTooltip end
    mapPinTooltip = CreateFrame("GameTooltip", "shupaz_ForeverQuestLogMapPinTooltip", UIParent, "GameTooltipTemplate")
    mapPinTooltip:SetFrameStrata("TOOLTIP")
    mapPinTooltip:SetFrameLevel(9999)
    return mapPinTooltip
end

local function GetCanvas()
    if not WorldMapFrame then return nil end
    if WorldMapFrame.GetCanvas then
        local ok, canvas = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
        if ok and canvas then return canvas end
    end
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        return WorldMapFrame.ScrollContainer.Child
    end
    return nil
end

local function GetCanvasScale()
    if WorldMapFrame and WorldMapFrame.GetCanvasScale then
        local ok, scale = pcall(WorldMapFrame.GetCanvasScale, WorldMapFrame)
        if ok and type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvasScale then
        local ok, scale = pcall(WorldMapFrame.ScrollContainer.GetCanvasScale, WorldMapFrame.ScrollContainer)
        if ok and type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    return 1.0
end

local function PositionPinOnCanvas(pin, canvas, canvasWidth, canvasHeight, pinScale)
    if not pin or not canvas or not pin.normX or not pin.normY then return end
    pin:SetScale(pinScale)
    local xPos = (pin.normX * canvasWidth) / pinScale
    local yPos = -(pin.normY * canvasHeight) / pinScale
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", xPos, yPos)
end

local function ShowPinTooltip(pin)
    local db = _G.shupazForeverQuestLogDB or FQL.DB_DEFAULTS
    if db and db.showTooltips == false then return end
    if not pin or not pin.quests or #pin.quests == 0 then return end

    local tip = GetMapPinTooltip()
    tip:SetOwner(pin, "ANCHOR_RIGHT")
    tip:ClearLines()

    local giverName = pin.giverName or "Quest Giver"
    local giverType = pin.giverType or 1
    local typeBadge = (giverType == 2 and "|cffaaaaaa(Object)|r") or (giverType == 3 and "|cff66ccff(Item Drop)|r") or ""
    if typeBadge ~= "" then
        tip:AddDoubleLine(giverName, typeBadge, 1, 0.82, 0, 0.7, 0.7, 0.7)
    else
        tip:AddLine(giverName, 1, 0.82, 0)
    end

    local mapName = (FQL.QuestData and FQL.QuestData.mapNames and FQL.QuestData.mapNames[pin.uiMapID]) or ""
    local coordText = string.format("(%.1f, %.1f)", pin.x or 0, pin.y or 0)
    if mapName ~= "" then
        tip:AddLine(mapName .. " " .. coordText, 0.65, 0.65, 0.65)
    else
        tip:AddLine(coordText, 0.65, 0.65, 0.65)
    end

    local QD = FQL.QuestData
    local itemNames = QD and QD.itemNames or {}

    for i = 1, #pin.quests do
        local qInfo = pin.quests[i]
        local qEntry = qInfo.qEntry
        local qid = qInfo.questID
        local qName = qEntry[1] or ("Quest #" .. tostring(qid))
        local reqLvl = qEntry[2] or 1
        local qLvl = qEntry[3] or reqLvl
        local flags = qEntry[11] or 0

        tip:AddLine(" ")

        local r, g, b = 1, 0.82, 0
        if FQL.GetDifficultyColor then
            r, g, b = FQL.GetDifficultyColor(qLvl)
        end
        local prefix = string.format("[%d] ", qLvl)
        local suffix = ""
        if bit and bit.band(flags, 2) ~= 0 then
            suffix = suffix .. " |cff88ccff[Dungeon/Group]|r"
        end
        if bit and bit.band(flags, 1) ~= 0 then
            suffix = suffix .. " |cff00ccff[Repeatable]|r"
        end
        if bit and bit.band(flags, 4) ~= 0 then
            suffix = suffix .. " |cffff99cc[World Event]|r"
        end
        if qInfo.isHighLevel then
            suffix = suffix .. string.format(" |cffff4444(Req Lv %d)|r", reqLvl)
        end

        tip:AddDoubleLine(prefix .. qName .. suffix, "|cff777777ID: " .. tostring(qid) .. "|r", r, g, b, 0.5, 0.5, 0.5)

        local objText = qEntry[17]
        if objText and objText ~= "" then
            local shortObj = objText
            if #shortObj > 110 then
                shortObj = shortObj:sub(1, 107) .. "..."
            end
            tip:AddLine("  " .. shortObj, 0.85, 0.85, 0.85, true)
        end

        local items = qEntry[16]
        if type(items) == "table" and #items > 0 then
            local maxItems = math.min(#items, 4)
            for j = 1, maxItems do
                local pair = items[j]
                local iid = pair[1]
                local role = pair[2]
                local iname = itemNames[iid] or ("Item #" .. tostring(iid))
                local roleLbl = ROLE_LABELS[role] or "Item"
                tip:AddDoubleLine("    • " .. iname, roleLbl, 0.9, 0.8, 0.5, 0.7, 0.7, 0.7)
            end
            if #items > maxItems then
                tip:AddLine(string.format("    |cff888888+ %d more item(s)...|r", #items - maxItems))
            end
        end
    end

    tip:AddLine(" ")
    tip:AddLine("|cff88ff88Left-Click:|r Inspect in Quest Search DB", 0.7, 0.7, 0.7)
    tip:AddLine("|cff88ff88Shift+Left-Click:|r Copy Wowhead URL", 0.7, 0.7, 0.7)
    tip:AddLine("|cff88ff88Shift+Right-Click:|r Hide Inactive Pin", 0.7, 0.7, 0.7)
    tip:Show()
end

local function CreateMapPin(canvas)
    local pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(18, 18)
    pin:SetFrameStrata("HIGH")
    pin:SetFrameLevel(2200)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local glow = pin:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(28, 28)
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.35)
    pin.glow = glow

    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    pin.icon = icon

    local hlRing = pin:CreateTexture(nil, "OVERLAY")
    hlRing:SetSize(34, 34)
    hlRing:SetPoint("CENTER")
    hlRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    hlRing:SetBlendMode("ADD")
    hlRing:Hide()
    pin.hlRing = hlRing

    pin:SetScript("OnEnter", function(self)
        self.glow:SetAlpha(0.85)
        ShowPinTooltip(self)
    end)

    pin:SetScript("OnLeave", function(self)
        self.glow:SetAlpha(0.35)
        if mapPinTooltip then
            mapPinTooltip:Hide()
        end
    end)

    pin:SetScript("OnClick", function(self, button)
        if not self.quests or #self.quests == 0 then return end
        local primaryQuestID = self.quests[1].questID
        local primaryName = self.quests[1].qEntry and self.quests[1].qEntry[1] or ("Quest #" .. tostring(primaryQuestID))
        if IsShiftKeyDown and IsShiftKeyDown() then
            if button == "RightButton" then
                for i = 1, #self.quests do
                    local qid = self.quests[i].questID
                    if FQL.SetQuestHiddenByUser then
                        FQL:SetQuestHiddenByUser(qid, true)
                    end
                end
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffForever Quest Log:|r Hid map pin for |cffffd100[" .. tostring(primaryName) .. "]|r. (Restore in |cff88ff88/fql options|r or |cff88ff88/fql search|r)")
                end
                FQL:RefreshMapQuestPins()
                if FQL.RefreshQuestSearch then
                    FQL:RefreshQuestSearch()
                end
            else
                local url = FQL.GetQuestWebURL and FQL.GetQuestWebURL(primaryQuestID) or ("https://www.wowhead.com/forever/quest=" .. tostring(primaryQuestID))
                if FQL.ShowCopyURLPopup then
                    FQL:ShowCopyURLPopup(url, primaryName)
                end
            end
        else
            if FQL.OpenQuestSearch then
                FQL:OpenQuestSearch(primaryQuestID)
            end
        end
    end)

    return pin
end

local function AcquirePin(canvas)
    local pin = table.remove(pinPool)
    if not pin then
        pin = CreateMapPin(canvas)
    else
        pin:SetParent(canvas)
    end
    pin:Show()
    activePins[#activePins + 1] = pin
    return pin
end

local function ReleaseAllPins()
    for i = #activePins, 1, -1 do
        local pin = activePins[i]
        pin:Hide()
        pin:ClearAllPoints()
        pin.quests = nil
        pinPool[#pinPool + 1] = pin
        activePins[i] = nil
    end
    if mapPinTooltip then
        mapPinTooltip:Hide()
    end
end

function FQL:UpdateMapPinPositions()
    if #activePins == 0 then return end
    local canvas = GetCanvas()
    if not canvas then return end
    local width = canvas:GetWidth()
    local height = canvas:GetHeight()
    if not width or width <= 0 or not height or height <= 0 then return end

    local canvasScale = GetCanvasScale()
    local pinScale = 1.0 / math.max(0.5, math.min(canvasScale, 2.5))

    for i = 1, #activePins do
        PositionPinOnCanvas(activePins[i], canvas, width, height, pinScale)
    end
end

function FQL:RefreshMapQuestPins()
    ReleaseAllPins()

    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end

    local db = _G.shupazForeverQuestLogDB or FQL.DB_DEFAULTS
    local showMapQuests = (db.showMapAvailableQuests ~= false)

    local QD = self.QuestData
    if not QD or not QD.byMap or not QD.quests then
        return
    end

    local uiMapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    if not uiMapID or uiMapID <= 0 then
        return
    end

    local canvas = GetCanvas()
    if not canvas then return end
    local width = canvas:GetWidth()
    local height = canvas:GetHeight()
    if not width or width <= 0 or not height or height <= 0 then return end

    local now = GetTime and GetTime() or 0
    local activeHighlightID = (highlightedQuestID and now < highlightExpireTime) and highlightedQuestID or nil
    if not activeHighlightID then
        highlightedQuestID = nil
    end

    if not showMapQuests and not activeHighlightID then
        return
    end

    local mapSpawns = QD.byMap[uiMapID]
    if not mapSpawns or #mapSpawns == 0 then
        return
    end

    local groups = {}
    local seenQuestInGroup = {}

    for i = 1, #mapSpawns do
        local sp = mapSpawns[i]
        local qid = sp[1]
        local x = sp[2]
        local y = sp[3]
        local giverName = sp[4]
        local giverType = sp[5]
        local qEntry = QD.quests[qid]

        if qEntry and x and y then
            local isHighlighted = (activeHighlightID == qid)
            local shouldShow = false
            local isLow = false
            local isHigh = false

            if isHighlighted then
                shouldShow = true
                local _, low, high = self:PassesLevelThreshold(qEntry, true)
                isLow = low
                isHigh = high
            elseif showMapQuests then
                local status = self:GetDatabaseQuestStatus(qid, qEntry)
                if status == "AVAILABLE" or (status == "HIGH_LEVEL" and db.showUpcomingHighLevelQuests == true) then
                    local passes, low, high = self:PassesLevelThreshold(qEntry, false)
                    if passes then
                        shouldShow = true
                        isLow = low
                        isHigh = high
                    end
                end
            end

            if shouldShow then
                -- Find an existing group at nearly the same coordinate
                local matchedGroup = nil
                for gIdx = 1, #groups do
                    local g = groups[gIdx]
                    local dx = g.x - x
                    local dy = g.y - y
                    if (dx * dx + dy * dy) <= 0.65 then
                        matchedGroup = g
                        break
                    end
                end

                if not matchedGroup then
                    matchedGroup = {
                        uiMapID = uiMapID,
                        x = x,
                        y = y,
                        giverName = giverName,
                        giverType = giverType,
                        quests = {},
                        questSet = {},
                        hasHighlight = false,
                        allLowLevel = true,
                        allHighLevel = true,
                        anyRepeatable = false,
                    }
                    groups[#groups + 1] = matchedGroup
                end

                if not matchedGroup.questSet[qid] then
                    matchedGroup.questSet[qid] = true
                    local flags = qEntry[11] or 0
                    if bit and bit.band(flags, 1) ~= 0 then
                        matchedGroup.anyRepeatable = true
                    end
                    if not isLow then
                        matchedGroup.allLowLevel = false
                    end
                    if not isHigh then
                        matchedGroup.allHighLevel = false
                    end
                    if isHighlighted then
                        matchedGroup.hasHighlight = true
                    end
                    matchedGroup.quests[#matchedGroup.quests + 1] = {
                        questID = qid,
                        qEntry = qEntry,
                        isLowLevel = isLow,
                        isHighLevel = isHigh,
                    }
                end
            end
        end
    end

    local canvasScale = GetCanvasScale()
    local pinScale = 1.0 / math.max(0.5, math.min(canvasScale, 2.5))

    for i = 1, #groups do
        local g = groups[i]
        table.sort(g.quests, function(a, b)
            local la = a.qEntry[3] or a.qEntry[2] or 1
            local lb = b.qEntry[3] or b.qEntry[2] or 1
            if la ~= lb then return la < lb end
            return a.questID < b.questID
        end)

        local pin = AcquirePin(canvas)
        pin.uiMapID = g.uiMapID
        pin.x = g.x
        pin.y = g.y
        pin.normX = g.x / 100.0
        pin.normY = g.y / 100.0
        pin.giverName = g.giverName
        pin.giverType = g.giverType
        pin.quests = g.quests

        -- Icon styling
        if g.anyRepeatable then
            pin.icon:SetTexture("Interface\\GossipFrame\\DailyQuestIcon")
            if pin.icon.SetDesaturated then pin.icon:SetDesaturated(false) end
            pin.icon:SetVertexColor(1, 1, 1, 1)
        elseif g.allHighLevel then
            pin.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
            if pin.icon.SetDesaturated then pin.icon:SetDesaturated(false) end
            pin.icon:SetVertexColor(1.0, 0.35, 0.25, 1)
        elseif g.allLowLevel then
            pin.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
            if pin.icon.SetDesaturated then pin.icon:SetDesaturated(true) end
            pin.icon:SetVertexColor(0.78, 0.78, 0.78, 0.9)
        else
            pin.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
            if pin.icon.SetDesaturated then pin.icon:SetDesaturated(false) end
            pin.icon:SetVertexColor(1, 1, 1, 1)
        end

        if g.hasHighlight then
            pin.hlRing:Show()
            pin:SetFrameLevel(2350)
        else
            pin.hlRing:Hide()
            pin:SetFrameLevel(2200)
        end

        PositionPinOnCanvas(pin, canvas, width, height, pinScale)
    end
end

function FQL:HighlightQuestOnMap(questID)
    questID = tonumber(questID)
    if not questID or not self.QuestData or not self.QuestData.quests then return end
    local qEntry = self.QuestData.quests[questID]
    if not qEntry then return end

    local uiMapID = qEntry[4]
    if not uiMapID or uiMapID <= 0 then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("No world map location recorded for this quest.", 1, 0.82, 0)
        end
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Cannot open map in combat.", 1, 0.1, 0.1)
        end
        return
    end

    highlightedQuestID = questID
    highlightExpireTime = (GetTime and GetTime() or 0) + 10

    if self.SetQuestLogCVarClosed then
        self.SetQuestLogCVarClosed()
    end
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "miniWorldMap", "1")
    elseif SetCVar then
        pcall(SetCVar, "miniWorldMap", "1")
    end

    if C_Map and C_Map.OpenWorldMap then
        pcall(C_Map.OpenWorldMap, uiMapID)
    elseif ToggleWorldMap then
        if not (WorldMapFrame and WorldMapFrame:IsShown()) then
            pcall(ToggleWorldMap)
        end
        if WorldMapFrame and WorldMapFrame.SetMapID then
            pcall(WorldMapFrame.SetMapID, WorldMapFrame, uiMapID)
        end
    end

    if WorldMapFrame and WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() then
        if WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.Minimize then
            pcall(WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.Minimize, WorldMapFrame.BorderFrame.MaximizeMinimizeFrame)
        elseif WorldMapFrame.Minimize then
            pcall(WorldMapFrame.Minimize, WorldMapFrame)
        end
    end

    self:RefreshMapQuestPins()
end

function FQL:InitMapQuests()
    if self._mapQuestsInitialized then return end
    if not WorldMapFrame then return end
    self._mapQuestsInitialized = true

    WorldMapFrame:HookScript("OnShow", function()
        FQL:RefreshMapQuestPins()
    end)

    WorldMapFrame:HookScript("OnHide", function()
        if mapPinTooltip then
            mapPinTooltip:Hide()
        end
    end)

    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            FQL:RefreshMapQuestPins()
        end)
    end

    if WorldMapFrame.OnCanvasScaleChanged then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function()
            FQL:UpdateMapPinPositions()
        end)
    end

    WorldMapFrame:HookScript("OnSizeChanged", function()
        FQL:UpdateMapPinPositions()
    end)

    local canvas = GetCanvas()
    if canvas then
        canvas:HookScript("OnSizeChanged", function()
            FQL:UpdateMapPinPositions()
        end)
    end

    if not self._mapNPCEventFrame then
        local evFrame = CreateFrame("Frame", "shupaz_ForeverQuestLogMapNPCEventFrame")
        evFrame:RegisterEvent("GOSSIP_SHOW")
        evFrame:RegisterEvent("QUEST_GREETING")
        evFrame:RegisterEvent("QUEST_DETAIL")
        evFrame:RegisterEvent("SKILL_LINES_CHANGED")
        evFrame:RegisterEvent("UPDATE_FACTION")
        evFrame:SetScript("OnEvent", function(_, event)
            if event == "SKILL_LINES_CHANGED" or event == "UPDATE_FACTION" then
                if FQL.InvalidateSkillAndRepCache then
                    FQL:InvalidateSkillAndRepCache()
                end
                if WorldMapFrame and WorldMapFrame:IsShown() then
                    FQL:RefreshMapQuestPins()
                end
                return
            end

            local QD = FQL.QuestData
            if not QD or not QD.byMap or not QD.quests then return end

            if event == "QUEST_DETAIL" then
                if GetQuestID then
                    local ok, qid = pcall(GetQuestID)
                    if ok and type(qid) == "number" and qid > 0 then
                        FQL.sessionInactiveQuests[qid] = nil
                    end
                end
                return
            end

            -- GOSSIP_SHOW or QUEST_GREETING: verify NPC's offered quests against static DB
            local guid = UnitGUID and (UnitGUID("npc") or UnitGUID("target"))
            if type(guid) ~= "string" or FQL.IsSecret(guid) then return end
            local unitType, _, _, _, _, npcIDStr = strsplit("-", guid)
            if unitType ~= "Creature" and unitType ~= "Vehicle" then return end
            local npcID = tonumber(npcIDStr)
            if not npcID or npcID <= 0 then return end

            local offeredIDs = {}
            local offeredTitles = {}

            if event == "GOSSIP_SHOW" and C_GossipInfo and C_GossipInfo.GetAvailableQuests then
                local ok, list = pcall(C_GossipInfo.GetAvailableQuests)
                if ok and type(list) == "table" then
                    for i = 1, #list do
                        local q = list[i]
                        if type(q) == "table" then
                            if type(q.questID) == "number" and q.questID > 0 then
                                offeredIDs[q.questID] = true
                            end
                            if type(q.title) == "string" and q.title ~= "" then
                                offeredTitles[q.title:lower()] = true
                            end
                        end
                    end
                end
            elseif event == "QUEST_GREETING" and GetNumAvailableQuests then
                local okN, num = pcall(GetNumAvailableQuests)
                if okN and type(num) == "number" and num > 0 then
                    for i = 1, num do
                        if GetAvailableTitle then
                            local okT, title = pcall(GetAvailableTitle, i)
                            if okT and type(title) == "string" and title ~= "" then
                                offeredTitles[title:lower()] = true
                            end
                        end
                        if GetAvailableQuestInfo then
                            local okI, _, _, _, _, qid = pcall(GetAvailableQuestInfo, i)
                            if okI and type(qid) == "number" and qid > 0 then
                                offeredIDs[qid] = true
                            end
                        end
                    end
                end
            end

            local changed = false
            local mapsToCheck = {}
            if C_Map and C_Map.GetBestMapForUnit then
                local okM, pMap = pcall(C_Map.GetBestMapForUnit, "player")
                if okM and type(pMap) == "number" and pMap > 0 then
                    mapsToCheck[pMap] = true
                end
            end
            if WorldMapFrame and WorldMapFrame.GetMapID then
                local wMap = WorldMapFrame:GetMapID()
                if type(wMap) == "number" and wMap > 0 then
                    mapsToCheck[wMap] = true
                end
            end

            for mID in pairs(mapsToCheck) do
                local spawns = QD.byMap[mID]
                if type(spawns) == "table" then
                    for i = 1, #spawns do
                        local sp = spawns[i]
                        if sp[5] == 1 and sp[6] == npcID then
                            local qid = sp[1]
                            local qEntry = QD.quests[qid]
                            local qTitle = qEntry and qEntry[1] and qEntry[1]:lower() or nil
                            if offeredIDs[qid] or (qTitle and offeredTitles[qTitle]) then
                                if FQL.sessionInactiveQuests[qid] then
                                    FQL.sessionInactiveQuests[qid] = nil
                                    changed = true
                                end
                            else
                                local status = FQL:GetDatabaseQuestStatus(qid, qEntry)
                                if status == "AVAILABLE" then
                                    FQL.sessionInactiveQuests[qid] = true
                                    changed = true
                                end
                            end
                        end
                    end
                end
            end

            if changed and WorldMapFrame and WorldMapFrame:IsShown() then
                FQL:RefreshMapQuestPins()
            end
        end)
        self._mapNPCEventFrame = evFrame
    end
end
