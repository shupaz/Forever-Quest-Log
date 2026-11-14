local ADDON_NAME, FQL = ...

local SafeNum                 = FQL.SafeNum
local SafeStr                 = FQL.SafeStr
local CanChangeFrame          = FQL.CanChangeFrame
local SetBackdrop             = FQL.SetBackdrop
local PlayClickSound          = FQL.PlayClickSound

local ExpandAllNativeHeaders  = FQL.ExpandAllNativeHeaders
local GetNumLogEntries        = FQL.GetNumLogEntries
local GetLogEntryInfo         = FQL.GetLogEntryInfo
local IsQuestWatchedByID      = FQL.IsQuestWatchedByID
local SetQuestWatchedByID     = FQL.SetQuestWatchedByID
local IsQuestCompleteOrFailed = FQL.IsQuestCompleteOrFailed
local GetDifficultyColor      = FQL.GetDifficultyColor

local MIN_SCALE               = FQL.MIN_SCALE or 0.6
local MAX_SCALE               = FQL.MAX_SCALE or 1.6

-- ============================================================
-- Private State Tables (Zero Custom Keys on Blizzard Tables)
-- ============================================================

local TState = setmetatable({}, { __mode = "k" })
local BState = setmetatable({}, { __mode = "k" })
local FState = setmetatable({}, { __mode = "k" })
local WheelHooked = setmetatable({}, { __mode = "k" })
local CustomZoneHeaders = setmetatable({}, { __mode = "k" })

local function TS(tracker)
    if not tracker then return {} end
    local s = TState[tracker]
    if not s then
        s = {}
        TState[tracker] = s
    end
    return s
end

local function BS(block)
    if not block then return {} end
    local s = BState[block]
    if not s then
        s = {}
        BState[block] = s
    end
    return s
end

local function FS(fs)
    if not fs then return {} end
    local s = FState[fs]
    if not s then
        s = {}
        FState[fs] = s
    end
    return s
end

-- ============================================================
-- Objective Tracker Collapsible Zone Headers
-- ============================================================

local TRACKER_ZONE_HEADER_HEIGHT = 22
local TRACKER_ZONE_HEADER_GAP_TOP = 12
local TRACKER_ZONE_HEADER_GAP_BOTTOM = 12
local TRACKER_BLOCK_GAP = 8

function FQL:GetQuestZoneLookup()
    ExpandAllNativeHeaders()
    local numShown = GetNumLogEntries()
    local questToZone = {}
    local zoneOrder = {}
    local seenZones = {}
    local currentHeader = "Quests"
    local orderCounter = 0

    for i = 1, numShown do
        local info = GetLogEntryInfo(i)
        if info and not info.isHidden and not info.isBounty and not info.isTask then
            if info.isHeader then
                currentHeader = (info.title and info.title ~= "") and info.title or "Quests"
                if not seenZones[currentHeader] then
                    orderCounter = orderCounter + 1
                    seenZones[currentHeader] = orderCounter
                    zoneOrder[currentHeader] = orderCounter
                end
            elseif info.questID and info.questID > 0 then
                if not seenZones[currentHeader] then
                    orderCounter = orderCounter + 1
                    seenZones[currentHeader] = orderCounter
                    zoneOrder[currentHeader] = orderCounter
                end
                questToZone[info.questID] = {
                    zone = currentHeader,
                    logIndex = i,
                    questOrder = i,
                    completeState = IsQuestCompleteOrFailed(info.questID, info.isComplete),
                    title = info.title,
                    level = SafeNum(info.difficultyLevel) or SafeNum(info.level) or 0,
                    difficultyLevel = SafeNum(info.difficultyLevel) or SafeNum(info.level) or 0,
                }
            end
        end
    end

    return questToZone, zoneOrder
end

function FQL:ResolveQuestZoneName(questID, questToZone)
    if questToZone and questToZone[questID] and questToZone[questID].zone then
        return questToZone[questID].zone
    end
    if GetQuestUiMapID and C_Map and C_Map.GetMapInfo then
        local okM, mapID = pcall(GetQuestUiMapID, questID)
        if okM and SafeNum(mapID) and mapID > 0 then
            local okI, mapInfo = pcall(C_Map.GetMapInfo, mapID)
            if okI and type(mapInfo) == "table" and SafeStr(mapInfo.name) then
                return mapInfo.name
            end
        end
    end
    return "Quests"
end

function FQL:IsTrackerZoneCollapsed(zoneName)
    if not zoneName or not shupazForeverQuestLogCharDB or not shupazForeverQuestLogCharDB.collapsedTrackerZones then
        return false
    end
    return shupazForeverQuestLogCharDB.collapsedTrackerZones[zoneName] == true
end

function FQL:SetTrackerZoneCollapsed(zoneName, collapsed)
    if not zoneName then return end
    shupazForeverQuestLogCharDB = shupazForeverQuestLogCharDB or {}
    shupazForeverQuestLogCharDB.collapsedTrackerZones = shupazForeverQuestLogCharDB.collapsedTrackerZones or {}
    if collapsed then
        shupazForeverQuestLogCharDB.collapsedTrackerZones[zoneName] = true
    else
        shupazForeverQuestLogCharDB.collapsedTrackerZones[zoneName] = nil
    end
    self:RefreshObjectiveTracker()
end

function FQL:ToggleTrackerZone(zoneName)
    if not zoneName then return end
    local isCol = self:IsTrackerZoneCollapsed(zoneName)
    self:SetTrackerZoneCollapsed(zoneName, not isCol)
end

function FQL:SetAllTrackerZonesCollapsed(shouldCollapse)
    shupazForeverQuestLogCharDB = shupazForeverQuestLogCharDB or {}
    shupazForeverQuestLogCharDB.collapsedTrackerZones = shupazForeverQuestLogCharDB.collapsedTrackerZones or {}
    local collapsed = shupazForeverQuestLogCharDB.collapsedTrackerZones
    if not shouldCollapse then
        wipe(collapsed)
    else
        local questToZone = self:GetQuestZoneLookup()
        for _, data in pairs(questToZone) do
            if data.zone then
                collapsed[data.zone] = true
            end
        end
        if _G.QuestObjectiveTracker and TState[_G.QuestObjectiveTracker] and TState[_G.QuestObjectiveTracker].activeZones then
            for _, z in ipairs(TState[_G.QuestObjectiveTracker].activeZones) do
                collapsed[z] = true
            end
        end
        if _G.CampaignQuestObjectiveTracker and TState[_G.CampaignQuestObjectiveTracker] and TState[_G.CampaignQuestObjectiveTracker].activeZones then
            for _, z in ipairs(TState[_G.CampaignQuestObjectiveTracker].activeZones) do
                collapsed[z] = true
            end
        end
    end
    self:RefreshObjectiveTracker()
end

function FQL:ToggleAllTrackerZones(activeZones)
    shupazForeverQuestLogCharDB = shupazForeverQuestLogCharDB or {}
    shupazForeverQuestLogCharDB.collapsedTrackerZones = shupazForeverQuestLogCharDB.collapsedTrackerZones or {}
    local collapsed = shupazForeverQuestLogCharDB.collapsedTrackerZones

    local zones = {}
    local seen = {}
    local function AddZoneList(list)
        if type(list) ~= "table" then return end
        for _, z in ipairs(list) do
            if z and not seen[z] then
                seen[z] = true
                zones[#zones + 1] = z
            end
        end
    end

    if activeZones then
        AddZoneList(activeZones)
    else
        if _G.QuestObjectiveTracker and TState[_G.QuestObjectiveTracker] then
            AddZoneList(TState[_G.QuestObjectiveTracker].activeZones)
        end
        if _G.CampaignQuestObjectiveTracker and TState[_G.CampaignQuestObjectiveTracker] then
            AddZoneList(TState[_G.CampaignQuestObjectiveTracker].activeZones)
        end
        AddZoneList(self._lastTrackerZones)
    end

    if #zones == 0 then
        local questToZone = self:GetQuestZoneLookup()
        for _, data in pairs(questToZone) do
            if data.zone and not seen[data.zone] then
                seen[data.zone] = true
                zones[#zones + 1] = data.zone
            end
        end
    end

    local anyExpanded = false
    for _, z in ipairs(zones) do
        if not collapsed[z] then
            anyExpanded = true
            break
        end
    end

    if anyExpanded then
        for _, z in ipairs(zones) do
            collapsed[z] = true
        end
    else
        wipe(collapsed)
    end

    self:RefreshObjectiveTracker()
end

function FQL:UntrackZoneQuests(zoneName)
    if not zoneName then return end
    local questToZone = self:GetQuestZoneLookup()
    for questID, data in pairs(questToZone) do
        if data.zone == zoneName and IsQuestWatchedByID(questID, data.logIndex) then
            SetQuestWatchedByID(questID, data.logIndex, false)
        end
    end
    if C_QuestLog and C_QuestLog.SortQuestWatches then
        pcall(C_QuestLog.SortQuestWatches)
    end
    self:Refresh()
    self:RefreshObjectiveTracker(true)
end

function FQL:ShowTrackerZoneContextMenu(anchorButton, zoneName)
    if not zoneName then return end
    local menu = self.trackerContextMenu
    if not menu then
        menu = CreateFrame("Frame", "shupaz_ForeverQuestLogTrackerZoneMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        self.trackerContextMenu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetToplevel(true)
        menu:EnableMouse(true)
        SetBackdrop(menu, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
        menu:SetBackdropColor(0.06, 0.055, 0.048, 0.98)
        menu:SetBackdropBorderColor(0.58, 0.45, 0.22, 1)
        menu.items = {}
        menu:SetScript("OnUpdate", function(self, elapsed)
            if self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver()) then
                self.awayTime = 0
            else
                self.awayTime = (self.awayTime or 0) + elapsed
                if self.awayTime > 0.8 then
                    self:Hide()
                end
            end
        end)
    end

    local isCollapsed = self:IsTrackerZoneCollapsed(zoneName)
    local actions = {
        {
            label = isCollapsed and ("Expand " .. zoneName) or ("Collapse " .. zoneName),
            fn = function()
                FQL:ToggleTrackerZone(zoneName)
            end,
        },
        {
            label = "Collapse / Expand All Zones",
            fn = function()
                FQL:ToggleAllTrackerZones()
            end,
        },
        {
            label = "Open in Quest Log",
            fn = function()
                if shupazForeverQuestLogCharDB and shupazForeverQuestLogCharDB.collapsedHeaders then
                    shupazForeverQuestLogCharDB.collapsedHeaders[zoneName] = nil
                end
                local questToZone = FQL:GetQuestZoneLookup()
                local firstQID = nil
                for qid, data in pairs(questToZone) do
                    if data.zone == zoneName then
                        firstQID = qid
                        break
                    end
                end
                if firstQID then
                    FQL:OpenToQuest(firstQID)
                else
                    FQL:Open()
                end
            end,
        },
        {
            label = "|cffff5555Untrack All in " .. zoneName .. "|r",
            fn = function()
                FQL:UntrackZoneQuests(zoneName)
            end,
        },
    }

    local maxWidth = 160
    for i, act in ipairs(actions) do
        local row = menu.items[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(22)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetJustifyH("LEFT")
            menu.items[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 22)
        row:SetPoint("RIGHT", -5, 0)
        row.text:SetText(act.label)
        row.text:SetTextColor(0.95, 0.88, 0.72)
        row:SetScript("OnClick", function()
            PlayClickSound()
            menu:Hide()
            act.fn()
        end)
        local w = (row.text:GetStringWidth() or 120) + 24
        if w > maxWidth then maxWidth = w end
        row:Show()
    end
    for i = #actions + 1, #menu.items do
        menu.items[i]:Hide()
    end

    menu:SetSize(maxWidth, (#actions * 22) + 10)
    menu.anchor = anchorButton
    menu.awayTime = 0
    menu:ClearAllPoints()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", (x / scale) - 4, (y / scale) - 4)
    menu:Show()
end

local function AcquireTrackerZoneHeader(tracker, index)
    local ts = TS(tracker)
    ts.zoneHeaders = ts.zoneHeaders or {}
    local hBtn = ts.zoneHeaders[index]
    if hBtn then return hBtn end

    local parent = tracker.ContentsFrame or tracker
    hBtn = CreateFrame("Button", nil, parent)
    CustomZoneHeaders[hBtn] = true
    hBtn:SetHeight(TRACKER_ZONE_HEADER_HEIGHT)
    hBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hBtn:SetHitRectInsets(-26, 0, 0, 0)

    local bg = hBtn:CreateTexture(nil, "BACKGROUND")
    hBtn.bg = bg
    bg:SetPoint("TOPLEFT", -2, 0)
    bg:SetPoint("BOTTOMRIGHT", 2, 0)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetColorTexture(0.11, 0.08, 0.035, 0.52)

    local line = hBtn:CreateTexture(nil, "BORDER")
    hBtn.line = line
    line:SetPoint("BOTTOMLEFT", -2, 0)
    line:SetPoint("BOTTOMRIGHT", 2, 0)
    line:SetHeight(1)
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetColorTexture(0.76, 0.60, 0.22, 0.48)

    local iconWrap = CreateFrame("Frame", nil, hBtn)
    hBtn.iconWrap = iconWrap
    iconWrap:SetSize(16, 16)
    iconWrap:SetPoint("RIGHT", hBtn, "LEFT", -6, 0)

    local collapseIcon = iconWrap:CreateTexture(nil, "ARTWORK")
    hBtn.collapseIcon = collapseIcon
    collapseIcon:SetAllPoints()
    collapseIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")

    local iconHighlight = iconWrap:CreateTexture(nil, "HIGHLIGHT")
    iconHighlight:SetAllPoints()
    iconHighlight:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    iconHighlight:SetBlendMode("ADD")

    local countText = hBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hBtn.countText = countText
    countText:SetPoint("RIGHT", -4, 0)
    countText:SetJustifyH("RIGHT")

    local titleText = hBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hBtn.titleText = titleText
    titleText:SetPoint("LEFT", 2, 0)
    titleText:SetPoint("RIGHT", countText, "LEFT", -6, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)

    hBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.22, 0.16, 0.06, 0.72)
        self.line:SetColorTexture(0.95, 0.78, 0.30, 0.80)
        self.titleText:SetTextColor(1.0, 0.94, 0.68)
        if GameTooltip and (not shupazForeverQuestLogDB or shupazForeverQuestLogDB.showTooltips ~= false) then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(self.zoneName or "Zone", 1, 0.82, 0)
            local status = self.isCollapsed and "Collapsed" or "Expanded"
            GameTooltip:AddLine(string.format("%d tracked quest(s) (%s)", self.questCount or 0, status), 0.9, 0.9, 0.9)
            GameTooltip:AddLine("Left-Click: Collapse / Expand Zone", 0.65, 0.65, 0.65)
            GameTooltip:AddLine("Shift-Click: Collapse / Expand All Zones", 0.65, 0.65, 0.65)
            GameTooltip:AddLine("Right-Click: Zone Options", 0.65, 0.65, 0.65)
            if tracker and (TS(tracker).maxScrollIndex or 1) > 1 then
                GameTooltip:AddLine("Mouse Wheel: Scroll Tracked List", 0.55, 0.82, 1.0)
            end
            GameTooltip:Show()
        end
    end)

    hBtn:SetScript("OnLeave", function(self)
        if self.isCollapsed then
            self.bg:SetColorTexture(0.08, 0.06, 0.03, 0.42)
            self.line:SetColorTexture(0.55, 0.44, 0.18, 0.32)
            self.titleText:SetTextColor(0.78, 0.67, 0.38)
        else
            self.bg:SetColorTexture(0.11, 0.08, 0.035, 0.52)
            self.line:SetColorTexture(0.76, 0.60, 0.22, 0.48)
            self.titleText:SetTextColor(1.00, 0.82, 0.18)
        end
        if GameTooltip then GameTooltip:Hide() end
    end)

    hBtn:SetScript("OnClick", function(self, button)
        if not self.zoneName then return end
        PlayClickSound()
        if button == "RightButton" then
            FQL:ShowTrackerZoneContextMenu(self, self.zoneName)
            return
        end
        if IsShiftKeyDown and IsShiftKeyDown() then
            FQL:ToggleAllTrackerZones()
            return
        end
        FQL:ToggleTrackerZone(self.zoneName)
    end)

    hBtn:EnableMouseWheel(true)
    hBtn:SetScript("OnMouseWheel", function(_, delta)
        if FQL and FQL.ScrollTrackerByDelta then
            FQL:ScrollTrackerByDelta(tracker, delta)
        end
    end)

    ts.zoneHeaders[index] = hBtn
    return hBtn
end

local function HideAllTrackerZoneHeaders(tracker)
    local ts = TState[tracker]
    if not ts or not ts.zoneHeaders then return end
    for _, hBtn in ipairs(ts.zoneHeaders) do
        hBtn:Hide()
    end
end

local function IsRealTrackerBlock(block)
    if type(block) ~= "table" or not block.GetObjectType then return false end
    if CustomZoneHeaders[block] then return false end
    if (block.GetQuestID or block.SetQuestID) and not block.HeaderText and not block.usedLines then
        return false
    end
    if block.HeaderText ~= nil or block.HeaderButton ~= nil or block.usedLines ~= nil or block.AddObjective ~= nil or block.linePool ~= nil or block.parentModule ~= nil then
        return true
    end
    return false
end

local function CaptureBlockNativeAnchors(block, contents)
    local bs = BS(block)
    local h = SafeNum(block.height) or SafeNum(block:GetHeight())
    if h and h > 8 then
        bs.height = h
    end
    if bs.nativeCaptured then return end
    local numPts = block.GetNumPoints and block:GetNumPoints() or 0
    if numPts == 0 then return end

    local horizPoints = {}
    local leftOffset = SafeNum(block.offsetX)
    local rightOffset = 0
    local topOffset = nil

    for i = 1, numPts do
        local p, rel, rp, x, y = block:GetPoint(i)
        local sx = SafeNum(x) or 0
        local sy = SafeNum(y) or 0
        if p == "LEFT" or p == "RIGHT" then
            horizPoints[#horizPoints + 1] = { p = p, rel = rel or contents, rp = rp or p, x = sx, y = sy }
            if p == "LEFT" and not leftOffset then leftOffset = sx end
            if p == "RIGHT" then rightOffset = sx end
        elseif p == "TOPLEFT" then
            if not leftOffset then leftOffset = sx end
            if not topOffset and (rel == contents) then topOffset = math.abs(sy) end
        elseif p == "TOPRIGHT" then
            rightOffset = sx
        elseif p == "TOP" then
            if not topOffset and (rel == contents) then topOffset = math.abs(sy) end
        end
    end

    bs.horizPoints = horizPoints
    bs.leftOffset = leftOffset or 0
    bs.rightOffset = rightOffset or 0
    if topOffset and topOffset > 0 and topOffset < 30 then
        bs.topOffset = topOffset
    end
    local w = SafeNum(block:GetWidth())
    if w and w > 80 then
        bs.width = w
    end
    bs.nativeCaptured = true
end

local function CollectTrackerBlocksAndAttachments(tracker, questToZone, titleToQuestID)
    local contents = tracker.ContentsFrame or tracker
    local blocksByQuestID = {}
    local orderedQuestBlocks = {}
    local topBannerBlocks = {}
    local seenBlocks = {}

    local function ResolveBlockQuestID(block, keyQuestID)
        local qid = SafeNum(block.id) or SafeNum(keyQuestID) or SafeNum(block.questID)
        if qid and qid > 0 then return qid end
        if block.HeaderText and block.HeaderText.GetText and titleToQuestID then
            local ok, txt = pcall(block.HeaderText.GetText, block.HeaderText)
            local clean = ok and SafeStr(txt)
            if clean then
                clean = clean:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
                if titleToQuestID[clean] then
                    return titleToQuestID[clean]
                end
            end
        end
        return nil
    end

    local function InspectCandidateBlock(block, keyQuestID, fromActiveTable)
        if not IsRealTrackerBlock(block) or seenBlocks[block] then return end
        local bs = BS(block)
        if not (fromActiveTable or block:IsShown() or bs.hiddenByZone or block.used) then return end

        local qid = ResolveBlockQuestID(block, keyQuestID)
        if not qid or qid <= 0 then return end

        if not fromActiveTable and questToZone and not questToZone[qid] then
            return
        end

        seenBlocks[block] = true
        CaptureBlockNativeAnchors(block, contents)

        if not blocksByQuestID[qid] then
            local entry = {
                questID = qid,
                block = block,
                attachments = {},
            }
            blocksByQuestID[qid] = entry
            orderedQuestBlocks[#orderedQuestBlocks + 1] = entry
        end
    end

    if tracker.firstBlock then
        local curr = tracker.firstBlock
        local guard = 0
        while curr and guard < 200 do
            guard = guard + 1
            InspectCandidateBlock(curr, nil, true)
            curr = curr.nextBlock
        end
    end

    if type(tracker.usedBlocks) == "table" then
        for _, templateBlocks in pairs(tracker.usedBlocks) do
            if type(templateBlocks) == "table" then
                for k, block in pairs(templateBlocks) do
                    InspectCandidateBlock(block, k, block.used ~= false)
                end
            end
        end
    end

    if contents and contents.GetChildren then
        for _, child in ipairs({ contents:GetChildren() }) do
            InspectCandidateBlock(child, nil, false)
        end
    end

    local function AddAttachment(entry, frameObj)
        if not entry or not frameObj or frameObj == entry.block then return end
        for _, existing in ipairs(entry.attachments) do
            if existing == frameObj then return end
        end
        entry.attachments[#entry.attachments + 1] = frameObj
    end

    for _, entry in pairs(blocksByQuestID) do
        local b = entry.block
        if b.poiButton then AddAttachment(entry, b.poiButton) end
        if b.ItemButton then AddAttachment(entry, b.ItemButton) end
        if b.itemButton then AddAttachment(entry, b.itemButton) end
        if b.rightEdgeFrame then AddAttachment(entry, b.rightEdgeFrame) end
        if b.groupFinderButton then AddAttachment(entry, b.groupFinderButton) end
    end

    local function ScanChildrenForAttachments(parentFrame)
        if not parentFrame or not parentFrame.GetChildren then return end
        for _, child in ipairs({ parentFrame:GetChildren() }) do
            if not seenBlocks[child] and not CustomZoneHeaders[child] then
                local cQuestID = SafeNum(child.questID)
                if not cQuestID and type(child.GetQuestID) == "function" then
                    local ok, id = pcall(child.GetQuestID, child)
                    if ok then cQuestID = SafeNum(id) end
                end
                if cQuestID and blocksByQuestID[cQuestID] then
                    AddAttachment(blocksByQuestID[cQuestID], child)
                elseif child:IsShown() and parentFrame == contents and IsRealTrackerBlock(child) then
                    topBannerBlocks[#topBannerBlocks + 1] = child
                end
            end
        end
    end

    ScanChildrenForAttachments(contents)
    if tracker ~= contents then
        ScanChildrenForAttachments(tracker)
    end

    return orderedQuestBlocks, topBannerBlocks
end

function FQL:EnsureTrackerHeaderZoneButton(tracker)
    if not tracker or not tracker.Header then return end
    local ts = TS(tracker)
    if ts.headerZoneBtn then return end
    local header = tracker.Header
    local minBtn = header.MinimizeButton or header.FilterButton
    local btn = CreateFrame("Button", nil, header)
    ts.headerZoneBtn = btn
    btn:SetSize(16, 16)
    if minBtn then
        btn:SetPoint("RIGHT", minBtn, "LEFT", -6, 0)
    else
        btn:SetPoint("RIGHT", header, "RIGHT", -28, 0)
    end

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")

    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.hl:SetAllPoints()
    btn.hl:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    btn.hl:SetBlendMode("ADD")

    btn:SetScript("OnClick", function()
        PlayClickSound()
        FQL:ToggleAllTrackerZones()
    end)
    btn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Collapse / Expand All Zones", 1, 0.82, 0)
        GameTooltip:AddLine("Click to collapse or expand all zone sections in the Objective Tracker.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function ApplyFontToFontString(fs, fontPath)
    if not fs or type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then return end
    local ok, curFont, curSize, curFlags = pcall(fs.GetFont, fs)
    if not ok then return end
    local fst = FS(fs)
    if not fst.origFont then
        fst.origFont = SafeStr(curFont) or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
        local sz = SafeNum(curSize) or 12
        if sz <= 0 then sz = 12 end
        fst.origSize = sz
        fst.origFlags = SafeStr(curFlags) or ""
    end
    local targetFont = fontPath or fst.origFont
    local fontScale = (shupazForeverQuestLogDB and SafeNum(shupazForeverQuestLogDB.trackerFontScale)) or 1.0
    if fontScale < 0.5 then fontScale = 0.5 elseif fontScale > 2.5 then fontScale = 2.5 end
    local baseSize = fst.origSize or 12
    if baseSize <= 0 then baseSize = 12 end
    local targetSize = math.max(8, math.floor(baseSize * fontScale + 0.5))
    local flags = SafeStr(curFlags) or fst.origFlags or ""
    if curFont ~= targetFont or curSize ~= targetSize then
        pcall(fs.SetFont, fs, targetFont, targetSize, flags)
    end
end

local function ApplyFontToTrackerBlock(block, fontPath)
    if not block then return end
    if block.HeaderText then
        ApplyFontToFontString(block.HeaderText, fontPath)
    end
    if block.HeaderButton and block.HeaderButton.GetFontString then
        ApplyFontToFontString(block.HeaderButton:GetFontString(), fontPath)
    end
    if type(block.usedLines) == "table" then
        for _, line in pairs(block.usedLines) do
            if type(line) == "table" then
                ApplyFontToFontString(line.Text, fontPath)
                ApplyFontToFontString(line.Dash, fontPath)
            end
        end
    end
    if type(block.lines) == "table" then
        for _, line in pairs(block.lines) do
            if type(line) == "table" then
                ApplyFontToFontString(line.Text, fontPath)
                ApplyFontToFontString(line.Dash, fontPath)
            end
        end
    end
    if block.GetRegions then
        for _, reg in ipairs({ block:GetRegions() }) do
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                ApplyFontToFontString(reg, fontPath)
            end
        end
    end
    if block.GetChildren then
        for _, child in ipairs({ block:GetChildren() }) do
            if child and child ~= block.ItemButton and child ~= block.itemButton and child ~= block.poiButton then
                if child.Text then ApplyFontToFontString(child.Text, fontPath) end
                if child.Dash then ApplyFontToFontString(child.Dash, fontPath) end
                if child.GetRegions then
                    for _, reg in ipairs({ child:GetRegions() }) do
                        if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                            ApplyFontToFontString(reg, fontPath)
                        end
                    end
                end
            end
        end
    end
end

local function ApplyBlockHeaderColor(block, qid, qMeta)
    if not block or not GetDifficultyColor then return end
    local qLevel = (qMeta and (SafeNum(qMeta.difficultyLevel) or SafeNum(qMeta.level))) or 0
    if qLevel <= 0 and qid and qid > 0 then
        if C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
            local ok, dLvl = pcall(C_QuestLog.GetQuestDifficultyLevel, qid)
            if ok and SafeNum(dLvl) and dLvl > 0 then
                qLevel = dLvl
            end
        end
        if qLevel <= 0 and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
            local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, qid)
            if ok and SafeNum(idx) and idx > 0 then
                local ok2, info = pcall(C_QuestLog.GetInfo, idx)
                if ok2 and type(info) == "table" then
                    qLevel = SafeNum(info.difficultyLevel) or SafeNum(info.level) or 0
                end
            end
        end
    end

    local r, g, b = GetDifficultyColor(qLevel, qid)
    local hex = string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))

    local function ColorizeFontString(fs)
        if not fs or type(fs.GetText) ~= "function" then return end
        local ok, txt = pcall(fs.GetText, fs)
        if not ok or not txt or txt == "" then return end

        local clean = txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        pcall(fs.SetText, fs, "|cff" .. hex .. clean .. "|r")
        if fs.SetTextColor then
            pcall(fs.SetTextColor, fs, r, g, b)
        end
    end

    if block.HeaderText then
        ColorizeFontString(block.HeaderText)
    end
    if block.HeaderButton and block.HeaderButton.GetFontString then
        ColorizeFontString(block.HeaderButton:GetFontString())
    end
end

function FQL:ApplyTrackerStyle(tracker)
    local tScale = (shupazForeverQuestLogDB and tonumber(shupazForeverQuestLogDB.trackerScale)) or 1.0
    if tScale < MIN_SCALE then tScale = MIN_SCALE end
    if tScale > MAX_SCALE then tScale = MAX_SCALE end

    if _G.ObjectiveTrackerFrame then
        if CanChangeFrame(_G.ObjectiveTrackerFrame) then
            local curScale = SafeNum(_G.ObjectiveTrackerFrame:GetScale())
            if not curScale or math.abs(curScale - tScale) > 0.005 then
                pcall(_G.ObjectiveTrackerFrame.SetScale, _G.ObjectiveTrackerFrame, tScale)
            end
        else
            self._needsTrackerCombatRefresh = true
        end
        if _G.ObjectiveTrackerFrame.Header and _G.ObjectiveTrackerFrame.Header.Text then
            ApplyFontToFontString(_G.ObjectiveTrackerFrame.Header.Text, self:GetTrackerFontPath())
        end
    elseif tracker and CanChangeFrame(tracker) then
        local curScale = SafeNum(tracker:GetScale())
        if not curScale or math.abs(curScale - tScale) > 0.005 then
            pcall(tracker.SetScale, tracker, tScale)
        end
    end

    if not tracker then return end
    local fontPath = self:GetTrackerFontPath()
    local ts = TS(tracker)

    if tracker.Header and tracker.Header.Text then
        ApplyFontToFontString(tracker.Header.Text, fontPath)
    end

    if ts.zoneHeaders then
        for _, hBtn in ipairs(ts.zoneHeaders) do
            ApplyFontToFontString(hBtn.titleText, fontPath)
            ApplyFontToFontString(hBtn.countText, fontPath)
        end
    end

    local contents = tracker.ContentsFrame or tracker
    if contents and contents.GetChildren then
        for _, child in ipairs({ contents:GetChildren() }) do
            if IsRealTrackerBlock(child) then
                ApplyFontToTrackerBlock(child, fontPath)
            end
        end
    end
end

function FQL:SetTrackerScale(scale)
    scale = tonumber(scale) or 1.0
    if scale < MIN_SCALE then scale = MIN_SCALE end
    if scale > MAX_SCALE then scale = MAX_SCALE end
    scale = math.floor(scale * 100 + 0.5) / 100
    if shupazForeverQuestLogDB then
        shupazForeverQuestLogDB.trackerScale = scale
    end
    self:RefreshObjectiveTracker()
    if self.optionsPanel and self.optionsPanel.RefreshControls then
        self.optionsPanel:RefreshControls()
    end
end

function FQL:SetTrackerFontScale(scale)
    scale = tonumber(scale) or 1.0
    if scale < 0.80 then scale = 0.80 end
    if scale > 1.60 then scale = 1.60 end
    scale = math.floor(scale * 100 + 0.5) / 100
    if shupazForeverQuestLogDB then
        shupazForeverQuestLogDB.trackerFontScale = scale
    end
    if _G.ObjectiveTrackerFrame then self:ApplyTrackerStyle(_G.ObjectiveTrackerFrame) end
    if _G.QuestObjectiveTracker then self:ApplyTrackerStyle(_G.QuestObjectiveTracker) end
    if _G.CampaignQuestObjectiveTracker then self:ApplyTrackerStyle(_G.CampaignQuestObjectiveTracker) end
    self:RefreshObjectiveTracker()
    if self.optionsPanel and self.optionsPanel.RefreshControls then
        self.optionsPanel:RefreshControls()
    end
end

function FQL:SetTrackerFont(fontID)
    if shupazForeverQuestLogDB then
        shupazForeverQuestLogDB.trackerFont = fontID or "DEFAULT"
    end
    if _G.ObjectiveTrackerFrame then self:ApplyTrackerStyle(_G.ObjectiveTrackerFrame) end
    if _G.QuestObjectiveTracker then self:ApplyTrackerStyle(_G.QuestObjectiveTracker) end
    if _G.CampaignQuestObjectiveTracker then self:ApplyTrackerStyle(_G.CampaignQuestObjectiveTracker) end
    self:RefreshObjectiveTracker()
    if self.optionsPanel and self.optionsPanel.RefreshControls then
        self.optionsPanel:RefreshControls()
    end
end

local function GetMaxTrackerContentsHeight(tracker, contents)
    local container = _G.ObjectiveTrackerFrame
    local containerMax = nil
    local ts = TS(tracker)

    if container then
        containerMax = SafeNum(container.editModeHeight)
        if (not containerMax or containerMax <= 0 or containerMax >= 50000) and type(container.GetAvailableHeight) == "function" then
            local ok, h = pcall(container.GetAvailableHeight, container)
            if ok then
                local sh = SafeNum(h)
                if sh and sh > 0 and sh < 50000 then
                    containerMax = sh
                end
            end
        end
    end

    if (not containerMax or containerMax <= 0 or containerMax >= 50000) and ts.nativeAvailableHeight then
        containerMax = ts.nativeAvailableHeight
    end

    if not containerMax or containerMax <= 0 or containerMax >= 50000 then
        containerMax = 540
    end

    local hdrH = (tracker.Header and SafeNum(tracker.Header:GetHeight())) or 26
    local usedAbove = hdrH
    local cTop = container and container.GetTop and SafeNum(container:GetTop())
    local myTop = (contents and contents.GetTop and SafeNum(contents:GetTop())) or (tracker.GetTop and SafeNum(tracker:GetTop()))
    if cTop and myTop and cTop > myTop then
        usedAbove = cTop - myTop
    end

    local maxH = containerMax - usedAbove
    if ts.nativeAvailableHeight and ts.nativeAvailableHeight > 60 and ts.nativeAvailableHeight < maxH then
        maxH = ts.nativeAvailableHeight
    end

    if myTop and myTop > 180 then
        local screenLimit = myTop - 100
        if screenLimit < maxH then
            maxH = screenLimit
        end
    end

    if maxH < 120 then maxH = 120 end
    return maxH
end

function FQL:SetTrackerScrollIndex(tracker, newIndex)
    if not tracker then return end
    local ts = TS(tracker)
    local maxIdx = ts.maxScrollIndex or 1
    local clamped = math.max(1, math.min(maxIdx, math.floor((newIndex or 1) + 0.5)))
    if clamped ~= (ts.scrollIndex or 1) then
        ts.scrollIndex = clamped
        self:ApplyTrackerZoneLayout(tracker)
    end
end

function FQL:ScrollTrackerByDelta(tracker, delta)
    if not tracker then return end
    local ts = TS(tracker)
    local maxIdx = ts.maxScrollIndex or 1
    if maxIdx <= 1 then return end
    local cur = ts.scrollIndex or 1
    local step = (IsShiftKeyDown and IsShiftKeyDown()) and 3 or 1
    local nextIdx
    if (delta or 0) > 0 then
        nextIdx = math.max(1, cur - step)
    else
        nextIdx = math.min(maxIdx, cur + step)
    end
    if nextIdx ~= cur then
        ts.scrollIndex = nextIdx
        self:ApplyTrackerZoneLayout(tracker)
    end
end

local function AttachTrackerMouseWheel(frameObj, tracker)
    if not frameObj or WheelHooked[frameObj] or not tracker then return end
    WheelHooked[frameObj] = tracker
    pcall(function()
        if frameObj.EnableMouseWheel then
            frameObj:EnableMouseWheel(true)
        end
        if frameObj.GetScript and frameObj:GetScript("OnMouseWheel") then
            frameObj:HookScript("OnMouseWheel", function(self, delta)
                if FQL and FQL.ScrollTrackerByDelta then
                    FQL:ScrollTrackerByDelta(WheelHooked[self] or tracker, delta)
                end
            end)
        elseif frameObj.SetScript then
            frameObj:SetScript("OnMouseWheel", function(self, delta)
                if FQL and FQL.ScrollTrackerByDelta then
                    FQL:ScrollTrackerByDelta(WheelHooked[self] or tracker, delta)
                end
            end)
        end
    end)
end

local function EnsureTrackerScrollBar(tracker, contents)
    if not tracker or not contents then return nil end
    local ts = TS(tracker)
    if ts.scrollBar then
        return ts.scrollBar
    end

    local sb = CreateFrame("Frame", nil, contents)
    ts.scrollBar = sb
    sb:SetWidth(6)
    sb:SetPoint("TOPRIGHT", contents, "TOPRIGHT", -1, -6)
    sb:SetFrameLevel((contents:GetFrameLevel() or 5) + 12)
    sb:EnableMouse(true)
    sb:EnableMouseWheel(true)
    sb:SetScript("OnMouseWheel", function(_, delta)
        if FQL and FQL.ScrollTrackerByDelta then
            FQL:ScrollTrackerByDelta(tracker, delta)
        end
    end)

    local upBtn = CreateFrame("Button", nil, sb)
    sb.upBtn = upBtn
    upBtn:SetSize(6, 10)
    upBtn:SetPoint("TOP", sb, "TOP", 0, 0)
    local upBg = upBtn:CreateTexture(nil, "BACKGROUND")
    upBtn.bg = upBg
    upBg:SetAllPoints()
    upBg:SetColorTexture(0.12, 0.09, 0.04, 0.78)
    local upIcon = upBtn:CreateTexture(nil, "ARTWORK")
    upBtn.icon = upIcon
    upIcon:SetSize(10, 10)
    upIcon:SetPoint("CENTER", 0, 0)
    upIcon:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    upIcon:SetTexCoord(0.20, 0.80, 0.20, 0.80)
    upBtn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight", "ADD")
    upBtn:SetScript("OnClick", function()
        PlayClickSound()
        FQL:ScrollTrackerByDelta(tracker, 1)
    end)
    upBtn:EnableMouseWheel(true)
    upBtn:SetScript("OnMouseWheel", function(_, delta)
        FQL:ScrollTrackerByDelta(tracker, delta)
    end)

    local downBtn = CreateFrame("Button", nil, sb)
    sb.downBtn = downBtn
    downBtn:SetSize(6, 10)
    downBtn:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
    local downBg = downBtn:CreateTexture(nil, "BACKGROUND")
    downBtn.bg = downBg
    downBg:SetAllPoints()
    downBg:SetColorTexture(0.12, 0.09, 0.04, 0.78)
    local downIcon = downBtn:CreateTexture(nil, "ARTWORK")
    downBtn.icon = downIcon
    downIcon:SetSize(10, 10)
    downIcon:SetPoint("CENTER", 0, 0)
    downIcon:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    downIcon:SetTexCoord(0.20, 0.80, 0.20, 0.80)
    downBtn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
    downBtn:SetScript("OnClick", function()
        PlayClickSound()
        FQL:ScrollTrackerByDelta(tracker, -1)
    end)
    downBtn:EnableMouseWheel(true)
    downBtn:SetScript("OnMouseWheel", function(_, delta)
        FQL:ScrollTrackerByDelta(tracker, delta)
    end)

    local track = CreateFrame("Button", nil, sb)
    sb.track = track
    track:SetPoint("TOPLEFT", upBtn, "BOTTOMLEFT", 0, -2)
    track:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    track.bg = trackBg
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.05, 0.04, 0.02, 0.62)

    local trackBorderL = track:CreateTexture(nil, "BORDER")
    trackBorderL:SetWidth(1)
    trackBorderL:SetPoint("TOPLEFT", 0, 0)
    trackBorderL:SetPoint("BOTTOMLEFT", 0, 0)
    trackBorderL:SetColorTexture(0.50, 0.40, 0.16, 0.42)

    local trackBorderR = track:CreateTexture(nil, "BORDER")
    trackBorderR:SetWidth(1)
    trackBorderR:SetPoint("TOPRIGHT", 0, 0)
    trackBorderR:SetPoint("BOTTOMRIGHT", 0, 0)
    trackBorderR:SetColorTexture(0.50, 0.40, 0.16, 0.42)

    local thumb = CreateFrame("Button", nil, track)
    sb.thumb = thumb
    thumb:SetWidth(4)
    thumb:SetHeight(28)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumb.tex = thumbTex
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.82, 0.66, 0.24, 0.85)

    thumb:SetScript("OnEnter", function(self)
        self.tex:SetColorTexture(1.0, 0.85, 0.36, 0.98)
        if GameTooltip and (not shupazForeverQuestLogDB or shupazForeverQuestLogDB.showTooltips ~= false) then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Objective Tracker Scroll", 1, 0.82, 0)
            local cur = ts.scrollIndex or 1
            local maxIdx = ts.maxScrollIndex or 1
            local totalQ = ts.totalTrackedQuests or 0
            local shownQ = ts.shownTrackedQuests or 0
            GameTooltip:AddLine(string.format("Showing %d of %d tracked quests (Position %d/%d)", shownQ, totalQ, cur, maxIdx), 0.9, 0.9, 0.9)
            GameTooltip:AddLine("Drag thumb or use Mouse Wheel to scroll", 0.65, 0.85, 0.65)
            GameTooltip:AddLine("Hold Shift + Mouse Wheel to scroll faster", 0.65, 0.65, 0.65)
            GameTooltip:Show()
        end
    end)
    thumb:SetScript("OnLeave", function(self)
        if not self._dragging then
            self.tex:SetColorTexture(0.82, 0.66, 0.24, 0.85)
        end
        if GameTooltip then GameTooltip:Hide() end
    end)

    thumb:EnableMouseWheel(true)
    thumb:SetScript("OnMouseWheel", function(_, delta)
        FQL:ScrollTrackerByDelta(tracker, delta)
    end)

    local function StopThumbDrag(self)
        self._dragging = false
        self:SetScript("OnUpdate", nil)
        if self:IsMouseOver() then
            self.tex:SetColorTexture(1.0, 0.85, 0.36, 0.98)
        else
            self.tex:SetColorTexture(0.82, 0.66, 0.24, 0.85)
        end
    end

    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        self._dragging = true
        self.tex:SetColorTexture(1.0, 0.88, 0.42, 1.0)
        local scale = track:GetEffectiveScale() or 1
        local _, cursorY = GetCursorPosition()
        self._dragStartCursorY = (cursorY or 0) / scale
        self._dragStartOffset = sb._thumbOffset or 0
        self._dragMaxOffset = math.max(1, sb._maxThumbOffset or 1)
        self:SetScript("OnUpdate", function()
            if not self._dragging or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then
                StopThumbDrag(self)
                return
            end
            local maxIdx = ts.maxScrollIndex or 1
            local maxOff = self._dragMaxOffset or sb._maxThumbOffset or 0
            if maxIdx <= 1 or maxOff <= 0 then return end
            local effScale = track:GetEffectiveScale() or 1
            local _, curY = GetCursorPosition()
            local dy = self._dragStartCursorY - ((curY or 0) / effScale)
            local newOff = math.max(0, math.min(maxOff, self._dragStartOffset + dy))
            local ratio = newOff / maxOff
            local targetIdx = 1 + math.floor(ratio * (maxIdx - 1) + 0.5)
            FQL:SetTrackerScrollIndex(tracker, targetIdx)
        end)
    end)
    thumb:SetScript("OnMouseUp", StopThumbDrag)
    thumb:SetScript("OnDragStop", StopThumbDrag)
    thumb:SetScript("OnHide", StopThumbDrag)

    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        FQL:ScrollTrackerByDelta(tracker, delta)
    end)
    track:SetScript("OnClick", function()
        local scale = track:GetEffectiveScale() or 1
        local _, cursorY = GetCursorPosition()
        cursorY = (cursorY or 0) / scale
        local thumbTop = thumb:GetTop()
        local thumbBot = thumb:GetBottom()
        PlayClickSound()
        if thumbTop and cursorY > thumbTop then
            FQL:SetTrackerScrollIndex(tracker, (ts.scrollIndex or 1) - 3)
        elseif thumbBot and cursorY < thumbBot then
            FQL:SetTrackerScrollIndex(tracker, (ts.scrollIndex or 1) + 3)
        end
    end)

    sb:Hide()
    return sb
end

local function UpdateTrackerScrollBar(tracker, contents, finalHeight, scrollIndex, maxScrollIndex, visibleItemCount, totalItemCount)
    local sb = EnsureTrackerScrollBar(tracker, contents)
    if not sb then return end

    if not maxScrollIndex or maxScrollIndex <= 1 then
        sb:Hide()
        return
    end

    local sbHeight = math.max(48, (finalHeight or 120) - 10)
    sb:SetHeight(sbHeight)
    sb:Show()

    local trackHeight = math.max(16, sbHeight - 28)
    local fracVisible = math.max(0.15, math.min(0.90, (visibleItemCount or 1) / math.max(1, totalItemCount or 1)))
    local thumbHeight = math.max(16, math.min(trackHeight - 4, math.floor(trackHeight * fracVisible)))
    local maxThumbOffset = math.max(0, trackHeight - thumbHeight)
    local scrollRatio = (scrollIndex - 1) / math.max(1, maxScrollIndex - 1)
    local thumbOffset = math.floor(maxThumbOffset * scrollRatio + 0.5)

    sb._maxThumbOffset = maxThumbOffset
    sb._thumbOffset = thumbOffset

    sb.thumb:SetHeight(thumbHeight)
    sb.thumb:ClearAllPoints()
    sb.thumb:SetPoint("TOP", sb.track, "TOP", 0, -thumbOffset)

    if scrollIndex <= 1 then
        sb.upBtn:SetAlpha(0.35)
    else
        sb.upBtn:SetAlpha(1.0)
    end
    if scrollIndex >= maxScrollIndex then
        sb.downBtn:SetAlpha(0.35)
    else
        sb.downBtn:SetAlpha(1.0)
    end
end

function FQL:ApplyTrackerZoneLayout(tracker)
    if not tracker or self._inTrackerLayout then return end
    local contents = tracker.ContentsFrame or tracker
    if not contents then return end
    local ts = TS(tracker)

    self:ApplyTrackerStyle(tracker)
    AttachTrackerMouseWheel(contents, tracker)

    local function HideTrackerQuestEntry(entry)
        if not entry then return end
        local b = entry.block
        if b then
            BS(b).hiddenByZone = true
            if CanChangeFrame(b) then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", contents, "TOPLEFT", 0, 0)
                b:Hide()
            else
                FQL._needsTrackerCombatRefresh = true
            end
        end
        for _, att in ipairs(entry.attachments or {}) do
            BS(att).hiddenByZone = true
            if CanChangeFrame(att) then
                att:Hide()
            end
        end
    end

    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerByZone == false then
        HideAllTrackerZoneHeaders(tracker)
        if ts.headerZoneBtn then ts.headerZoneBtn:Hide() end
        if ts.scrollBar then ts.scrollBar:Hide() end
        if contents.GetChildren then
            for _, child in ipairs({ contents:GetChildren() }) do
                if BState[child] and BState[child].hiddenByZone then
                    BState[child].hiddenByZone = nil
                    if CanChangeFrame(child) then child:Show() end
                end
            end
        end
        local questToZone = self:GetQuestZoneLookup()
        local titleToQuestID = {}
        for qid, data in pairs(questToZone) do
            if data.title then
                titleToQuestID[data.title] = qid
            end
        end
        local questBlocks = CollectTrackerBlocksAndAttachments(tracker, questToZone, titleToQuestID)
        for _, entry in ipairs(questBlocks) do
            ApplyBlockHeaderColor(entry.block, entry.questID, questToZone[entry.questID])
        end
        return
    end

    if (tracker.IsCollapsed and tracker:IsCollapsed()) or not contents:IsShown() then
        HideAllTrackerZoneHeaders(tracker)
        if ts.headerZoneBtn then ts.headerZoneBtn:Hide() end
        if ts.scrollBar then ts.scrollBar:Hide() end
        return
    end

    self._inTrackerLayout = true

    local questToZone, zoneOrder = self:GetQuestZoneLookup()
    local titleToQuestID = {}
    for qid, data in pairs(questToZone) do
        if data.title then
            titleToQuestID[data.title] = qid
        end
    end

    local questBlocks, topBanners = CollectTrackerBlocksAndAttachments(tracker, questToZone, titleToQuestID)

    if #questBlocks == 0 then
        HideAllTrackerZoneHeaders(tracker)
        if ts.headerZoneBtn then ts.headerZoneBtn:Hide() end
        if ts.scrollBar then ts.scrollBar:Hide() end
        self._inTrackerLayout = false
        return
    end

    self:EnsureTrackerHeaderZoneButton(tracker)
    if ts.headerZoneBtn then
        ts.headerZoneBtn:Show()
    end

    local defaultLeftOffset = 0
    local defaultRightOffset = 0
    local defaultWidth = SafeNum(contents:GetWidth()) or 235
    local startY = 10

    for _, entry in ipairs(questBlocks) do
        local bs = BS(entry.block)
        if bs.leftOffset ~= nil then
            defaultLeftOffset = bs.leftOffset
            defaultRightOffset = bs.rightOffset or 0
            if bs.width and bs.width > 80 then
                defaultWidth = bs.width
            end
            if bs.topOffset then
                startY = math.max(10, bs.topOffset)
            end
            break
        end
    end

    local groupsByName = {}
    local orderedGroups = {}
    local currentPlayerZone = (GetRealZoneText and SafeStr(GetRealZoneText())) or (GetZoneText and SafeStr(GetZoneText())) or nil
    local prioritizeCurrent = (not shupazForeverQuestLogDB) or (shupazForeverQuestLogDB.trackerCurrentZoneFirst ~= false)
    local showZoneCount = (not shupazForeverQuestLogDB) or (shupazForeverQuestLogDB.trackerShowZoneCount ~= false)

    for idx, entry in ipairs(questBlocks) do
        local qid = entry.questID
        local qMeta = questToZone[qid]
        local zName = self:ResolveQuestZoneName(qid, questToZone)
        local grp = groupsByName[zName]
        if not grp then
            grp = {
                zoneName = zName,
                order = (prioritizeCurrent and zName == currentPlayerZone) and 0 or (zoneOrder[zName] or (1000 + idx)),
                entries = {},
                completeCount = 0,
            }
            groupsByName[zName] = grp
            orderedGroups[#orderedGroups + 1] = grp
        end
        entry.questOrder = (qMeta and qMeta.questOrder) or idx
        entry.completeState = (qMeta and qMeta.completeState) or IsQuestCompleteOrFailed(qid, nil)
        if entry.completeState == 1 then
            grp.completeCount = grp.completeCount + 1
        end
        grp.entries[#grp.entries + 1] = entry
        ApplyBlockHeaderColor(entry.block, qid, qMeta)
        AttachTrackerMouseWheel(entry.block, tracker)
        if entry.block and entry.block.HeaderButton then
            AttachTrackerMouseWheel(entry.block.HeaderButton, tracker)
        end
    end

    table.sort(orderedGroups, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.zoneName < b.zoneName
    end)

    for _, grp in ipairs(orderedGroups) do
        table.sort(grp.entries, function(a, b)
            return (a.questOrder or 0) < (b.questOrder or 0)
        end)
    end

    local maxContentsHeight = GetMaxTrackerContentsHeight(tracker, contents)
    local activeZoneNames = {}
    local anyZoneExpanded = false

    local renderItems = {}
    for _, grp in ipairs(orderedGroups) do
        activeZoneNames[#activeZoneNames + 1] = grp.zoneName
        local isCollapsed = self:IsTrackerZoneCollapsed(grp.zoneName)
        grp.isCollapsed = isCollapsed

        local headerItem = {
            type = "HEADER",
            grp = grp,
            height = TRACKER_ZONE_HEADER_HEIGHT,
        }
        renderItems[#renderItems + 1] = headerItem
        grp.headerItemIndex = #renderItems

        if isCollapsed then
            for _, entry in ipairs(grp.entries) do
                HideTrackerQuestEntry(entry)
            end
        else
            anyZoneExpanded = true
            for bIdx, entry in ipairs(grp.entries) do
                local b = entry.block
                local bs = BS(b)
                local bHeight = SafeNum(b.height) or bs.height or SafeNum(b:GetHeight()) or 36
                renderItems[#renderItems + 1] = {
                    type = "QUEST",
                    grp = grp,
                    entry = entry,
                    bIdx = bIdx,
                    height = bHeight,
                }
            end
        end
    end

    local function ComputeTailHeight(startIdx)
        local h = startY
        local hasPrev = (#topBanners > 0)
        local firstItem = renderItems[startIdx]
        if firstItem and firstItem.type == "QUEST" then
            local gap = hasPrev and TRACKER_ZONE_HEADER_GAP_BOTTOM or 0
            h = h + gap + TRACKER_ZONE_HEADER_HEIGHT
            hasPrev = true
        end
        for i = startIdx, #renderItems do
            local it = renderItems[i]
            local gap = 0
            if hasPrev then
                if it.type == "HEADER" then
                    gap = TRACKER_ZONE_HEADER_GAP_TOP
                else
                    gap = (i == startIdx or renderItems[i - 1].type == "HEADER") and TRACKER_ZONE_HEADER_GAP_BOTTOM or TRACKER_BLOCK_GAP
                end
            end
            h = h + gap + it.height
            hasPrev = true
        end
        return h
    end

    local totalItems = #renderItems
    local maxScrollIndex = 1
    if totalItems > 1 and ComputeTailHeight(1) > maxContentsHeight then
        maxScrollIndex = totalItems
        for s = 1, totalItems do
            if ComputeTailHeight(s) <= maxContentsHeight then
                maxScrollIndex = s
                break
            end
        end
    end

    ts.maxScrollIndex = maxScrollIndex
    local scrollIndex = math.max(1, math.min(maxScrollIndex, ts.scrollIndex or 1))
    ts.scrollIndex = scrollIndex

    local scrollbarPad = (maxScrollIndex > 1) and 9 or 0
    local effectiveRightOffset = defaultRightOffset - scrollbarPad

    for i = 1, scrollIndex - 1 do
        local it = renderItems[i]
        if it and it.type == "QUEST" then
            HideTrackerQuestEntry(it.entry)
        end
    end

    local headerIdx = 0
    local prevAnchorFrame = (#topBanners > 0) and topBanners[#topBanners] or nil
    local estimatedHeight = startY
    local visibleItemCount = 0
    local shownTrackedQuests = 0

    local function RenderZoneHeader(grp, isFirstHeader)
        headerIdx = headerIdx + 1
        local hBtn = AcquireTrackerZoneHeader(tracker, headerIdx)
        local isCollapsed = grp.isCollapsed
        local headerGap = prevAnchorFrame and (isFirstHeader and TRACKER_ZONE_HEADER_GAP_BOTTOM or TRACKER_ZONE_HEADER_GAP_TOP) or 0

        hBtn.zoneName = grp.zoneName
        hBtn.questCount = #grp.entries
        hBtn.isCollapsed = isCollapsed
        hBtn:SetHeight(TRACKER_ZONE_HEADER_HEIGHT)
        if scrollbarPad > 0 and defaultWidth then
            hBtn:SetWidth(defaultWidth - scrollbarPad)
        else
            hBtn:SetWidth(defaultWidth)
        end
        hBtn:ClearAllPoints()

        if prevAnchorFrame then
            hBtn:SetPoint("TOP", prevAnchorFrame, "BOTTOM", 0, -headerGap)
            estimatedHeight = estimatedHeight + headerGap
        else
            hBtn:SetPoint("TOP", contents, "TOP", 0, -startY)
        end
        hBtn:SetPoint("LEFT", contents, "LEFT", defaultLeftOffset, 0)
        hBtn:SetPoint("RIGHT", contents, "RIGHT", effectiveRightOffset, 0)

        hBtn.collapseIcon:SetTexture(isCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        hBtn.titleText:SetText(grp.zoneName)

        if not showZoneCount then
            hBtn.countText:SetText("")
        elseif grp.completeCount > 0 then
            if grp.completeCount == #grp.entries then
                hBtn.countText:SetFormattedText("|cff40ff40(%d/%d)|r", grp.completeCount, #grp.entries)
            else
                hBtn.countText:SetFormattedText("|cff40ff40%d|r|cffb8a582/%d|r", grp.completeCount, #grp.entries)
            end
        else
            hBtn.countText:SetFormattedText("|cffb8a582(%d)|r", #grp.entries)
        end

        if isCollapsed then
            hBtn.bg:SetColorTexture(0.08, 0.06, 0.03, 0.42)
            hBtn.line:SetColorTexture(0.55, 0.44, 0.18, 0.32)
            hBtn.titleText:SetTextColor(0.78, 0.67, 0.38)
        else
            hBtn.bg:SetColorTexture(0.11, 0.08, 0.035, 0.52)
            hBtn.line:SetColorTexture(0.76, 0.60, 0.22, 0.48)
            hBtn.titleText:SetTextColor(1.00, 0.82, 0.18)
        end

        hBtn:Show()
        prevAnchorFrame = hBtn
        estimatedHeight = estimatedHeight + TRACKER_ZONE_HEADER_HEIGHT
        return hBtn
    end

    local firstVisibleItem = renderItems[scrollIndex]
    if firstVisibleItem and firstVisibleItem.type == "QUEST" then
        RenderZoneHeader(firstVisibleItem.grp, true)
    end

    local overflowReached = false
    for i = scrollIndex, totalItems do
        local it = renderItems[i]
        if it.type == "HEADER" then
            local headerGap = prevAnchorFrame and ((headerIdx == 0) and TRACKER_ZONE_HEADER_GAP_BOTTOM or TRACKER_ZONE_HEADER_GAP_TOP) or 0
            local neededH = headerGap + TRACKER_ZONE_HEADER_HEIGHT
            local nextItem = renderItems[i + 1]
            if nextItem and nextItem.type == "QUEST" and nextItem.grp == it.grp then
                neededH = neededH + TRACKER_ZONE_HEADER_GAP_BOTTOM + nextItem.height
            end
            local fits = (not overflowReached) and ((estimatedHeight + neededH <= maxContentsHeight) or visibleItemCount == 0)
            if fits then
                RenderZoneHeader(it.grp, headerIdx == 0)
                visibleItemCount = visibleItemCount + 1
            else
                overflowReached = true
            end
        elseif it.type == "QUEST" then
            local entry = it.entry
            local b = entry.block
            local bs = BS(b)
            local prevIsHeader = (i == scrollIndex) or (renderItems[i - 1] and renderItems[i - 1].type == "HEADER")
            local gap = prevIsHeader and TRACKER_ZONE_HEADER_GAP_BOTTOM or TRACKER_BLOCK_GAP
            local bHeight = it.height
            local fits = (not overflowReached) and ((estimatedHeight + gap + bHeight <= maxContentsHeight) or visibleItemCount == 0)

            if not fits then
                overflowReached = true
                HideTrackerQuestEntry(entry)
            else
                bs.hiddenByZone = nil
                local bWidth = bs.width or defaultWidth
                local bLeft = SafeNum(b.offsetX) or bs.leftOffset or defaultLeftOffset

                if CanChangeFrame(b) then
                    b:ClearAllPoints()
                    b:SetPoint("TOP", prevAnchorFrame, "BOTTOM", 0, -gap)
                    if bs.horizPoints and #bs.horizPoints > 0 and scrollbarPad == 0 then
                        for _, hp in ipairs(bs.horizPoints) do
                            b:SetPoint(hp.p, hp.rel or contents, hp.rp, hp.x, hp.y)
                        end
                    else
                        b:SetPoint("LEFT", contents, "LEFT", bLeft, 0)
                        b:SetPoint("RIGHT", contents, "RIGHT", effectiveRightOffset, 0)
                    end
                    if bWidth and bWidth > 80 then
                        b:SetWidth(scrollbarPad > 0 and (bWidth - scrollbarPad) or bWidth)
                    end
                    if bHeight and bHeight > 8 then
                        b:SetHeight(bHeight)
                    end
                    b:Show()
                else
                    FQL._needsTrackerCombatRefresh = true
                end

                for _, att in ipairs(entry.attachments) do
                    BS(att).hiddenByZone = nil
                    if CanChangeFrame(att) then
                        att:Show()
                    end
                end

                prevAnchorFrame = b
                estimatedHeight = estimatedHeight + gap + bHeight
                visibleItemCount = visibleItemCount + 1
                shownTrackedQuests = shownTrackedQuests + 1
            end
        end
    end

    for i = headerIdx + 1, #(ts.zoneHeaders or {}) do
        ts.zoneHeaders[i]:Hide()
    end

    if ts.headerZoneBtn and ts.headerZoneBtn.icon then
        ts.headerZoneBtn.icon:SetTexture(anyZoneExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    end

    ts.activeZones = activeZoneNames
    ts.totalTrackedQuests = #questBlocks
    ts.shownTrackedQuests = shownTrackedQuests
    if #activeZoneNames > 0 then
        self._lastTrackerZones = activeZoneNames
    end

    local finalHeight = math.min(maxContentsHeight, math.max(24, estimatedHeight + 6))
    if CanChangeFrame(contents) then
        if contents.SetClipsChildren then
            pcall(contents.SetClipsChildren, contents, false)
        end
        contents:SetHeight(finalHeight)
    end
    if tracker ~= contents and CanChangeFrame(tracker) then
        local hdrH = (tracker.Header and SafeNum(tracker.Header:GetHeight())) or 26
        tracker:SetHeight(hdrH + finalHeight + 6)
    end

    local sbTargetHeight = (maxScrollIndex > 1) and math.max(finalHeight, maxContentsHeight - 16) or finalHeight
    UpdateTrackerScrollBar(tracker, contents, sbTargetHeight, scrollIndex, maxScrollIndex, visibleItemCount, totalItems)

    self:ApplyTrackerStyle(tracker)

    self._inTrackerLayout = false
end

local function HandleTrackerQuestClick(block, mouseButton)
    if mouseButton == "LeftButton" and not (IsModifiedClick and IsModifiedClick()) then
        local qid = block and (block.id or block.questID)
        qid = SafeNum(qid)
        if qid and qid > 0 then
            if WorldMapFrame and WorldMapFrame:IsShown() and CanChangeFrame(WorldMapFrame) and HideUIPanel then
                pcall(HideUIPanel, WorldMapFrame)
            end
            if FQL and FQL.OpenToQuest then
                FQL:OpenToQuest(qid)
            end
        end
    end
end

local function ForceUnlimitedTrackerHeight(self)
    if not self then return end
    local cur = SafeNum(self.availableHeight)
    if cur and cur > 40 and cur < 50000 then
        TS(self).nativeAvailableHeight = cur
    end
    if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.trackerByZone ~= false then
        self.availableHeight = 100000
    end
end

local function NeedsFullHeightRetry(tracker)
    if not tracker then return false end
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerByZone == false then return false end
    if tracker.hasSkippedBlocks then return true end
    local avail = SafeNum(tracker.availableHeight)
    if avail and avail < 50000 then return true end
    return false
end

local function HookSingleTrackerModule(tracker)
    if not tracker then return end
    local ts = TS(tracker)
    if ts.trackerHooked then return end
    ts.trackerHooked = true

    if tracker.BeginLayout then
        hooksecurefunc(tracker, "BeginLayout", function(self)
            ForceUnlimitedTrackerHeight(self)
            local cFrame = self.ContentsFrame or self
            if cFrame and cFrame.GetChildren then
                for _, child in ipairs({ cFrame:GetChildren() }) do
                    if BState[child] and BState[child].hiddenByZone then
                        BState[child].hiddenByZone = nil
                    end
                end
            end
        end)
    end

    local preFitMethods = {
        "MarkBlocksUnused",
        "AddAutoQuestObjectives",
        "EnumQuestWatchData",
        "ShouldDisplayQuest",
        "UpdateSingle",
        "GetBlock",
        "SetBlockHeader",
        "AddHeader",
        "AnchorBlock",
        "AddBlock",
    }
    for _, mName in ipairs(preFitMethods) do
        if type(tracker[mName]) == "function" then
            hooksecurefunc(tracker, mName, ForceUnlimitedTrackerHeight)
        end
    end

    if tracker.EndLayout then
        hooksecurefunc(tracker, "EndLayout", function(self)
            local s = TS(self)
            if NeedsFullHeightRetry(self) then
                if not s.retryingFullHeight and not (InCombatLockdown and InCombatLockdown()) and self.Update then
                    s.retryingFullHeight = true
                    pcall(self.Update, self, 100000, false)
                    s.retryingFullHeight = false
                    return
                end
            end
            FQL:ApplyTrackerZoneLayout(self)
        end)
    elseif tracker.LayoutContents then
        hooksecurefunc(tracker, "LayoutContents", function(self)
            FQL:ApplyTrackerZoneLayout(self)
        end)
    end

    if tracker.Update then
        hooksecurefunc(tracker, "Update", function(self, _, dirtyUpdate)
            if dirtyUpdate and not TS(self).retryingFullHeight and not (InCombatLockdown and InCombatLockdown()) then
                FQL:ApplyTrackerZoneLayout(self)
            end
        end)
    end

    if type(tracker.OnBlockHeaderClick) == "function" and not ts.headerClickHooked then
        ts.headerClickHooked = true
        hooksecurefunc(tracker, "OnBlockHeaderClick", function(_, block, mouseButton)
            HandleTrackerQuestClick(block, mouseButton)
        end)
    end
end

local legacyClickHooked = false
local containerHooked = false

local function SetupObjectiveTrackerHooks()
    if _G.QuestObjectiveTracker then
        HookSingleTrackerModule(_G.QuestObjectiveTracker)
    end
    if _G.CampaignQuestObjectiveTracker then
        HookSingleTrackerModule(_G.CampaignQuestObjectiveTracker)
    end
    if type(_G.ObjectiveTracker_OnBlockHeaderClick) == "function" and not legacyClickHooked then
        legacyClickHooked = true
        hooksecurefunc("ObjectiveTracker_OnBlockHeaderClick", function(block, mouseButton)
            HandleTrackerQuestClick(block, mouseButton)
        end)
    end
    if _G.ObjectiveTrackerFrame and not containerHooked then
        containerHooked = true
        if _G.ObjectiveTrackerFrame.Update then
            hooksecurefunc(_G.ObjectiveTrackerFrame, "Update", function()
                if _G.QuestObjectiveTracker then
                    if NeedsFullHeightRetry(_G.QuestObjectiveTracker) and not (InCombatLockdown and InCombatLockdown()) and _G.QuestObjectiveTracker.Update then
                        pcall(_G.QuestObjectiveTracker.Update, _G.QuestObjectiveTracker, 100000, false)
                    else
                        FQL:ApplyTrackerZoneLayout(_G.QuestObjectiveTracker)
                    end
                end
                if _G.CampaignQuestObjectiveTracker then
                    if NeedsFullHeightRetry(_G.CampaignQuestObjectiveTracker) and not (InCombatLockdown and InCombatLockdown()) and _G.CampaignQuestObjectiveTracker.Update then
                        pcall(_G.CampaignQuestObjectiveTracker.Update, _G.CampaignQuestObjectiveTracker, 100000, false)
                    else
                        FQL:ApplyTrackerZoneLayout(_G.CampaignQuestObjectiveTracker)
                    end
                end
            end)
        end
    end
end

function FQL:RefreshObjectiveTracker()
    SetupObjectiveTrackerHooks()
    local inCombat = (InCombatLockdown and InCombatLockdown())
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerByZone == false then
        if _G.QuestObjectiveTracker then
            self:ApplyTrackerZoneLayout(_G.QuestObjectiveTracker)
            if not inCombat and _G.QuestObjectiveTracker.Update then
                pcall(_G.QuestObjectiveTracker.Update, _G.QuestObjectiveTracker, 800, false)
            end
        end
        if _G.CampaignQuestObjectiveTracker then
            self:ApplyTrackerZoneLayout(_G.CampaignQuestObjectiveTracker)
            if not inCombat and _G.CampaignQuestObjectiveTracker.Update then
                pcall(_G.CampaignQuestObjectiveTracker.Update, _G.CampaignQuestObjectiveTracker, 800, false)
            end
        end
        if not inCombat and _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Update then
            pcall(_G.ObjectiveTrackerFrame.Update, _G.ObjectiveTrackerFrame)
        end
        return
    end

    if not inCombat then
        if _G.QuestObjectiveTracker then
            _G.QuestObjectiveTracker.availableHeight = 100000
            if _G.QuestObjectiveTracker.MarkDirty then
                pcall(_G.QuestObjectiveTracker.MarkDirty, _G.QuestObjectiveTracker)
            end
            if _G.QuestObjectiveTracker.Update then
                pcall(_G.QuestObjectiveTracker.Update, _G.QuestObjectiveTracker, 100000, false)
            end
        end
        if _G.CampaignQuestObjectiveTracker then
            _G.CampaignQuestObjectiveTracker.availableHeight = 100000
            if _G.CampaignQuestObjectiveTracker.MarkDirty then
                pcall(_G.CampaignQuestObjectiveTracker.MarkDirty, _G.CampaignQuestObjectiveTracker)
            end
            if _G.CampaignQuestObjectiveTracker.Update then
                pcall(_G.CampaignQuestObjectiveTracker.Update, _G.CampaignQuestObjectiveTracker, 100000, false)
            end
        end
    else
        self._needsTrackerCombatRefresh = true
    end

    if _G.QuestObjectiveTracker then
        self:ApplyTrackerZoneLayout(_G.QuestObjectiveTracker)
    end
    if _G.CampaignQuestObjectiveTracker then
        self:ApplyTrackerZoneLayout(_G.CampaignQuestObjectiveTracker)
    end
    if not inCombat then
        if _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.UpdateHeight then
            pcall(_G.ObjectiveTrackerFrame.UpdateHeight, _G.ObjectiveTrackerFrame)
        end
    else
        self._needsTrackerCombatRefresh = true
    end
end

-- ============================================================
-- Export Tracker Functions to FQL Namespace
-- ============================================================

FQL.SetupObjectiveTrackerHooks = SetupObjectiveTrackerHooks
