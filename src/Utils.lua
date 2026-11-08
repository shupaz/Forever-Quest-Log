local ADDON_NAME, FQL = ...

-- ============================================================
-- Tracker Fonts
-- ============================================================

local BUILTIN_TRACKER_FONTS = {
    { id = "DEFAULT",  label = "Friz Quadrata (Default)", path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
    { id = "ARIALN",   label = "Arial Narrow",            path = "Fonts\\ARIALN.TTF" },
    { id = "MORPHEUS", label = "Morpheus (Quest Header)", path = "Fonts\\MORPHEUS.TTF" },
    { id = "SKURRI",   label = "Skurri",                  path = "Fonts\\SKURRI.TTF" },
    { id = "2002",     label = "2002",                    path = "Fonts\\2002.TTF" },
    { id = "2002B",    label = "2002 Bold",               path = "Fonts\\2002B.TTF" },
    { id = "NIMROD",   label = "Nimrod MT",               path = "Fonts\\NIM_____.ttf" },
    { id = "MOK",      label = "MoK (Page Text)",         path = "Fonts\\K_Pagetext.TTF" },
    { id = "ARHEI",    label = "AR CrystalzcuheiGBK",     path = "Fonts\\ARHei.TTF" },
    { id = "ARKAI",    label = "AR ZhongkaiGBK",          path = "Fonts\\ARKai_T.TTF" },
}

function FQL:GetTrackerFonts()
    local list = {}
    local seenPaths = {}
    for _, entry in ipairs(BUILTIN_TRACKER_FONTS) do
        list[#list + 1] = entry
        seenPaths[entry.path:lower()] = true
    end
    -- Also include any extra fonts registered in LibSharedMedia-3.0 if present
    if _G.LibStub then
        local ok, lsm = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm and type(lsm.List) == "function" and type(lsm.Fetch) == "function" then
            local names = lsm:List("font")
            if type(names) == "table" then
                for _, name in ipairs(names) do
                    local path = lsm:Fetch("font", name)
                    if type(path) == "string" and path ~= "" and not seenPaths[path:lower()] then
                        seenPaths[path:lower()] = true
                        list[#list + 1] = {
                            id = "LSM:" .. name,
                            label = name,
                            path = path,
                        }
                    end
                end
            end
        end
    end
    return list
end

function FQL:GetTrackerFontEntry(fontID)
    fontID = fontID or (shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerFont) or "DEFAULT"
    local fonts = self:GetTrackerFonts()
    for i, entry in ipairs(fonts) do
        if entry.id == fontID then
            return entry, i, fonts
        end
    end
    return fonts[1], 1, fonts
end

function FQL:GetTrackerFontPath()
    local entry = self:GetTrackerFontEntry()
    if not entry or entry.id == "DEFAULT" then
        return nil -- nil means restore/keep native font path
    end
    return entry.path
end



-- ============================================================
-- Core Helpers & Quest API Wrappers
-- ============================================================

local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function SafeStr(v)
    if type(v) == "string" and not IsSecret(v) and v ~= "" then
        return v
    end
    return nil
end

local function SafeNum(v)
    if type(v) == "number" and not IsSecret(v) then
        return v
    end
    return nil
end

local function CanChangeFrame(f)
    if not f then return false end
    if InCombatLockdown and InCombatLockdown() and f.IsProtected and f:IsProtected() then
        return false
    end
    return true
end

local function PlayOpenSound()
    if PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN) or 844)
    end
end

local function PlayCloseSound()
    if PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_CLOSE) or 845)
    end
end

local function PlayClickSound()
    if PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856)
    end
end

local function SetBackdrop(frameObj, bgFile, edgeFile, edgeSize, inset)
    if not frameObj or not frameObj.SetBackdrop then return end
    local ins = inset or 3
    frameObj:SetBackdrop({
        bgFile = bgFile or "Interface\\Buttons\\WHITE8X8",
        edgeFile = edgeFile or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = edgeSize or 12,
        insets = { left = ins, right = ins, top = ins, bottom = ins },
    })
end

local function AddClassicParchment(frameObj, alpha, r, g, b)
    local tex = frameObj:CreateTexture(nil, "BACKGROUND", nil, -2)
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetTexture("Interface\\QuestFrame\\QuestBG")
    tex:SetTexCoord(0, 0.585, 0, 0.65)
    tex:SetVertexColor(r or 1, g or 0.96, b or 0.84)
    tex:SetAlpha(alpha or 0.16)
    return tex
end

local function FormatNumber(n)
    n = SafeNum(n)
    if not n then return "0" end
    if BreakUpLargeNumbers then
        local ok, s = pcall(BreakUpLargeNumbers, n)
        if ok and SafeStr(s) then return s end
    end
    local formatted = tostring(math.floor(n))
    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- ============================================================
-- Quest API Wrappers (Compatible with WoW: Forever 16001)
-- ============================================================

local function GetMaxQuests()
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        local ok, m = pcall(C_QuestLog.GetMaxNumQuestsCanAccept)
        if ok and SafeNum(m) and m > 0 then return m end
    end
    if Constants and Constants.QuestLogConsts and Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT then
        return Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT
    end
    return MAX_QUESTS or 25
end

local function ExpandAllNativeHeaders()
    if ExpandQuestHeader then
        pcall(ExpandQuestHeader, 0)
    end
end

local function GetNumLogEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, numShown, numQuests = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and SafeNum(numShown) then
            return numShown, SafeNum(numQuests) or 0
        end
    end
    if GetNumQuestLogEntries then
        local ok, numShown, numQuests = pcall(GetNumQuestLogEntries)
        if ok and SafeNum(numShown) then
            return numShown, SafeNum(numQuests) or 0
        end
    end
    return 0, 0
end

local function GetLogEntryInfo(index)
    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if ok and type(info) == "table" then
            return {
                logIndex = index,
                title = SafeStr(info.title) or "Unknown",
                level = SafeNum(info.level) or 0,
                suggestedGroup = SafeNum(info.suggestedGroup) or 0,
                isHeader = info.isHeader == true,
                isCollapsed = info.isCollapsed == true,
                isComplete = info.isComplete,
                frequency = SafeNum(info.frequency),
                questID = SafeNum(info.questID) or 0,
                isOnMap = info.isOnMap == true,
                hasLocalPOI = info.hasLocalPOI == true,
                isTask = info.isTask == true,
                isBounty = info.isBounty == true,
                isHidden = info.isHidden == true,
                isScaling = info.isScaling == true,
                difficultyLevel = SafeNum(info.difficultyLevel),
            }
        end
    end
    if GetQuestLogTitle then
        local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, _, _, isOnMap, hasLocalPOI, isTask, isBounty, _, isHidden, isScaling = pcall(GetQuestLogTitle, index)
        if ok and SafeStr(title) then
            return {
                logIndex = index,
                title = title,
                level = SafeNum(level) or 0,
                suggestedGroup = SafeNum(suggestedGroup) or 0,
                isHeader = isHeader == true or isHeader == 1,
                isCollapsed = isCollapsed == true or isCollapsed == 1,
                isComplete = SafeNum(isComplete),
                frequency = SafeNum(frequency),
                questID = SafeNum(questID) or 0,
                isOnMap = isOnMap == true or isOnMap == 1,
                hasLocalPOI = hasLocalPOI == true or hasLocalPOI == 1,
                isTask = isTask == true or isTask == 1,
                isBounty = isBounty == true or isBounty == 1,
                isHidden = isHidden == true or isHidden == 1,
                isScaling = isScaling == true or isScaling == 1,
            }
        end
    end
    return nil
end

local function GetLogIndexForQuest(questID)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return nil end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and SafeNum(idx) and idx > 0 then return idx end
    end
    if GetQuestLogIndexByID then
        local ok, idx = pcall(GetQuestLogIndexByID, questID)
        if ok and SafeNum(idx) and idx > 0 then return idx end
    end
    local numShown = GetNumLogEntries()
    for i = 1, numShown do
        local info = GetLogEntryInfo(i)
        if info and not info.isHeader and info.questID == questID then
            return i
        end
    end
    return nil
end

local function SelectLogQuest(questID, logIndex)
    questID = SafeNum(questID)
    logIndex = SafeNum(logIndex) or (questID and GetLogIndexForQuest(questID))
    if C_QuestLog and C_QuestLog.SetSelectedQuest and questID and questID > 0 then
        pcall(C_QuestLog.SetSelectedQuest, questID)
    end
    if SelectQuestLogEntry and logIndex and logIndex > 0 then
        pcall(SelectQuestLogEntry, logIndex)
    end
end

local function IsQuestCompleteOrFailed(questID, infoComplete)
    if C_QuestLog and C_QuestLog.IsComplete and questID and questID > 0 then
        local ok, done = pcall(C_QuestLog.IsComplete, questID)
        if ok and done == true then return 1 end
    end
    if infoComplete == 1 or infoComplete == true then
        return 1
    elseif infoComplete == -1 then
        return -1
    end
    if C_QuestLog and C_QuestLog.ReadyForTurnIn and questID and questID > 0 then
        local ok, ready = pcall(C_QuestLog.ReadyForTurnIn, questID)
        if ok and ready == true then return 1 end
    end
    return 0
end

local function IsQuestWatchedByID(questID, logIndex)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return false end
    if C_QuestLog and C_QuestLog.GetQuestWatchType then
        local ok, watchType = pcall(C_QuestLog.GetQuestWatchType, questID)
        if ok and not IsSecret(watchType) and watchType ~= nil then
            return true
        end
    end
    if IsQuestWatched and logIndex then
        local ok, watched = pcall(IsQuestWatched, logIndex)
        if ok and (watched == true or watched == 1) then return true end
    end
    return false
end

local function SetQuestWatchedByID(questID, logIndex, shouldWatch)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return end
    logIndex = SafeNum(logIndex) or GetLogIndexForQuest(questID)
    local watched = IsQuestWatchedByID(questID, logIndex)
    if shouldWatch and not watched then
        local added = false
        if C_QuestLog and C_QuestLog.AddQuestWatch then
            local ok, res = pcall(C_QuestLog.AddQuestWatch, questID)
            if ok and res ~= false then
                added = IsQuestWatchedByID(questID, logIndex)
            end
            if not added and Enum and Enum.QuestWatchType and Enum.QuestWatchType.Manual then
                pcall(C_QuestLog.AddQuestWatch, questID, Enum.QuestWatchType.Manual)
                added = IsQuestWatchedByID(questID, logIndex)
            end
        end
        if not added and AddQuestWatch and logIndex then
            pcall(AddQuestWatch, logIndex)
        end
    elseif not shouldWatch then
        if C_QuestLog and C_QuestLog.RemoveQuestWatch then
            pcall(C_QuestLog.RemoveQuestWatch, questID)
        end
        if RemoveQuestWatch and logIndex then
            pcall(RemoveQuestWatch, logIndex)
        end
    end
end

local function ToggleQuestWatchByID(questID, logIndex)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return end
    local watched = IsQuestWatchedByID(questID, logIndex)
    SetQuestWatchedByID(questID, logIndex, not watched)
    if C_QuestLog and C_QuestLog.SortQuestWatches then
        pcall(C_QuestLog.SortQuestWatches)
    end
    FQL:RefreshObjectiveTracker(true)
end

local function IsQuestSuperTracked(questID)
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, trackedID = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok and SafeNum(trackedID) and trackedID == questID then
            return true
        end
    end
    return false
end

local function SetQuestSuperTracked(questID)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID and questID then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
    end
end

local function GetQuestTagDetails(questID, info)
    local tagName, tagAbbr = nil, ""
    if C_QuestLog and C_QuestLog.GetQuestTagInfo and questID and questID > 0 then
        local ok, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if ok and type(tagInfo) == "table" then
            tagName = SafeStr(tagInfo.tagName)
            local tagID = SafeNum(tagInfo.tagID)
            if tagID == 1 or (tagName and tagName:lower():find("group")) then
                tagAbbr = "G"
            elseif tagID == 81 or (tagName and tagName:lower():find("dungeon")) then
                tagAbbr = "D"
            elseif tagID == 62 or (tagName and tagName:lower():find("raid")) then
                tagAbbr = "R"
            elseif tagID == 41 or (tagName and tagName:lower():find("pvp")) then
                tagAbbr = "P"
            elseif tagID == 85 or (tagName and tagName:lower():find("heroic")) then
                tagAbbr = "H"
            elseif tagName and tagName:lower():find("elite") then
                tagAbbr = "+"
            end
        end
    elseif GetQuestTagInfo and questID and questID > 0 then
        local ok, _, name = pcall(GetQuestTagInfo, questID)
        if ok and SafeStr(name) then
            tagName = name
        end
    end

    if info and info.suggestedGroup and info.suggestedGroup > 0 and tagAbbr == "" then
        tagAbbr = "G" .. tostring(info.suggestedGroup)
    elseif info and info.suggestedGroup and info.suggestedGroup > 0 and tagAbbr == "G" then
        tagAbbr = "G" .. tostring(info.suggestedGroup)
    end

    if info and info.frequency then
        if info.frequency == (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily or 2) then
            if tagAbbr == "" then tagAbbr = "•" end
            if not tagName then tagName = DAILY or "Daily" end
        elseif info.frequency == (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly or 3) then
            if tagAbbr == "" then tagAbbr = "•" end
            if not tagName then tagName = WEEKLY or "Weekly" end
        end
    end

    return tagName, tagAbbr
end

local function GetDifficultyColor(level)
    level = SafeNum(level) or 0
    if level <= 0 and UnitLevel then
        level = SafeNum(UnitLevel("player")) or 1
    end
    if GetQuestDifficultyColor then
        local ok, c = pcall(GetQuestDifficultyColor, level)
        if ok and type(c) == "table" and c.r then
            return c.r, c.g, c.b
        end
    end
    return 1.0, 0.82, 0.0
end

local function GetQuestTextAndObjectives(questID, logIndex)
    SelectLogQuest(questID, logIndex)
    local description, objectiveSummary = "", ""
    if GetQuestLogQuestText then
        local ok, desc, obj = pcall(GetQuestLogQuestText, logIndex)
        if not ok or (not SafeStr(desc) and not SafeStr(obj)) then
            ok, desc, obj = pcall(GetQuestLogQuestText)
        end
        if ok then
            description = SafeStr(desc) or ""
            objectiveSummary = SafeStr(obj) or ""
        end
    end

    local objectives = {}
    if C_QuestLog and C_QuestLog.GetQuestObjectives and questID and questID > 0 then
        local ok, list = pcall(C_QuestLog.GetQuestObjectives, questID)
        if ok and type(list) == "table" then
            for _, o in ipairs(list) do
                if type(o) == "table" and SafeStr(o.text) then
                    objectives[#objectives + 1] = {
                        text = o.text,
                        finished = o.finished == true,
                        type = SafeStr(o.type),
                    }
                end
            end
        end
    end
    if #objectives == 0 and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard and logIndex then
        local okN, num = pcall(GetNumQuestLeaderBoards, logIndex)
        if okN and SafeNum(num) and num > 0 then
            for i = 1, num do
                local okL, text, objType, finished = pcall(GetQuestLogLeaderBoard, i, logIndex)
                if okL and SafeStr(text) then
                    objectives[#objectives + 1] = {
                        text = text,
                        finished = finished == true or finished == 1,
                        type = SafeStr(objType),
                    }
                end
            end
        end
    end

    return objectiveSummary, description, objectives
end

local function GetQuestRewardsData(questID, logIndex)
    SelectLogQuest(questID, logIndex)
    local data = {
        choices = {},
        fixed = {},
        spells = {},
        xp = 0,
        money = 0,
        requiredMoney = 0,
        timeLeft = nil,
        specialItem = nil,
    }

    -- Choice rewards
    local numChoices = 0
    if GetNumQuestLogChoices then
        local ok, n = pcall(GetNumQuestLogChoices, questID)
        if not ok or not SafeNum(n) then ok, n = pcall(GetNumQuestLogChoices) end
        if ok and SafeNum(n) then numChoices = n end
    end
    for i = 1, numChoices do
        if GetQuestLogChoiceInfo then
            local ok, name, texture, numItems, quality, isUsable, itemID = pcall(GetQuestLogChoiceInfo, i, questID)
            if not ok or (not SafeStr(name) and not SafeNum(itemID)) then
                ok, name, texture, numItems, quality, isUsable, itemID = pcall(GetQuestLogChoiceInfo, i)
            end
            if ok and (SafeStr(name) or SafeNum(itemID)) then
                data.choices[#data.choices + 1] = {
                    index = i,
                    rewardType = "choice",
                    name = SafeStr(name) or (itemID and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or "Unknown Item",
                    texture = texture or (itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark",
                    count = SafeNum(numItems) or 1,
                    quality = SafeNum(quality) or 1,
                    isUsable = isUsable ~= false,
                    itemID = SafeNum(itemID),
                }
            end
        end
    end

    -- Fixed item rewards
    local numFixed = 0
    if GetNumQuestLogRewards then
        local ok, n = pcall(GetNumQuestLogRewards, questID)
        if not ok or not SafeNum(n) then ok, n = pcall(GetNumQuestLogRewards) end
        if ok and SafeNum(n) then numFixed = n end
    end
    for i = 1, numFixed do
        if GetQuestLogRewardInfo then
            local ok, name, texture, numItems, quality, isUsable, itemID = pcall(GetQuestLogRewardInfo, i, questID)
            if not ok or (not SafeStr(name) and not SafeNum(itemID)) then
                ok, name, texture, numItems, quality, isUsable, itemID = pcall(GetQuestLogRewardInfo, i)
            end
            if ok and (SafeStr(name) or SafeNum(itemID)) then
                data.fixed[#data.fixed + 1] = {
                    index = i,
                    rewardType = "reward",
                    name = SafeStr(name) or (itemID and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or "Unknown Item",
                    texture = texture or (itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark",
                    count = SafeNum(numItems) or 1,
                    quality = SafeNum(quality) or 1,
                    isUsable = isUsable ~= false,
                    itemID = SafeNum(itemID),
                }
            end
        end
    end

    -- Spell rewards
    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells and questID then
        local ok, spellIDs = pcall(C_QuestInfoSystem.GetQuestRewardSpells, questID)
        if ok and type(spellIDs) == "table" then
            for _, spellID in ipairs(spellIDs) do
                if SafeNum(spellID) and spellID > 0 then
                    local spellInfo = C_QuestInfoSystem.GetQuestRewardSpellInfo and C_QuestInfoSystem.GetQuestRewardSpellInfo(questID, spellID)
                    local sName = spellInfo and SafeStr(spellInfo.name) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID))
                    local sTex = spellInfo and spellInfo.texture or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)) or (GetSpellInfo and select(3, GetSpellInfo(spellID)))
                    data.spells[#data.spells + 1] = {
                        spellID = spellID,
                        name = sName or ("Spell " .. tostring(spellID)),
                        texture = sTex or "Interface\\Icons\\INV_Misc_Book_09",
                    }
                end
            end
        end
    elseif GetNumQuestLogRewardSpells and GetQuestLogRewardSpell then
        local okN, numSpells = pcall(GetNumQuestLogRewardSpells, questID)
        if not okN or not SafeNum(numSpells) then okN, numSpells = pcall(GetNumQuestLogRewardSpells) end
        if okN and SafeNum(numSpells) and numSpells > 0 then
            for i = 1, math.min(numSpells, 10) do
                local okS, texture, name, _, _, _, _, _, _, spellID = pcall(GetQuestLogRewardSpell, i, questID)
                if not okS then okS, texture, name, _, _, _, _, _, _, spellID = pcall(GetQuestLogRewardSpell, i) end
                if okS and (SafeStr(name) or SafeNum(spellID)) then
                    data.spells[#data.spells + 1] = {
                        index = i,
                        spellID = SafeNum(spellID),
                        name = SafeStr(name) or "Reward Spell",
                        texture = texture or "Interface\\Icons\\INV_Misc_Book_09",
                    }
                end
            end
        end
    end

    -- XP reward
    if GetQuestLogRewardXP then
        local ok, xp = pcall(GetQuestLogRewardXP, questID)
        if not ok or not SafeNum(xp) or xp <= 0 then
            ok, xp = pcall(GetQuestLogRewardXP)
        end
        if ok and SafeNum(xp) and xp > 0 then
            data.xp = xp
        end
    end

    -- Money reward
    if GetQuestLogRewardMoney then
        local ok, money = pcall(GetQuestLogRewardMoney, questID)
        if not ok or not SafeNum(money) or money <= 0 then
            ok, money = pcall(GetQuestLogRewardMoney)
        end
        if ok and SafeNum(money) and money > 0 then
            data.money = money
        end
    end

    -- Required Money
    if GetQuestLogRequiredMoney then
        local ok, reqMoney = pcall(GetQuestLogRequiredMoney, questID)
        if not ok or not SafeNum(reqMoney) then
            ok, reqMoney = pcall(GetQuestLogRequiredMoney)
        end
        if ok and SafeNum(reqMoney) and reqMoney > 0 then
            data.requiredMoney = reqMoney
        end
    end

    -- Quest Timer
    if GetQuestLogTimeLeft then
        local ok, timeLeft = pcall(GetQuestLogTimeLeft, logIndex)
        if ok and SafeNum(timeLeft) and timeLeft > 0 then
            data.timeLeft = timeLeft
        end
    end

    -- Special Quest Item (usable item in log)
    if GetQuestLogSpecialItemInfo and logIndex then
        local ok, link, icon, charges = pcall(GetQuestLogSpecialItemInfo, logIndex)
        if ok and (SafeStr(link) or icon) then
            data.specialItem = {
                logIndex = logIndex,
                link = SafeStr(link),
                icon = icon,
                charges = SafeNum(charges),
            }
        end
    end

    return data
end



-- ============================================================
-- Link & Action Helpers
-- ============================================================

local function SetQuestLogCVarClosed()
    if FQL.SetQuestLogCVarClosed then
        FQL.SetQuestLogCVarClosed()
    end
end

local function TryInsertQuestChatLink(questID, title, level)
    if not questID or not ChatEdit_InsertLink then return false end
    if type(ChatEdit_GetActiveWindow) == "function" and not ChatEdit_GetActiveWindow() then
        return false
    end
    local link
    if GetQuestLink then
        local ok, l = pcall(GetQuestLink, questID)
        if ok and SafeStr(l) then link = l end
    end
    if not link then
        link = "|cffffff00|Hquest:" .. tostring(questID) .. ":" .. tostring(level or -1) .. "|h[" .. tostring(title or ("Quest " .. questID)) .. "]|h|r"
    end
    return ChatEdit_InsertLink(link) and true or false
end

local function InsertOrOpenQuestChatLink(questID, title, level)
    if not questID then return false end
    local link
    if GetQuestLink then
        local ok, l = pcall(GetQuestLink, questID)
        if ok and SafeStr(l) then link = l end
    end
    if not link then
        link = "|cffffff00|Hquest:" .. tostring(questID) .. ":" .. tostring(level or -1) .. "|h[" .. tostring(title or ("Quest " .. questID)) .. "]|h|r"
    end
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then
        return true
    end
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(link)
        return true
    end
    return false
end

local function GetQuestWebURL(questID)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return "" end
    return "https://www.wowhead.com/forever/quest=" .. tostring(questID)
end

local function AbandonSelectedQuest(questID, title)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return end
    local logIndex = GetLogIndexForQuest(questID)
    if not logIndex then return end

    SelectLogQuest(questID, logIndex)
    if C_QuestLog and C_QuestLog.SetAbandonQuest then
        pcall(C_QuestLog.SetAbandonQuest)
    elseif SetAbandonQuest then
        pcall(SetAbandonQuest)
    end

    local abandonName = title
    if C_QuestLog and C_QuestLog.GetAbandonQuestName then
        local ok, n = pcall(C_QuestLog.GetAbandonQuestName)
        if ok and SafeStr(n) then abandonName = n end
    elseif GetAbandonQuestName then
        local ok, n = pcall(GetAbandonQuestName)
        if ok and SafeStr(n) then abandonName = n end
    end

    local items
    if C_QuestLog and C_QuestLog.GetAbandonQuestItems then
        local ok, it = pcall(C_QuestLog.GetAbandonQuestItems)
        if ok and SafeStr(it) then items = it end
    elseif GetAbandonQuestItems then
        local ok, it = pcall(GetAbandonQuestItems)
        if ok and SafeStr(it) then items = it end
    end

    if StaticPopup_Show then
        if items then
            StaticPopup_Hide("ABANDON_QUEST")
            StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", abandonName, items)
        else
            StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
            StaticPopup_Show("ABANDON_QUEST", abandonName)
        end
    end
end

local function ShareSelectedQuest(questID)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return end
    local logIndex = GetLogIndexForQuest(questID)
    if not logIndex then return end
    SelectLogQuest(questID, logIndex)
    if QuestLogPushQuest then
        pcall(QuestLogPushQuest, logIndex)
    end
end

local function ShowQuestOnWorldMap(questID)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return end
    SetQuestSuperTracked(questID)

    local mapID
    if GetQuestUiMapID then
        local ok, m = pcall(GetQuestUiMapID, questID)
        if ok and SafeNum(m) and m > 0 then mapID = m end
    end
    if not mapID and C_Map and C_Map.GetBestMapForUnit then
        local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and SafeNum(m) and m > 0 then mapID = m end
    end

    if InCombatLockdown and InCombatLockdown() then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Cannot open map in combat.", 1, 0.1, 0.1)
        end
        return
    end

    SetQuestLogCVarClosed()
    if C_Map and C_Map.OpenWorldMap then
        pcall(C_Map.OpenWorldMap, mapID)
    elseif ToggleWorldMap then
        if not (WorldMapFrame and WorldMapFrame:IsShown()) then
            pcall(ToggleWorldMap)
        end
    end
end



-- ============================================================
-- Export Helpers to FQL Namespace
-- ============================================================

FQL.IsSecret                  = IsSecret
FQL.SafeStr                   = SafeStr
FQL.SafeNum                   = SafeNum
FQL.CanChangeFrame            = CanChangeFrame
FQL.PlayOpenSound             = PlayOpenSound
FQL.PlayCloseSound            = PlayCloseSound
FQL.PlayClickSound            = PlayClickSound
FQL.SetBackdrop               = SetBackdrop
FQL.AddClassicParchment        = AddClassicParchment
FQL.FormatNumber              = FormatNumber

FQL.GetMaxQuests              = GetMaxQuests
FQL.ExpandAllNativeHeaders    = ExpandAllNativeHeaders
FQL.GetNumLogEntries          = GetNumLogEntries
FQL.GetLogEntryInfo           = GetLogEntryInfo
FQL.GetLogIndexForQuest       = GetLogIndexForQuest
FQL.SelectLogQuest            = SelectLogQuest
FQL.IsQuestCompleteOrFailed   = IsQuestCompleteOrFailed
FQL.IsQuestWatchedByID        = IsQuestWatchedByID
FQL.SetQuestWatchedByID       = SetQuestWatchedByID
FQL.ToggleQuestWatchByID      = ToggleQuestWatchByID
FQL.IsQuestSuperTracked       = IsQuestSuperTracked
FQL.SetQuestSuperTracked      = SetQuestSuperTracked
FQL.GetQuestTagDetails        = GetQuestTagDetails
FQL.GetDifficultyColor        = GetDifficultyColor
FQL.GetQuestTextAndObjectives = GetQuestTextAndObjectives
FQL.GetQuestRewardsData       = GetQuestRewardsData

FQL.TryInsertQuestChatLink    = TryInsertQuestChatLink
FQL.InsertOrOpenQuestChatLink = InsertOrOpenQuestChatLink
FQL.GetQuestWebURL            = GetQuestWebURL
FQL.AbandonSelectedQuest      = AbandonSelectedQuest
FQL.ShareSelectedQuest        = ShareSelectedQuest
FQL.ShowQuestOnWorldMap       = ShowQuestOnWorldMap
