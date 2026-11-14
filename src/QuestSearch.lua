local _, FQL = ...

local SEARCH_ROW_HEIGHT = 20
local VISIBLE_SEARCH_ROWS = 18

local ROLE_NAMES = {
    [1] = "|cff66ccffStarts Quest|r",
    [2] = "|cff88ff88Provided|r",
    [3] = "|cffffd100Objective|r",
    [4] = "|cffffaa44Required|r",
    [5] = "|cffb080ffReward|r",
}

local STATUS_FILTERS = {
    { id = "AVAILABLE",   label = "Available Now" },
    { id = "UNCOMPLETED", label = "All Uncompleted" },
    { id = "WORLD_EVENT", label = "World Events" },
    { id = "IN_LOG",      label = "In Quest Log" },
    { id = "COMPLETED",   label = "Completed" },
    { id = "ALL",         label = "All Quests" },
}

local STATUS_BADGES = {
    AVAILABLE         = "|cff00ff00Available Now|r",
    HIGH_LEVEL        = "|cffff5533Requires Higher Level|r",
    PREREQ_LOCKED     = "|cffffaa00Prerequisite Not Met|r",
    SKILL_LOCKED      = "|cffffaa00Requires Profession / Skill|r",
    REP_LOCKED        = "|cffffaa00Requires Faction Reputation|r",
    SPELL_LOCKED      = "|cffffaa00Requires Spell / Training|r",
    EVENT_INACTIVE    = "|cffff99ccWorld Event / Holiday (Hidden on Map)|r",
    HIDDEN            = "|cffff8844Hidden on Map (Inactive / Manual)|r",
    EXCLUSIVE_LOCKED  = "|cff888888Locked (Mutually Exclusive / Obsolete)|r",
    IN_LOG            = "|cff66ccffCurrently in Quest Log|r",
    COMPLETED         = "|cff44dd44Completed|r",
    INELIGIBLE_RACE   = "|cff888888Other Faction / Race|r",
    INELIGIBLE_CLASS  = "|cff888888Other Class|r",
}

local searchState = {
    query = "",
    zoneFilter = "CURRENT", -- "ALL", "CURRENT", or numeric uiMapID / string catName
    statusFilter = "AVAILABLE",
    useLevelThresholds = true,
    results = {},
    selectedQuestID = nil,
}

local function ApplyBoxBackdrop(frameObj, bgColor, borderColor, edgeSize, inset)
    if FQL.SetBackdrop then
        FQL.SetBackdrop(frameObj, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize or 12, inset or 3)
    end
    if frameObj.SetBackdropColor and bgColor then
        frameObj:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end
    if frameObj.SetBackdropBorderColor and borderColor then
        frameObj:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end
end

local function GetActiveZoneMapID()
    if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID then
        local m = WorldMapFrame:GetMapID()
        if m and m > 0 and FQL.QuestData and FQL.QuestData.mapNames and FQL.QuestData.mapNames[m] then
            return m
        end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and type(m) == "number" and m > 0 then
            return m
        end
    end
    return nil
end

local function GetZoneFilterLabel()
    local zf = searchState.zoneFilter
    local QD = FQL.QuestData
    if zf == "ALL" then
        return "All Zones"
    elseif zf == "CURRENT" then
        local curMap = GetActiveZoneMapID()
        local curName = (curMap and QD and QD.mapNames and QD.mapNames[curMap]) or "Current Zone"
        return "Current (" .. curName .. ")"
    elseif type(zf) == "number" then
        return (QD and QD.mapNames and QD.mapNames[zf]) or ("Map " .. tostring(zf))
    elseif type(zf) == "string" then
        return zf
    end
    return "All Zones"
end

local function GetStatusFilterLabel()
    for _, entry in ipairs(STATUS_FILTERS) do
        if entry.id == searchState.statusFilter then
            return entry.label
        end
    end
    return "Available Now"
end

local function QuestMatchesQuery(qid, qEntry, lowerQuery, numQuery, itemNames)
    if lowerQuery == "" then return true end
    if numQuery and qid == numQuery then return true end

    local name = qEntry[1]
    if name and name:lower():find(lowerQuery, 1, true) then
        return true
    end

    local giver = qEntry[7]
    if giver and giver:lower():find(lowerQuery, 1, true) then
        return true
    end

    local catName = qEntry[18]
    if catName and catName:lower():find(lowerQuery, 1, true) then
        return true
    end

    local items = qEntry[16]
    if type(items) == "table" then
        for i = 1, #items do
            local iid = items[i][1]
            if numQuery and iid == numQuery then
                return true
            end
            local iname = itemNames[iid]
            if iname and iname:lower():find(lowerQuery, 1, true) then
                return true
            end
        end
    end

    local objText = qEntry[17]
    if objText and objText:lower():find(lowerQuery, 1, true) then
        return true
    end

    return false
end

function FQL:RunQuestSearch()
    local QD = self.QuestData
    if not QD or not QD.quests then return end

    local rawQuery = (searchState.query or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lowerQuery = rawQuery:lower()
    local numQuery = tonumber(rawQuery)
    local itemNames = QD.itemNames or {}

    local targetMapID = nil
    local targetCatName = nil
    if searchState.zoneFilter == "CURRENT" then
        targetMapID = GetActiveZoneMapID()
    elseif type(searchState.zoneFilter) == "number" then
        targetMapID = searchState.zoneFilter
    elseif type(searchState.zoneFilter) == "string" and searchState.zoneFilter ~= "ALL" then
        targetCatName = searchState.zoneFilter
    end

    local statusFilter = searchState.statusFilter or "AVAILABLE"
    local ignoreThresholds = not searchState.useLevelThresholds

    local results = {}
    for qid, qEntry in pairs(QD.quests) do
        local zoneMatch = true
        if targetMapID then
            zoneMatch = (qEntry[4] == targetMapID)
        elseif targetCatName then
            zoneMatch = (qEntry[18] == targetCatName)
        end

        if zoneMatch and QuestMatchesQuery(qid, qEntry, lowerQuery, numQuery, itemNames) then
            local status = self:GetDatabaseQuestStatus(qid, qEntry)
            local statusMatch = false

            if statusFilter == "ALL" then
                statusMatch = true
            elseif statusFilter == "AVAILABLE" then
                local db = _G.shupazForeverQuestLogDB or FQL.DB_DEFAULTS
                statusMatch = (status == "AVAILABLE") or (status == "HIGH_LEVEL" and db.showUpcomingHighLevelQuests == true)
            elseif statusFilter == "UNCOMPLETED" then
                statusMatch = (status == "AVAILABLE" or status == "HIGH_LEVEL" or status == "PREREQ_LOCKED" or status == "SKILL_LOCKED" or status == "REP_LOCKED" or status == "SPELL_LOCKED")
            elseif statusFilter == "WORLD_EVENT" then
                local flags = qEntry[11] or 0
                statusMatch = (bit and bit.band(flags, 4) ~= 0)
            elseif statusFilter == "IN_LOG" then
                statusMatch = (status == "IN_LOG")
            elseif statusFilter == "COMPLETED" then
                statusMatch = (status == "COMPLETED")
            end

            if statusMatch then
                local passesLevel = true
                if not ignoreThresholds and (statusFilter == "AVAILABLE" or statusFilter == "UNCOMPLETED") then
                    passesLevel = self:PassesLevelThreshold(qEntry, false)
                end
                if passesLevel then
                    results[#results + 1] = {
                        questID = qid,
                        qEntry = qEntry,
                        status = status,
                    }
                end
            end
        end
    end

    table.sort(results, function(a, b)
        local la = a.qEntry[3] or a.qEntry[2] or 1
        local lb = b.qEntry[3] or b.qEntry[2] or 1
        if la ~= lb then return la < lb end
        local na = a.qEntry[1] or ""
        local nb = b.qEntry[1] or ""
        if na ~= nb then return na < nb end
        return a.questID < b.questID
    end)

    searchState.results = results

    if searchState.selectedQuestID then
        local found = false
        for i = 1, #results do
            if results[i].questID == searchState.selectedQuestID then
                found = true
                break
            end
        end
        if not found and #results > 0 then
            searchState.selectedQuestID = results[1].questID
        end
    elseif #results > 0 then
        searchState.selectedQuestID = results[1].questID
    end

    self:UpdateQuestSearchUI()
end

function FQL:UpdateQuestSearchUI()
    local f = self.searchFrame
    if not f or not f:IsShown() then return end

    f.zoneBtn:SetText(GetZoneFilterLabel())
    f.statusBtn:SetText(GetStatusFilterLabel())
    f.levelCheck:SetChecked(searchState.useLevelThresholds)

    local results = searchState.results or {}
    local total = #results
    f.resultCountText:SetText(string.format("%d Quest(s)", total))

    local offset = FauxScrollFrame_GetOffset(f.listScroll) or 0
    FauxScrollFrame_Update(f.listScroll, math.max(total, 1), VISIBLE_SEARCH_ROWS, SEARCH_ROW_HEIGHT)

    for i = 1, VISIBLE_SEARCH_ROWS do
        local row = f.rows[i]
        local idx = offset + i
        local item = results[idx]
        if item then
            local qid = item.questID
            local qEntry = item.qEntry
            local qName = qEntry[1] or ("Quest #" .. tostring(qid))
            local qLvl = qEntry[3] or qEntry[2] or 1
            local status = item.status

            row.questID = qid
            local r, g, b = 1, 0.82, 0
            if FQL.GetDifficultyColor then
                r, g, b = FQL.GetDifficultyColor(qLvl)
            end

            local statusPrefix = ""
            if status == "AVAILABLE" then
                statusPrefix = "|cffffd100!|r "
            elseif status == "HIGH_LEVEL" then
                statusPrefix = "|cffff4444!|r "
            elseif status == "IN_LOG" then
                statusPrefix = "|cff66ccff?|r "
            elseif status == "COMPLETED" then
                statusPrefix = "|cff44dd44✓|r "
            else
                statusPrefix = "|cff888888•|r "
            end

            row.title:SetText(string.format("%s[%d] %s", statusPrefix, qLvl, qName))
            row.title:SetTextColor(r, g, b)

            local cat = qEntry[18] or ""
            row.zoneText:SetText(cat)

            if qid == searchState.selectedQuestID then
                row.selectedTex:Show()
            else
                row.selectedTex:Hide()
            end
            row:Show()
        else
            row.questID = nil
            row:Hide()
        end
    end

    self:UpdateQuestSearchDetails()
end

function FQL:UpdateQuestSearchDetails()
    local f = self.searchFrame
    if not f then return end

    local qid = searchState.selectedQuestID
    local QD = self.QuestData
    local qEntry = (qid and QD and QD.quests) and QD.quests[qid] or nil

    if not qEntry then
        f.detailTitle:SetText("Select a Quest")
        f.detailMeta:SetText("")
        f.detailStatus:SetText("")
        f.detailGiver:SetText("")
        f.detailChain:SetText("")
        f.detailObjHeader:Hide()
        f.detailObjText:SetText("")
        f.detailItemsHeader:Hide()
        for _, btn in ipairs(f.prereqButtons) do btn:Hide() end
        for _, row in ipairs(f.itemRows) do row:Hide() end
        f.showOnMapBtn:Disable()
        if f.hidePinBtn then f.hidePinBtn:Disable() end
        f.wowheadBtn:Disable()
        return
    end

    local qName = qEntry[1] or ("Quest #" .. tostring(qid))
    local reqLvl = qEntry[2] or 1
    local qLvl = qEntry[3] or reqLvl
    local uiMapID = qEntry[4] or 0
    local x = qEntry[5]
    local y = qEntry[6]
    local giverName = qEntry[7]
    local giverType = qEntry[8]
    local flags = qEntry[11] or 0
    local preSingle = qEntry[12]
    local preGroup = qEntry[13]
    local nextQ = qEntry[15]
    local items = qEntry[16]
    local objText = qEntry[17]
    local catName = qEntry[18] or (QD.mapNames and QD.mapNames[uiMapID]) or "World"

    f.detailTitle:SetText(string.format("[%d] %s", qLvl, qName))

    local tagParts = {
        string.format("Quest ID: |cffffffff%d|r", qid),
        string.format("Level: |cffffffff%d|r (Req: |cffffffff%d|r)", qLvl, reqLvl),
        string.format("Zone: |cffffffff%s|r", catName),
    }
    if bit and bit.band(flags, 2) ~= 0 then
        tagParts[#tagParts + 1] = "|cff55aaff[Dungeon/Group]|r"
    end
    if bit and bit.band(flags, 1) ~= 0 then
        tagParts[#tagParts + 1] = "|cff00ccff[Repeatable]|r"
    end
    if bit and bit.band(flags, 4) ~= 0 then
        tagParts[#tagParts + 1] = "|cffff99cc[World Event]|r"
    end
    local reqSkill = qEntry[20]
    if type(reqSkill) == "table" and reqSkill[1] then
        local sName = (FQL.SKILL_ID_TO_NAME and FQL.SKILL_ID_TO_NAME[reqSkill[1]]) or ("Skill #" .. tostring(reqSkill[1]))
        tagParts[#tagParts + 1] = string.format("|cffffcc66[%s (%d)]|r", sName, reqSkill[2] or 1)
    end
    f.detailMeta:SetText(table.concat(tagParts, "   •   "))

    local status = self:GetDatabaseQuestStatus(qid, qEntry)
    f.detailStatus:SetText("Status: " .. (STATUS_BADGES[status] or status))

    if f.hidePinBtn then
        f.hidePinBtn:Enable()
        local isHidden = (self.IsQuestHiddenByUser and self:IsQuestHiddenByUser(qid)) or (self.sessionInactiveQuests and self.sessionInactiveQuests[qid])
        f.hidePinBtn:SetText(isHidden and "Unhide Pin" or "Hide Pin")
    end

    if giverName and x and y then
        local typeLabel = (giverType == 2 and "Object") or (giverType == 3 and "Starter Item") or "NPC"
        local mapName = (QD.mapNames and QD.mapNames[uiMapID]) or catName
        f.detailGiver:SetText(string.format("Start (%s): |cffffd100%s|r — %s |cffffffff(%.1f, %.1f)|r", typeLabel, giverName, mapName, x, y))
        f.showOnMapBtn:Enable()
    elseif giverName then
        f.detailGiver:SetText(string.format("Start: |cffffd100%s|r (%s)", giverName, catName))
        if uiMapID and uiMapID > 0 then
            f.showOnMapBtn:Enable()
        else
            f.showOnMapBtn:Disable()
        end
    else
        f.detailGiver:SetText("Start: |cff888888Unknown / Automatic|r")
        f.showOnMapBtn:Disable()
    end
    f.wowheadBtn:Enable()

    local yCursor = -108

    -- Prerequisite & Next Quest clickable buttons
    for _, btn in ipairs(f.prereqButtons) do btn:Hide() end
    local chainLinks = {}
    if type(preSingle) == "table" then
        for i = 1, math.min(#preSingle, 2) do
            chainLinks[#chainLinks + 1] = { qid = preSingle[i], prefix = "Requires: " }
        end
    end
    if type(preGroup) == "table" then
        for i = 1, math.min(#preGroup, 2) do
            chainLinks[#chainLinks + 1] = { qid = preGroup[i], prefix = "Requires: " }
        end
    end
    if nextQ and nextQ > 0 then
        chainLinks[#chainLinks + 1] = { qid = nextQ, prefix = "Next in Chain: " }
    end

    if #chainLinks > 0 then
        f.detailChain:SetPoint("TOPLEFT", f.detailScrollChild, "TOPLEFT", 10, yCursor)
        f.detailChain:SetText("Quest Chain (Click to jump):")
        f.detailChain:Show()
        yCursor = yCursor - 16
        for i = 1, math.min(#chainLinks, #f.prereqButtons) do
            local linkInfo = chainLinks[i]
            local targetID = linkInfo.qid
            local targetEntry = QD.quests[targetID]
            local targetName = (targetEntry and targetEntry[1]) or ("Quest #" .. tostring(targetID))
            local done = self:IsQuestCompletedByPlayer(targetID)
            local doneTag = done and " |cff44dd44(Done)|r" or ""

            local btn = f.prereqButtons[i]
            btn.targetQuestID = targetID
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", f.detailScrollChild, "TOPLEFT", 14, yCursor)
            btn.text:SetText(string.format("• %s|cffffd100[%d] %s|r%s", linkInfo.prefix, targetID, targetName, doneTag))
            btn:Show()
            yCursor = yCursor - 18
        end
        yCursor = yCursor - 6
    else
        f.detailChain:SetText("")
        f.detailChain:Hide()
    end

    -- Objectives Text
    if objText and objText ~= "" then
        f.detailObjHeader:ClearAllPoints()
        f.detailObjHeader:SetPoint("TOPLEFT", f.detailScrollChild, "TOPLEFT", 10, yCursor)
        f.detailObjHeader:Show()
        yCursor = yCursor - 18

        f.detailObjText:ClearAllPoints()
        f.detailObjText:SetPoint("TOPLEFT", f.detailScrollChild, "TOPLEFT", 12, yCursor)
        f.detailObjText:SetText(objText)
        f.detailObjText:Show()
        local textH = math.max(20, f.detailObjText:GetStringHeight() or 20)
        yCursor = yCursor - textH - 12
    else
        f.detailObjHeader:Hide()
        f.detailObjText:SetText("")
        f.detailObjText:Hide()
    end

    -- Associated Items Section
    for _, row in ipairs(f.itemRows) do row:Hide() end
    local itemNames = QD.itemNames or {}

    if type(items) == "table" and #items > 0 then
        f.detailItemsHeader:ClearAllPoints()
        f.detailItemsHeader:SetPoint("TOPLEFT", f.detailScrollChild, "TOPLEFT", 10, yCursor)
        f.detailItemsHeader:Show()
        yCursor = yCursor - 20

        local count = math.min(#items, #f.itemRows)
        for i = 1, count do
            local pair = items[i]
            local iid = pair[1]
            local role = pair[2]
            local iname = itemNames[iid] or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(iid)) or ("Item #" .. tostring(iid))
            local iconTex = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(iid))
                or (GetItemIcon and GetItemIcon(iid))
                or "Interface\\Icons\\INV_Misc_QuestionMark"

            local irow = f.itemRows[i]
            irow.itemID = iid
            irow.itemName = iname
            irow.icon:SetTexture(iconTex)
            irow.nameText:SetText(string.format("%s |cff666666(#%d)|r", iname, iid))
            irow.roleText:SetText(ROLE_NAMES[role] or "Item")
            irow:ClearAllPoints()
            irow:SetPoint("TOPLEFT", f.detailScrollChild, "TOPLEFT", 12, yCursor)
            irow:Show()
            yCursor = yCursor - 26
        end
    else
        f.detailItemsHeader:Hide()
    end

    f.detailScrollChild:SetHeight(math.max(360, -yCursor + 20))
end

local function ToggleZoneMenu(anchorBtn)
    local f = FQL.searchFrame
    if not f then return end
    if f.zoneMenu and f.zoneMenu:IsShown() then
        f.zoneMenu:Hide()
        return
    end
    if f.statusMenu then f.statusMenu:Hide() end

    if not f.zoneMenu then
        local menu = CreateFrame("Frame", "shupaz_ForeverQuestLogSearchZoneMenu", f, "BackdropTemplate")
        menu:SetSize(210, 310)
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel(f:GetFrameLevel() + 30)
        ApplyBoxBackdrop(menu, { 0.06, 0.06, 0.08, 0.96 }, { 0.6, 0.5, 0.25, 1 })

        local scroll = CreateFrame("ScrollFrame", "shupaz_ForeverQuestLogSearchZoneMenuScroll", menu, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -26, 6)

        local child = CreateFrame("Frame", nil, scroll)
        child:SetWidth(175)
        scroll:SetScrollChild(child)

        local entries = {
            { value = "CURRENT", label = "|cffffd100Current Zone|r" },
            { value = "ALL",     label = "|cff88ff88All Zones & Dungeons|r" },
        }

        local QD = FQL.QuestData
        local mapList = {}
        if QD and QD.mapNames then
            for uimap, mname in pairs(QD.mapNames) do
                mapList[#mapList + 1] = { value = uimap, label = mname }
            end
        end
        table.sort(mapList, function(a, b) return a.label < b.label end)
        for _, m in ipairs(mapList) do
            entries[#entries + 1] = m
        end

        for idx, item in ipairs(entries) do
            local btn = CreateFrame("Button", nil, child)
            btn:SetSize(175, 20)
            btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((idx - 1) * 20))

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAlpha(0.45)

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", btn, "LEFT", 6, 0)
            txt:SetJustifyH("LEFT")
            txt:SetText(item.label)

            btn:SetScript("OnClick", function()
                FQL.PlayClickSound()
                searchState.zoneFilter = item.value
                menu:Hide()
                FQL:RunQuestSearch()
            end)
        end

        child:SetHeight(#entries * 20 + 4)
        f.zoneMenu = menu
    end

    f.zoneMenu:ClearAllPoints()
    f.zoneMenu:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    f.zoneMenu:Show()
end

local function ToggleStatusMenu(anchorBtn)
    local f = FQL.searchFrame
    if not f then return end
    if f.statusMenu and f.statusMenu:IsShown() then
        f.statusMenu:Hide()
        return
    end
    if f.zoneMenu then f.zoneMenu:Hide() end

    if not f.statusMenu then
        local menu = CreateFrame("Frame", "shupaz_ForeverQuestLogSearchStatusMenu", f, "BackdropTemplate")
        menu:SetSize(160, #STATUS_FILTERS * 22 + 12)
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel(f:GetFrameLevel() + 30)
        ApplyBoxBackdrop(menu, { 0.06, 0.06, 0.08, 0.96 }, { 0.6, 0.5, 0.25, 1 })

        for idx, item in ipairs(STATUS_FILTERS) do
            local btn = CreateFrame("Button", nil, menu)
            btn:SetSize(148, 20)
            btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - ((idx - 1) * 22))

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAlpha(0.45)

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", btn, "LEFT", 6, 0)
            txt:SetJustifyH("LEFT")
            txt:SetText(item.label)

            btn:SetScript("OnClick", function()
                FQL.PlayClickSound()
                searchState.statusFilter = item.id
                menu:Hide()
                FQL:RunQuestSearch()
            end)
        end

        f.statusMenu = menu
    end

    f.statusMenu:ClearAllPoints()
    f.statusMenu:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    f.statusMenu:Show()
end

function FQL:CreateQuestSearchFrame()
    if self.searchFrame then return self.searchFrame end

    local f = CreateFrame("Frame", "shupaz_ForeverQuestLogSearchFrame", UIParent, "BackdropTemplate")
    f:SetSize(730, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 40, 0)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
    end)
    ApplyBoxBackdrop(f, { 0.05, 0.05, 0.07, 0.96 }, { 0.55, 0.46, 0.24, 1 })
    f:Hide()

    tinsert(UISpecialFrames, "shupaz_ForeverQuestLogSearchFrame")

    -- Top Header Bar
    local headerBg = f:CreateTexture(nil, "ARTWORK")
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    headerBg:SetHeight(28)
    headerBg:SetColorTexture(0.11, 0.09, 0.06, 0.95)

    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", headerBg, "LEFT", 8, 0)
    icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("Forever Quest & Item Database Search")

    local closeTopBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeTopBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    -- Filter Bar (Row under Header)
    local filterBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    filterBar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
    filterBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -36)
    filterBar:SetHeight(34)
    ApplyBoxBackdrop(filterBar, { 0.08, 0.08, 0.1, 0.9 }, { 0.3, 0.3, 0.35, 0.9 })

    local searchLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("LEFT", filterBar, "LEFT", 8, 0)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", "shupaz_ForeverQuestLogSearchEditBox", filterBar, "InputBoxTemplate")
    searchBox:SetSize(185, 22)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(eb, userInput)
        searchState.query = eb:GetText() or ""
        if userInput then
            FQL:RunQuestSearch()
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
        FQL:RunQuestSearch()
    end)
    searchBox:SetScript("OnEscapePressed", function(eb)
        if eb:GetText() ~= "" then
            eb:SetText("")
            searchState.query = ""
            FQL:RunQuestSearch()
        else
            eb:ClearFocus()
        end
    end)
    f.searchBox = searchBox

    local clearBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    clearBtn:SetSize(22, 20)
    clearBtn:SetPoint("LEFT", searchBox, "RIGHT", 2, 0)
    clearBtn:SetText("X")
    clearBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        searchState.query = ""
        FQL:RunQuestSearch()
    end)

    -- Zone Filter Button
    local zoneBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    zoneBtn:SetSize(165, 22)
    zoneBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
    zoneBtn:SetText("Current Zone")
    zoneBtn:SetScript("OnClick", function(btn)
        FQL.PlayClickSound()
        ToggleZoneMenu(btn)
    end)
    f.zoneBtn = zoneBtn

    -- Status Filter Button
    local statusBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    statusBtn:SetSize(130, 22)
    statusBtn:SetPoint("LEFT", zoneBtn, "RIGHT", 6, 0)
    statusBtn:SetText("Available Now")
    statusBtn:SetScript("OnClick", function(btn)
        FQL.PlayClickSound()
        ToggleStatusMenu(btn)
    end)
    f.statusBtn = statusBtn

    -- Level Threshold Checkbox
    local levelCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    levelCheck:SetSize(22, 22)
    levelCheck:SetPoint("LEFT", statusBtn, "RIGHT", 6, 0)
    levelCheck:SetChecked(true)
    local levelCheckText = levelCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelCheckText:SetPoint("LEFT", levelCheck, "RIGHT", 2, 0)
    levelCheckText:SetText("Level Filter")
    levelCheck:SetScript("OnClick", function(cb)
        FQL.PlayClickSound()
        searchState.useLevelThresholds = cb:GetChecked() and true or false
        FQL:RunQuestSearch()
    end)
    levelCheck:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Use Level Thresholds", 1, 0.82, 0)
            GameTooltip:AddLine("When checked, filters quests using your Low/High Level Thresholds configured in Options.\nUncheck to view quests of all levels (1-60).", 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end
    end)
    levelCheck:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    f.levelCheck = levelCheck

    -- Left Pane (Quest List)
    local leftPane = CreateFrame("Frame", nil, f, "BackdropTemplate")
    leftPane:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -74)
    leftPane:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 40)
    leftPane:SetWidth(325)
    ApplyBoxBackdrop(leftPane, { 0.04, 0.04, 0.05, 0.94 }, { 0.35, 0.31, 0.22, 0.9 })
    f.leftPane = leftPane

    local resultCountText = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultCountText:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 8, -6)
    resultCountText:SetText("0 Quest(s)")
    f.resultCountText = resultCountText

    local listScroll = CreateFrame("ScrollFrame", "shupaz_ForeverQuestLogSearchListScroll", leftPane, "FauxScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 4, -22)
    listScroll:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -26, 6)
    listScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, SEARCH_ROW_HEIGHT, function()
            FQL:UpdateQuestSearchUI()
        end)
    end)
    f.listScroll = listScroll

    f.rows = {}
    for i = 1, VISIBLE_SEARCH_ROWS do
        local row = CreateFrame("Button", nil, leftPane)
        row:SetSize(292, SEARCH_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 6, -22 - (i - 1) * SEARCH_ROW_HEIGHT)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.35)

        local sel = row:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        sel:SetVertexColor(0.85, 0.7, 0.2, 0.35)
        sel:Hide()
        row.selectedTex = sel

        local rTitle = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rTitle:SetPoint("LEFT", row, "LEFT", 4, 0)
        rTitle:SetWidth(205)
        rTitle:SetJustifyH("LEFT")
        rTitle:SetWordWrap(false)
        row.title = rTitle

        local rZone = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rZone:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        rZone:SetWidth(80)
        rZone:SetJustifyH("RIGHT")
        rZone:SetWordWrap(false)
        row.zoneText = rZone

        row:SetScript("OnClick", function(selfRow)
            if not selfRow.questID then return end
            FQL.PlayClickSound()
            if IsShiftKeyDown and IsShiftKeyDown() then
                local qEntry = FQL.QuestData and FQL.QuestData.quests and FQL.QuestData.quests[selfRow.questID]
                local qName = (qEntry and qEntry[1]) or ("Quest " .. tostring(selfRow.questID))
                local qLvl = (qEntry and qEntry[3]) or -1
                if not FQL.TryInsertQuestChatLink(selfRow.questID, qName, qLvl) then
                    FQL:ShowCopyURLPopup(FQL.GetQuestWebURL(selfRow.questID), qName)
                end
                return
            end
            searchState.selectedQuestID = selfRow.questID
            FQL:UpdateQuestSearchUI()
        end)

        f.rows[i] = row
    end

    -- Right Pane (Quest Details & Items)
    local rightPane = CreateFrame("Frame", nil, f, "BackdropTemplate")
    rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 8, 0)
    rightPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 40)
    ApplyBoxBackdrop(rightPane, { 0.06, 0.05, 0.04, 0.94 }, { 0.35, 0.31, 0.22, 0.9 })
    f.rightPane = rightPane

    local detailScroll = CreateFrame("ScrollFrame", "shupaz_ForeverQuestLogSearchDetailScroll", rightPane, "UIPanelScrollFrameTemplate")
    detailScroll:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 6, -6)
    detailScroll:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", -26, 6)
    f.detailScroll = detailScroll

    local detailChild = CreateFrame("Frame", nil, detailScroll)
    detailChild:SetSize(340, 400)
    detailScroll:SetScrollChild(detailChild)
    f.detailScrollChild = detailChild

    local detailTitle = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailTitle:SetPoint("TOPLEFT", detailChild, "TOPLEFT", 10, -8)
    detailTitle:SetWidth(320)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetTextColor(1, 0.82, 0)
    f.detailTitle = detailTitle

    local detailMeta = detailChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailMeta:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -6)
    detailMeta:SetWidth(320)
    detailMeta:SetJustifyH("LEFT")
    detailMeta:SetTextColor(0.8, 0.8, 0.8)
    f.detailMeta = detailMeta

    local detailStatus = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailStatus:SetPoint("TOPLEFT", detailMeta, "BOTTOMLEFT", 0, -6)
    detailStatus:SetWidth(320)
    detailStatus:SetJustifyH("LEFT")
    f.detailStatus = detailStatus

    local detailGiver = detailChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailGiver:SetPoint("TOPLEFT", detailStatus, "BOTTOMLEFT", 0, -6)
    detailGiver:SetWidth(320)
    detailGiver:SetJustifyH("LEFT")
    f.detailGiver = detailGiver

    local detailChain = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailChain:SetPoint("TOPLEFT", detailGiver, "BOTTOMLEFT", 0, -10)
    detailChain:SetWidth(320)
    detailChain:SetJustifyH("LEFT")
    detailChain:SetTextColor(0.9, 0.8, 0.5)
    f.detailChain = detailChain

    f.prereqButtons = {}
    for i = 1, 5 do
        local pbtn = CreateFrame("Button", nil, detailChild)
        pbtn:SetSize(315, 16)
        local ptxt = pbtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ptxt:SetPoint("LEFT", pbtn, "LEFT", 0, 0)
        ptxt:SetJustifyH("LEFT")
        pbtn.text = ptxt
        pbtn:SetScript("OnClick", function(selfBtn)
            if selfBtn.targetQuestID then
                FQL.PlayClickSound()
                FQL:OpenQuestSearch(selfBtn.targetQuestID)
            end
        end)
        pbtn:Hide()
        f.prereqButtons[i] = pbtn
    end

    local detailObjHeader = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailObjHeader:SetText("Objectives")
    detailObjHeader:SetTextColor(1, 0.82, 0)
    f.detailObjHeader = detailObjHeader

    local detailObjText = detailChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailObjText:SetWidth(315)
    detailObjText:SetJustifyH("LEFT")
    detailObjText:SetTextColor(0.9, 0.9, 0.9)
    f.detailObjText = detailObjText

    local detailItemsHeader = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailItemsHeader:SetText("Items Used & Rewarded (Hover for Tooltip, Click to Search)")
    detailItemsHeader:SetTextColor(1, 0.82, 0)
    f.detailItemsHeader = detailItemsHeader

    f.itemRows = {}
    for i = 1, 14 do
        local irow = CreateFrame("Button", nil, detailChild, "BackdropTemplate")
        irow:SetSize(318, 24)
        ApplyBoxBackdrop(irow, { 0.1, 0.1, 0.12, 0.85 }, { 0.3, 0.3, 0.35, 0.8 }, 10, 2)

        local hl = irow:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.3)

        local iIcon = irow:CreateTexture(nil, "ARTWORK")
        iIcon:SetSize(18, 18)
        iIcon:SetPoint("LEFT", irow, "LEFT", 4, 0)
        irow.icon = iIcon

        local iName = irow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        iName:SetPoint("LEFT", iIcon, "RIGHT", 6, 0)
        iName:SetWidth(200)
        iName:SetJustifyH("LEFT")
        iName:SetWordWrap(false)
        irow.nameText = iName

        local iRole = irow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        iRole:SetPoint("RIGHT", irow, "RIGHT", -6, 0)
        iRole:SetJustifyH("RIGHT")
        irow.roleText = iRole

        irow:SetScript("OnEnter", function(selfItem)
            if not selfItem.itemID or not GameTooltip then return end
            GameTooltip:SetOwner(selfItem, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then
                pcall(GameTooltip.SetItemByID, GameTooltip, selfItem.itemID)
            else
                GameTooltip:SetHyperlink("item:" .. tostring(selfItem.itemID))
            end
            GameTooltip:Show()
        end)

        irow:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        irow:SetScript("OnClick", function(selfItem)
            if not selfItem.itemName then return end
            FQL.PlayClickSound()
            if IsShiftKeyDown and IsShiftKeyDown() then
                local url = "https://www.wowhead.com/forever/item=" .. tostring(selfItem.itemID)
                FQL:ShowCopyURLPopup(url, selfItem.itemName)
            else
                f.searchBox:SetText(selfItem.itemName)
                searchState.query = selfItem.itemName
                searchState.zoneFilter = "ALL"
                searchState.statusFilter = "ALL"
                FQL:RunQuestSearch()
            end
        end)

        irow:Hide()
        f.itemRows[i] = irow
    end

    -- Bottom Action Buttons
    local showOnMapBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    showOnMapBtn:SetSize(110, 24)
    showOnMapBtn:SetPoint("BOTTOMLEFT", rightPane, "BOTTOMLEFT", 0, -30)
    showOnMapBtn:SetText("Show on Map")
    showOnMapBtn:SetScript("OnClick", function()
        if not searchState.selectedQuestID then return end
        FQL.PlayClickSound()
        FQL:HighlightQuestOnMap(searchState.selectedQuestID)
    end)
    f.showOnMapBtn = showOnMapBtn

    local hidePinBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    hidePinBtn:SetSize(92, 24)
    hidePinBtn:SetPoint("LEFT", showOnMapBtn, "RIGHT", 5, 0)
    hidePinBtn:SetText("Hide Pin")
    hidePinBtn:SetScript("OnClick", function()
        local qid = searchState.selectedQuestID
        if not qid then return end
        FQL.PlayClickSound()
        local isHidden = (FQL.IsQuestHiddenByUser and FQL:IsQuestHiddenByUser(qid)) or (FQL.sessionInactiveQuests and FQL.sessionInactiveQuests[qid])
        if FQL.SetQuestHiddenByUser then
            FQL:SetQuestHiddenByUser(qid, not isHidden)
        end
        if FQL.RefreshMapQuestPins then
            FQL:RefreshMapQuestPins()
        end
        FQL:RunQuestSearch()
    end)
    f.hidePinBtn = hidePinBtn

    local wowheadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    wowheadBtn:SetSize(105, 24)
    wowheadBtn:SetPoint("LEFT", hidePinBtn, "RIGHT", 5, 0)
    wowheadBtn:SetText("Wowhead URL")
    wowheadBtn:SetScript("OnClick", function()
        local qid = searchState.selectedQuestID
        if not qid then return end
        FQL.PlayClickSound()
        local qEntry = FQL.QuestData and FQL.QuestData.quests and FQL.QuestData.quests[qid]
        local qName = (qEntry and qEntry[1]) or ("Quest #" .. tostring(qid))
        FQL:ShowCopyURLPopup(FQL.GetQuestWebURL(qid), qName)
    end)
    f.wowheadBtn = wowheadBtn

    local closeBottomBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBottomBtn:SetSize(80, 24)
    closeBottomBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    closeBottomBtn:SetText(CLOSE or "Close")
    closeBottomBtn:SetScript("OnClick", function()
        FQL.PlayCloseSound()
        f:Hide()
    end)

    self.searchFrame = f
    return f
end

function FQL:RefreshQuestSearch()
    if self.searchFrame and self.searchFrame:IsShown() then
        self:RunQuestSearch()
    end
end

function FQL:OpenQuestSearch(questID, initialQuery)
    local f = self:CreateQuestSearchFrame()
    if initialQuery and initialQuery ~= "" then
        f.searchBox:SetText(initialQuery)
        searchState.query = initialQuery
        searchState.zoneFilter = "ALL"
        searchState.statusFilter = "ALL"
    end

    if questID and self.QuestData and self.QuestData.quests and self.QuestData.quests[questID] then
        searchState.selectedQuestID = questID
        -- Ensure the selected quest is visible in the filter
        local qEntry = self.QuestData.quests[questID]
        local status = self:GetDatabaseQuestStatus(questID, qEntry)
        if status ~= "AVAILABLE" and searchState.statusFilter == "AVAILABLE" then
            searchState.statusFilter = "ALL"
        end
        if searchState.zoneFilter == "CURRENT" then
            local curMap = GetActiveZoneMapID()
            if curMap and qEntry[4] ~= curMap then
                searchState.zoneFilter = qEntry[4] > 0 and qEntry[4] or "ALL"
            end
        end
        if searchState.useLevelThresholds and not self:PassesLevelThreshold(qEntry, false) then
            searchState.useLevelThresholds = false
        end
    end

    f:Show()
    f:Raise()
    self:RunQuestSearch()
end

function FQL:ToggleQuestSearch()
    local f = self:CreateQuestSearchFrame()
    if f:IsShown() then
        FQL.PlayCloseSound()
        f:Hide()
    else
        FQL.PlayOpenSound()
        f:Show()
        f:Raise()
        self:RunQuestSearch()
    end
end
