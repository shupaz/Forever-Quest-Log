local ADDON_NAME, FQL = ...
if type(FQL) ~= "table" then
    FQL = {}
end
_G.shupaz_ForeverQuestLog = FQL

FQL.ADDON_NAME = ADDON_NAME or "shupaz_ForeverQuestLog"
FQL.VERSION = "1.0.0"

-- Keybinding label in Options > Keybindings > AddOns
BINDING_HEADER_SHUPAZ_FOREVERQUESTLOG = "shupaz ForeverQuestLog"
BINDING_NAME_SHUPAZ_FOREVERQUESTLOG_TOGGLE = "Toggle Quest Log"

local MIN_SCALE, MAX_SCALE = 0.6, 1.6
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 730, 520

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

local CHAR_DEFAULTS = {
    collapsedHeaders = {},
    collapsedTrackerZones = {},
    selectedQuestID = nil,
}

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
-- World Map Embedded Quest Log Removal & Redirection
-- ============================================================

local function SetQuestLogCVarClosed()
    if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.hideMapQuestLog == false then return end
    if C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
        if C_CVar.GetCVar("questLogOpen") ~= "0" then
            pcall(C_CVar.SetCVar, "questLogOpen", "0")
        end
    elseif GetCVar and SetCVar then
        if GetCVar("questLogOpen") ~= "0" then
            pcall(SetCVar, "questLogOpen", "0")
        end
    end
end

local function GetMapSidePanelToggle()
    if not WorldMapFrame then return nil end
    if WorldMapFrame.SidePanelToggle then return WorldMapFrame.SidePanelToggle end
    for _, frame in ipairs(WorldMapFrame.overlayFrames or {}) do
        if frame.OpenButton and frame.CloseButton then
            return frame
        end
    end
    return nil
end

local function SuppressMapQuestLog()
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.hideMapQuestLog == false then
        local toggle = GetMapSidePanelToggle()
        if toggle then
            toggle:SetAlpha(1)
            if CanChangeFrame(toggle) then
                if toggle.EnableMouse then toggle:EnableMouse(true) end
                toggle:Show()
            end
        end
        if _G.QuestLogCount then
            _G.QuestLogCount:SetAlpha(1)
            if CanChangeFrame(_G.QuestLogCount) then
                _G.QuestLogCount:Show()
            end
        end
        if _G.QuestMapFrame then
            _G.QuestMapFrame:SetAlpha(1)
        end
        return
    end
    SetQuestLogCVarClosed()

    local toggle = GetMapSidePanelToggle()
    if toggle then
        toggle:SetAlpha(0)
        if CanChangeFrame(toggle) then
            toggle:Hide()
            if toggle.EnableMouse then toggle:EnableMouse(false) end
        end
        if not toggle._fqlHooked then
            toggle._fqlHooked = true
            toggle:HookScript("OnShow", function(self)
                if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.hideMapQuestLog == false then return end
                self:SetAlpha(0)
                if CanChangeFrame(self) then
                    self:Hide()
                end
            end)
        end
    end

    if _G.QuestLogCount then
        _G.QuestLogCount:SetAlpha(0)
        if CanChangeFrame(_G.QuestLogCount) then
            _G.QuestLogCount:Hide()
        end
    end

    if _G.QuestMapFrame then
        _G.QuestMapFrame:SetAlpha(0)
        if not _G.QuestMapFrame._fqlHooked then
            _G.QuestMapFrame._fqlHooked = true
            _G.QuestMapFrame:HookScript("OnShow", function(self)
                if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.hideMapQuestLog == false then return end
                SetQuestLogCVarClosed()
                self:SetAlpha(0)
            end)
        end
    end
end

local function UpdateKeybindOverrides()
    if InCombatLockdown and InCombatLockdown() then
        FQL._needsBindingUpdate = true
        return
    end
    FQL._needsBindingUpdate = false
    if not FQL.bindingOwner then
        FQL.bindingOwner = CreateFrame("Frame", "shupaz_ForeverQuestLogBindingFrame", UIParent)
    end
    if ClearOverrideBindings then
        ClearOverrideBindings(FQL.bindingOwner)
    end
    if GetBindingKey and SetOverrideBinding then
        local key1, key2 = GetBindingKey("TOGGLEQUESTLOG")
        if key1 and key1 ~= "" then
            SetOverrideBinding(FQL.bindingOwner, false, key1, "FOREVERQUESTLOG_TOGGLE")
        end
        if key2 and key2 ~= "" then
            SetOverrideBinding(FQL.bindingOwner, false, key2, "FOREVERQUESTLOG_TOGGLE")
        end
    end
end

local function InitializeMicroMenuButtons()
    local buttonNames = {
        "CharacterMicroButton",
        "ProfessionMicroButton",
        "SpellbookMicroButton",
        "SpellBookMicroButton",
        "TalentMicroButton",
        "TalentsMicroButton",
        "PlayerSpellsMicroButton",
        "AchievementMicroButton",
        "QuestLogMicroButton",
        "GuildMicroButton",
        "LFDMicroButton",
        "LFGMicroButton",
        "CollectionsMicroButton",
        "EJMicroButton",
        "StoreMicroButton",
        "MainMenuMicroButton",
        "HelpMicroButton",
    }
    for _, name in ipairs(buttonNames) do
        local b = _G[name]
        if b and b.RegisterForClicks then
            b:RegisterForClicks("AnyDown")
        end
    end
    if _G.MicroMenu and _G.MicroMenu.GetChildren then
        for _, child in ipairs({ _G.MicroMenu:GetChildren() }) do
            if child and child.RegisterForClicks then
                child:RegisterForClicks("AnyDown")
            end
        end
    end
    if _G.MicroMenuContainer and _G.MicroMenuContainer.GetChildren then
        for _, child in ipairs({ _G.MicroMenuContainer:GetChildren() }) do
            if child and child.RegisterForClicks then
                child:RegisterForClicks("AnyDown")
            end
        end
    end
end

local function SetupMapAndBindingHooks()
    if FQL._hooksInstalled then return end
    FQL._hooksInstalled = true

    SuppressMapQuestLog()
    UpdateKeybindOverrides()
    InitializeMicroMenuButtons()

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            SuppressMapQuestLog()
        end)
    end

    -- Intercept ONLY QuestLogMicroButton clicks without tainting UpdateMicroButtons,
    -- WorldMapFrame, or UIParent's ShowUIPanel manager.
    if _G.QuestLogMicroButton and CanChangeFrame(_G.QuestLogMicroButton) then
        if _G.QuestLogMicroButton.RegisterForClicks then
            _G.QuestLogMicroButton:RegisterForClicks("AnyDown")
        end
        _G.QuestLogMicroButton:SetScript("OnClick", function(_, button)
            if button == "RightButton" then return end
            FQL:Toggle()
        end)
    end

    if _G.QuestMapFrame_OpenToQuestDetails then
        hooksecurefunc("QuestMapFrame_OpenToQuestDetails", function(questID)
            if questID and questID > 0 then
                if WorldMapFrame and WorldMapFrame:IsShown() and CanChangeFrame(WorldMapFrame) and HideUIPanel then
                    pcall(HideUIPanel, WorldMapFrame)
                end
                FQL:OpenToQuest(questID)
            end
        end)
    end

    if _G.QuestMapFrame_ShowQuestDetails then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(questID)
            if questID and questID > 0 then
                FQL:OpenToQuest(questID)
            end
        end)
    end
end

-- ============================================================
-- Link & Action Helpers
-- ============================================================

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
-- Copy Box Popup (for Wowhead Quest URL)
-- ============================================================

function FQL:ShowCopyPopup(titleText, urlText)
    local box = self.copyPopup
    if not box then
        box = CreateFrame("Frame", "shupaz_ForeverQuestLogCopyPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        self.copyPopup = box
        box:SetSize(420, 110)
        box:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        box:SetFrameStrata("FULLSCREEN_DIALOG")
        box:SetToplevel(true)
        box:EnableMouse(true)
        box:SetMovable(true)
        box:RegisterForDrag("LeftButton")
        box:SetScript("OnDragStart", box.StartMoving)
        box:SetScript("OnDragStop", box.StopMovingOrSizing)
        SetBackdrop(box, "Interface\\Buttons\\WHITE8X8", "Interface\\DialogFrame\\UI-DialogBox-Border", 24, 6)
        box:SetBackdropColor(0.06, 0.055, 0.048, 0.98)
        tinsert(UISpecialFrames, "shupaz_ForeverQuestLogCopyPopup")

        box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        box.title:SetPoint("TOP", 0, -14)
        box.title:SetTextColor(1, 0.82, 0)

        box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        box.hint:SetPoint("TOP", box.title, "BOTTOM", 0, -4)
        box.hint:SetText("Press Ctrl+C to copy:")
        box.hint:SetTextColor(0.75, 0.72, 0.65)

        local eb = CreateFrame("EditBox", nil, box, BackdropTemplateMixin and "BackdropTemplate" or nil)
        box.editBox = eb
        eb:SetSize(370, 26)
        eb:SetPoint("TOP", box.hint, "BOTTOM", 0, -8)
        eb:SetFontObject("ChatFontNormal")
        eb:SetAutoFocus(true)
        eb:SetTextInsets(8, 8, 0, 0)
        SetBackdrop(eb, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
        eb:SetBackdropColor(0.12, 0.11, 0.09, 1)
        eb:SetBackdropBorderColor(0.55, 0.45, 0.25, 1)
        eb:SetScript("OnEscapePressed", function() box:Hide() end)
        eb:SetScript("OnEnterPressed", function() box:Hide() end)

        local close = CreateFrame("Button", nil, box, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end

    box.title:SetText(titleText or "Quest Link")
    box.editBox:SetText(urlText or "")
    box:Show()
    box.editBox:SetFocus()
    box.editBox:HighlightText()
end

-- ============================================================
-- Context Menu for Quest Rows
-- ============================================================

function FQL:ShowQuestContextMenu(anchorButton, questEntry)
    if not questEntry or not questEntry.questID then return end
    local menu = self.contextMenu
    if not menu then
        menu = CreateFrame("Frame", "shupaz_ForeverQuestLogContextMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        self.contextMenu = menu
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

    local questID = questEntry.questID
    local logIndex = questEntry.logIndex
    local watched = IsQuestWatchedByID(questID, logIndex)
    local superTracked = IsQuestSuperTracked(questID)
    local canShare = (C_QuestLog and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(questID)) and (IsInGroup and IsInGroup())

    local actions = {
        {
            label = watched and "Untrack Quest" or "Track Quest",
            fn = function()
                ToggleQuestWatchByID(questID, logIndex)
                FQL:Refresh()
            end,
        },
        {
            label = superTracked and "Super-Tracked (Active)" or "Set as Active Waypoint",
            fn = function()
                SetQuestSuperTracked(questID)
                FQL:Refresh()
            end,
        },
        {
            label = "Show on World Map",
            fn = function()
                ShowQuestOnWorldMap(questID)
            end,
        },
        {
            label = "Share Quest with Party",
            disabled = not canShare,
            fn = function()
                ShareSelectedQuest(questID)
            end,
        },
        {
            label = "Wowhead Quest Link",
            fn = function()
                FQL:ShowCopyPopup(questEntry.title, "https://www.wowhead.com/classic/quest=" .. tostring(questID))
            end,
        },
        {
            label = "|cffff4444Abandon Quest|r",
            fn = function()
                AbandonSelectedQuest(questID, questEntry.title)
            end,
        },
    }

    local maxWidth = 150
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
        if act.disabled then
            row.text:SetTextColor(0.45, 0.45, 0.45)
            row:SetScript("OnClick", nil)
        else
            row.text:SetTextColor(0.95, 0.88, 0.72)
            row:SetScript("OnClick", function()
                PlayClickSound()
                menu:Hide()
                act.fn()
            end)
        end
        local w = (row.text:GetStringWidth() or 120) + 26
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
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 4, (y / scale) - 4)
    menu:Show()
end

-- ============================================================
-- Main Standalone Dual-Pane Window Creation
-- ============================================================

local function MakeRewardButton(parent)
    local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(166, 40)
    SetBackdrop(btn, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    btn:SetBackdropColor(0.18, 0.13, 0.08, 0.92)
    btn:SetBackdropBorderColor(0.45, 0.34, 0.18, 0.95)
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.iconBorder = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn.iconBorder:SetSize(34, 34)
    btn.iconBorder:SetPoint("LEFT", 3, 0)
    SetBackdrop(btn.iconBorder, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 8, 1)
    btn.iconBorder:SetBackdropColor(0, 0, 0, 1)
    btn.iconBorder:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)

    btn.icon = btn.iconBorder:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.count = btn.iconBorder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.count:SetJustifyH("RIGHT")

    btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.name:SetPoint("TOPLEFT", btn.iconBorder, "TOPRIGHT", 6, -2)
    btn.name:SetPoint("BOTTOMRIGHT", -6, 2)
    btn.name:SetJustifyH("LEFT")
    btn.name:SetJustifyV("MIDDLE")
    if btn.name.SetWordWrap then btn.name:SetWordWrap(true) end

    btn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.spellID then
            if GameTooltip.SetSpellByID then
                pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
            end
        elseif self.questID and self.rewardType and self.rewardIndex then
            SelectLogQuest(self.questID, self.logIndex)
            local ok = false
            if GameTooltip.SetQuestLogItem then
                ok = pcall(GameTooltip.SetQuestLogItem, GameTooltip, self.rewardType, self.rewardIndex, self.questID)
            end
            if not ok and self.itemID and GameTooltip.SetItemByID then
                pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
            end
        elseif self.itemID and GameTooltip.SetItemByID then
            pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
        end
        GameTooltip:Show()
        if IsModifiedClick and IsModifiedClick("COMPAREITEMS") and GameTooltip_ShowCompareItem then
            pcall(GameTooltip_ShowCompareItem, GameTooltip)
        end
    end)

    btn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    btn:SetScript("OnClick", function(self)
        if self.itemID then
            local _, itemLink = C_Item.GetItemInfo(self.itemID)
            if not itemLink and GetQuestLogItemLink and self.rewardType and self.rewardIndex then
                SelectLogQuest(self.questID, self.logIndex)
                local ok, l = pcall(GetQuestLogItemLink, self.rewardType, self.rewardIndex)
                if ok and SafeStr(l) then itemLink = l end
            end
            if itemLink then
                if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                    ChatEdit_InsertLink(itemLink)
                elseif IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then
                    DressUpItemLink(itemLink)
                end
            end
        end
    end)

    return btn
end

function FQL:SetScale(scale)
    if not self.frame then return end
    scale = tonumber(scale) or 1.0
    if scale < MIN_SCALE then scale = MIN_SCALE end
    if scale > MAX_SCALE then scale = MAX_SCALE end
    scale = math.floor(scale * 100 + 0.5) / 100
    shupazForeverQuestLogDB.scale = scale
    self.frame:SetScale(scale)
    if self.optionsPanel and self.optionsPanel.RefreshControls then
        self.optionsPanel:RefreshControls()
    end
end

function FQL:SavePosition()
    if not self.frame then return end
    local point, _, relPoint, x, y = self.frame:GetPoint(1)
    if point and not IsSecret(x) and not IsSecret(y) then
        shupazForeverQuestLogDB.useDefaultPosition = false
        shupazForeverQuestLogDB.pos = {
            point = point,
            relPoint = relPoint or point,
            x = x,
            y = y,
        }
    end
end

-- Respect the position of default Blizzard windows (CharacterFrame, SpellBookFrame,
-- ProfessionsFrame, PlayerSpellsFrame, FriendsFrame, PVEFrame, etc.):
-- Sits at the standard UIPanel left anchor (TOPLEFT, UIParent, TOPLEFT, 16, -116),
-- and pushes to the right side-by-side when a narrow left default window is open.
local DEFAULT_LEFT_PANELS = {
    "CharacterFrame",
    "SpellBookFrame",
    "FriendsFrame",
    "PVEFrame",
    "DressUpFrame",
    "GossipFrame",
    "QuestFrame",
    "MerchantFrame",
    "MailFrame",
    "BankFrame",
    "TradeFrame",
    "GuildRegistrarFrame",
    "TabardFrame",
}

function FQL:UpdateDefaultPanelPosition()
    if not self.frame then return end
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.useDefaultPosition == false then
        return
    end

    local xOff = 16
    local yOff = -116

    for _, frameName in ipairs(DEFAULT_LEFT_PANELS) do
        local f = _G[frameName]
        if f and f.IsShown and f:IsShown() then
            local okR, right = pcall(f.GetRight, f)
            local okW, width = pcall(f.GetWidth, f)
            local rNum = okR and SafeNum(right) or nil
            local wNum = okW and SafeNum(width) or nil
            if rNum and rNum > 0 and (not wNum or wNum < 650) then
                local fScale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
                local myScale = (self.frame.GetEffectiveScale and self.frame:GetEffectiveScale()) or 1
                local normalizedRight = (rNum * fScale) / (myScale > 0 and myScale or 1)
                if normalizedRight + 12 > xOff then
                    xOff = math.floor(normalizedRight + 12)
                end
            end
        end
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOff, yOff)
end

function FQL:SetupDefaultPanelHooks()
    if self._defaultPanelHooksInstalled then return end
    self._defaultPanelHooksInstalled = true

    if type(_G.UpdateUIPanelPositions) == "function" then
        hooksecurefunc("UpdateUIPanelPositions", function()
            if FQL.frame and FQL.frame:IsShown() then
                FQL:UpdateDefaultPanelPosition()
            end
        end)
    end

    for _, frameName in ipairs(DEFAULT_LEFT_PANELS) do
        local f = _G[frameName]
        if f and f.HookScript and not f._fqlPosHooked then
            f._fqlPosHooked = true
            f:HookScript("OnShow", function()
                if FQL.frame and FQL.frame:IsShown() then
                    FQL:UpdateDefaultPanelPosition()
                end
            end)
            f:HookScript("OnHide", function()
                if FQL.frame and FQL.frame:IsShown() then
                    FQL:UpdateDefaultPanelPosition()
                end
            end)
        end
    end
end

function FQL:RestorePosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    local useDefault = not shupazForeverQuestLogDB or (shupazForeverQuestLogDB.useDefaultPosition ~= false)
    local pos = shupazForeverQuestLogDB and shupazForeverQuestLogDB.pos
    if not useDefault and type(pos) == "table" and pos.point and type(pos.x) == "number" and type(pos.y) == "number" then
        self.frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    else
        self:UpdateDefaultPanelPosition()
    end
end

function FQL:CreateMainFrame()
    if self.frame then return self.frame end

    -- Use ButtonFrameTemplate / PortraitFrameTemplate so ForeverQuestLogFrame shares
    -- the exact Blizzard frame appearance of Professions / Character Info / Spellbook
    -- (top-left round portrait badge, gold title bar, stone background, bronze NineSlice border).
    local okTemplate, frame = pcall(CreateFrame, "Frame", "shupaz_ForeverQuestLogFrame", UIParent, "ButtonFrameTemplate")
    if not okTemplate or not frame then
        okTemplate, frame = pcall(CreateFrame, "Frame", "shupaz_ForeverQuestLogFrame", UIParent, "PortraitFrameTemplate")
    end
    if not okTemplate or not frame then
        frame = CreateFrame("Frame", "shupaz_ForeverQuestLogFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    end

    self.frame = frame
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    tinsert(UISpecialFrames, "shupaz_ForeverQuestLogFrame")

    -- Hide default single Inset from ButtonFrameTemplate (we render dual Left & Right insets)
    if frame.Inset then
        frame.Inset:Hide()
    end

    -- Ensure PortraitContainer, TitleContainer, and CloseButton sit above NineSlice
    if frame.NineSlice then
        local nsLevel = frame.NineSlice:GetFrameLevel() or 2
        if frame.PortraitContainer then
            frame.PortraitContainer:SetFrameLevel(nsLevel + 2)
        end
        if frame.TitleContainer then
            frame.TitleContainer:SetFrameLevel(nsLevel + 2)
        end
        if frame.CloseButton then
            frame.CloseButton:SetFrameLevel(nsLevel + 3)
        end
    else
        SetBackdrop(
            frame,
            "Interface\\FrameGeneral\\UI-Background-Rock",
            "Interface\\DialogFrame\\UI-DialogBox-Border",
            24,
            6
        )
        frame:SetBackdropColor(0.05, 0.045, 0.04, 0.98)
    end

    -- Configure Top-Left Circular Portrait Badge (like Professions / Character Info / Spellbook)
    local portraitIcon = "Interface\\QuestFrame\\UI-QuestLog-BookIcon"
    if frame.SetPortraitToAsset then
        pcall(frame.SetPortraitToAsset, frame, portraitIcon)
    elseif ButtonFrameTemplate_SetPortraitToAsset then
        pcall(ButtonFrameTemplate_SetPortraitToAsset, frame, portraitIcon)
    end
    local portraitTex = (frame.PortraitContainer and frame.PortraitContainer.portrait) or frame.portrait or _G["ForeverQuestLogFramePortrait"]
    if portraitTex then
        if SetPortraitToTexture then
            pcall(SetPortraitToTexture, portraitTex, portraitIcon)
        else
            portraitTex:SetTexture(portraitIcon)
        end
    end

    -- Configure Window Title Text
    local titleStr = QUEST_LOG or "Quest Log"
    if frame.SetTitle then
        pcall(frame.SetTitle, frame, titleStr)
    elseif frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(titleStr)
    elseif frame.TitleText then
        frame.TitleText:SetText(titleStr)
    else
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", frame, "TOP", 0, -6)
        title:SetText(titleStr)
        frame.titleText = title
    end

    -- Close Button (use native template CloseButton if present)
    if frame.CloseButton then
        frame.closeButton = frame.CloseButton
    else
        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        frame.closeButton = closeBtn
    end

    frame:SetScript("OnDragStart", function(self)
        if shupazForeverQuestLogDB and shupazForeverQuestLogDB.lockWindow then return end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        FQL:SavePosition()
    end)

    frame:SetScript("OnShow", function()
        PlayOpenSound()
        FQL:SetupDefaultPanelHooks()
        if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.useDefaultPosition ~= false then
            FQL:UpdateDefaultPanelPosition()
        end
        FQL:Refresh()
    end)
    frame:SetScript("OnHide", function()
        PlayCloseSound()
        if FQL.contextMenu then FQL.contextMenu:Hide() end
    end)

    -- ========================================================
    -- TOP TOOLBAR (In Portrait Frame Sub-Header Band, y = -30)
    -- ========================================================
    -- Collapse / Expand All Zones Button (to the right of the circular Portrait badge)
    local collapseAllBtn = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.collapseAllBtn = collapseAllBtn
    collapseAllBtn:SetSize(24, 22)
    collapseAllBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 62, -31)
    SetBackdrop(collapseAllBtn, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    collapseAllBtn:SetBackdropColor(0.14, 0.11, 0.07, 0.98)
    collapseAllBtn:SetBackdropBorderColor(0.48, 0.38, 0.22, 1)
    collapseAllBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    collapseAllBtn.icon = collapseAllBtn:CreateTexture(nil, "ARTWORK")
    collapseAllBtn.icon:SetSize(14, 14)
    collapseAllBtn.icon:SetPoint("CENTER", 0, 0)
    collapseAllBtn.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")

    collapseAllBtn:SetScript("OnClick", function()
        PlayClickSound()
        FQL:ToggleAllHeaders()
    end)
    collapseAllBtn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Collapse / Expand All Zones", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    collapseAllBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Search Box in Top Toolbar (aligned with Left Pane width)
    local searchBox = CreateFrame("EditBox", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.searchBox = searchBox
    searchBox:SetPoint("TOPLEFT", collapseAllBtn, "TOPRIGHT", 4, 0)
    searchBox:SetSize(233, 22)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetTextInsets(22, 20, 0, 0)
    SetBackdrop(searchBox, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    searchBox:SetBackdropColor(0.06, 0.05, 0.04, 0.96)
    searchBox:SetBackdropBorderColor(0.45, 0.35, 0.20, 1)

    local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(13, 13)
    searchIcon:SetPoint("LEFT", 6, -1)
    searchIcon:SetAtlas("common-search-magnifyingglass")
    if not searchIcon:GetTexture() then
        searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    end
    searchIcon:SetVertexColor(0.7, 0.65, 0.55)

    local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", 22, 0)
    searchPlaceholder:SetText(SEARCH or "Search quests...")
    searchPlaceholder:SetTextColor(0.55, 0.50, 0.42)

    local clearSearchBtn = CreateFrame("Button", nil, searchBox)
    clearSearchBtn:SetSize(16, 16)
    clearSearchBtn:SetPoint("RIGHT", -4, 0)
    clearSearchBtn.tex = clearSearchBtn:CreateTexture(nil, "ARTWORK")
    clearSearchBtn.tex:SetAllPoints()
    clearSearchBtn.tex:SetTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    clearSearchBtn.tex:SetAlpha(0.7)
    clearSearchBtn:Hide()
    clearSearchBtn:SetScript("OnEnter", function(self) self.tex:SetAlpha(1.0) end)
    clearSearchBtn:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.7) end)
    clearSearchBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        FQL.searchFilter = txt:lower():gsub("^%s+", ""):gsub("%s+$", "")
        searchPlaceholder:SetShown(txt == "" and not self:HasFocus())
        clearSearchBtn:SetShown(txt ~= "")
        FQL:RefreshQuestList()
    end)
    searchBox:SetScript("OnEditFocusGained", function(self)
        searchPlaceholder:Hide()
        self:SetBackdropBorderColor(0.82, 0.65, 0.25, 1)
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        local txt = self:GetText() or ""
        searchPlaceholder:SetShown(txt == "")
        self:SetBackdropBorderColor(0.45, 0.35, 0.20, 1)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    -- Quest Count Pill on the right of Top Toolbar (e.g., Quests: 12/25)
    local countBox = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.countBox = countBox
    countBox:SetSize(116, 22)
    countBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -31)
    SetBackdrop(countBox, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    countBox:SetBackdropColor(0.08, 0.06, 0.04, 0.95)
    countBox:SetBackdropBorderColor(0.50, 0.38, 0.20, 0.9)

    local countText = countBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.countText = countText
    countText:SetPoint("CENTER", 0, 0)
    countText:SetText("Quests: 0/25")

    -- Settings (Gear) Button next to Quest Count Pill
    local settingsBtn = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.settingsBtn = settingsBtn
    settingsBtn:SetSize(22, 22)
    settingsBtn:SetPoint("RIGHT", countBox, "LEFT", -6, 0)
    SetBackdrop(settingsBtn, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    settingsBtn:SetBackdropColor(0.08, 0.06, 0.04, 0.95)
    settingsBtn:SetBackdropBorderColor(0.50, 0.38, 0.20, 0.9)
    settingsBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    settingsBtn.icon = settingsBtn:CreateTexture(nil, "ARTWORK")
    settingsBtn.icon:SetSize(14, 14)
    settingsBtn.icon:SetPoint("CENTER", 0, 0)
    settingsBtn.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")

    settingsBtn:SetScript("OnClick", function()
        PlayClickSound()
        FQL:OpenOptions()
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Forever Quest Log Settings", 1, 0.82, 0)
        GameTooltip:AddLine("Click to open Options > AddOns > Forever Quest Log.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- ========================================================
    -- LEFT PANE: Quest List
    -- ========================================================
    local leftPane = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.leftPane = leftPane
    leftPane:SetPoint("TOPLEFT", 8, -60)
    leftPane:SetPoint("BOTTOMLEFT", 8, 30)
    leftPane:SetWidth(315)
    SetBackdrop(leftPane, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    leftPane:SetBackdropColor(0.09, 0.075, 0.055, 0.96)
    leftPane:SetBackdropBorderColor(0.47, 0.35, 0.18, 1)
    AddClassicParchment(leftPane, 0.11, 1.00, 0.94, 0.82)

    -- Left ScrollFrame
    local listScroll = CreateFrame("ScrollFrame", "shupaz_ForeverQuestLogListScroll", leftPane, "UIPanelScrollFrameTemplate")
    frame.listScroll = listScroll
    listScroll:SetPoint("TOPLEFT", 6, -6)
    listScroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local listContent = CreateFrame("Frame", nil, listScroll)
    frame.listContent = listContent
    listContent:SetSize(280, 1)
    listScroll:SetScrollChild(listContent)
    frame.listRows = {}

    -- Empty Log Message on Left Pane
    local emptyListText = leftPane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.emptyListText = emptyListText
    emptyListText:SetPoint("CENTER", leftPane, "CENTER", 0, 0)
    emptyListText:SetText("No active quests in your log.")
    emptyListText:Hide()

    -- ========================================================
    -- RIGHT PANE: Classic Parchment Quest Details
    -- ========================================================
    local rightPane = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.rightPane = rightPane
    rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 6, 0)
    rightPane:SetPoint("BOTTOMRIGHT", -8, 30)
    SetBackdrop(rightPane, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    rightPane:SetBackdropColor(0.14, 0.10, 0.06, 0.96)
    rightPane:SetBackdropBorderColor(0.47, 0.35, 0.18, 1)

    local parchmentInset = CreateFrame("Frame", nil, rightPane, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.parchmentInset = parchmentInset
    parchmentInset:SetPoint("TOPLEFT", 6, -6)
    parchmentInset:SetPoint("BOTTOMRIGHT", -6, 6)
    SetBackdrop(parchmentInset, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 3)
    parchmentInset:SetBackdropColor(0.74, 0.62, 0.43, 1)
    parchmentInset:SetBackdropBorderColor(0.36, 0.23, 0.09, 1)

    local parchmentTex = parchmentInset:CreateTexture(nil, "BACKGROUND", nil, -2)
    parchmentTex:SetPoint("TOPLEFT", 3, -3)
    parchmentTex:SetPoint("BOTTOMRIGHT", -3, 3)
    parchmentTex:SetTexture("Interface\\QuestFrame\\QuestBG")
    parchmentTex:SetTexCoord(0, 0.585, 0, 0.65)
    parchmentTex:SetVertexColor(1.00, 0.96, 0.85, 1.00)

    local detailScroll = CreateFrame("ScrollFrame", "shupaz_ForeverQuestLogDetailScroll", parchmentInset, "UIPanelScrollFrameTemplate")
    frame.detailScroll = detailScroll
    detailScroll:SetPoint("TOPLEFT", 12, -10)
    detailScroll:SetPoint("BOTTOMRIGHT", -28, 10)

    local detailContent = CreateFrame("Frame", nil, detailScroll)
    frame.detailContent = detailContent
    detailContent:SetSize(330, 1)
    detailScroll:SetScrollChild(detailContent)

    -- Detail Elements inside detailContent
    local dTitle = detailContent:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    frame.detailTitle = dTitle
    dTitle:SetPoint("TOPLEFT", 0, 0)
    dTitle:SetWidth(330)
    dTitle:SetJustifyH("LEFT")
    dTitle:SetTextColor(0.14, 0.08, 0.02)

    local dMeta = detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.detailMeta = dMeta
    dMeta:SetJustifyH("LEFT")
    dMeta:SetTextColor(0.32, 0.20, 0.08)

    local dSep = detailContent:CreateTexture(nil, "ARTWORK")
    frame.detailSep = dSep
    dSep:SetTexture("Interface\\Buttons\\WHITE8X8")
    dSep:SetHeight(1)
    dSep:SetColorTexture(0.45, 0.32, 0.16, 0.55)

    -- Special Quest Item button (top-right of objectives when present)
    local specialItemBtn = CreateFrame("Button", "shupaz_ForeverQuestLogSpecialItemBtn", detailContent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.specialItemBtn = specialItemBtn
    specialItemBtn:SetSize(36, 36)
    SetBackdrop(specialItemBtn, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    specialItemBtn:SetBackdropColor(0.1, 0.08, 0.05, 0.95)
    specialItemBtn:SetBackdropBorderColor(0.65, 0.50, 0.20, 1)
    specialItemBtn.icon = specialItemBtn:CreateTexture(nil, "ARTWORK")
    specialItemBtn.icon:SetPoint("TOPLEFT", 3, -3)
    specialItemBtn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    specialItemBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    specialItemBtn:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.logIndex then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
        end
        GameTooltip:Show()
    end)
    specialItemBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    specialItemBtn:SetScript("OnClick", function(self)
        if self.itemLink and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(self.itemLink)
        end
    end)
    specialItemBtn:Hide()

    local dObjSummary = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailObjSummary = dObjSummary
    dObjSummary:SetJustifyH("LEFT")
    dObjSummary:SetTextColor(0.12, 0.07, 0.02)

    local dObjLines = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailObjLines = dObjLines
    dObjLines:SetJustifyH("LEFT")
    dObjLines:SetSpacing(3)
    dObjLines:SetTextColor(0.10, 0.06, 0.02)

    local dDescHeader = detailContent:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    frame.detailDescHeader = dDescHeader
    dDescHeader:SetJustifyH("LEFT")
    dDescHeader:SetText(QUEST_DESCRIPTION or "Description")
    dDescHeader:SetTextColor(0.14, 0.08, 0.02)

    local dDescText = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailDescText = dDescText
    dDescText:SetJustifyH("LEFT")
    dDescText:SetTextColor(0.12, 0.07, 0.02)

    local dRewardsHeader = detailContent:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    frame.detailRewardsHeader = dRewardsHeader
    dRewardsHeader:SetJustifyH("LEFT")
    dRewardsHeader:SetText(QUEST_REWARDS or "Rewards")
    dRewardsHeader:SetTextColor(0.14, 0.08, 0.02)

    local dChoiceLabel = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailChoiceLabel = dChoiceLabel
    dChoiceLabel:SetJustifyH("LEFT")
    dChoiceLabel:SetText(REWARD_CHOICES or "You will be able to choose one of these rewards:")
    dChoiceLabel:SetTextColor(0.14, 0.08, 0.02)

    local dFixedLabel = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailFixedLabel = dFixedLabel
    dFixedLabel:SetJustifyH("LEFT")
    dFixedLabel:SetText(REWARD_ITEMS_ONLY or "You will receive:")
    dFixedLabel:SetTextColor(0.14, 0.08, 0.02)

    local dSpellLabel = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailSpellLabel = dSpellLabel
    dSpellLabel:SetJustifyH("LEFT")
    dSpellLabel:SetText(REWARD_AURA or "The following spell will be cast on you:")
    dSpellLabel:SetTextColor(0.14, 0.08, 0.02)

    local dXPLine = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailXPLine = dXPLine
    dXPLine:SetJustifyH("LEFT")
    dXPLine:SetTextColor(0.12, 0.07, 0.02)

    local dMoneyLine = detailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
    frame.detailMoneyLine = dMoneyLine
    dMoneyLine:SetJustifyH("LEFT")
    dMoneyLine:SetTextColor(0.12, 0.07, 0.02)

    frame.rewardButtons = {}

    local noSelectionText = parchmentInset:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    frame.noSelectionText = noSelectionText
    noSelectionText:SetPoint("CENTER", parchmentInset, "CENTER", 0, 0)
    noSelectionText:SetText("Select a quest to view its details")
    noSelectionText:SetTextColor(0.35, 0.24, 0.12)
    noSelectionText:Hide()

    -- ========================================================
    -- BOTTOM ACTION BAR
    -- ========================================================
    local function CreateBottomButton(label, width, anchor, relPoint, xOff, yOff, onClick, tooltipTitle, tooltipBody)
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(width, 22)
        btn:SetPoint("BOTTOMLEFT", anchor, relPoint, xOff, yOff)
        btn:SetText(label)
        btn:SetScript("OnClick", function(self)
            PlayClickSound()
            if onClick then onClick(self) end
        end)
        if tooltipTitle then
            btn:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(tooltipTitle, 1, 0.82, 0)
                if tooltipBody then
                    GameTooltip:AddLine(tooltipBody, 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                if GameTooltip then GameTooltip:Hide() end
            end)
        end
        return btn
    end

    frame.abandonBtn = CreateBottomButton(
        ABANDON_QUEST_ABBREV or "Abandon",
        96,
        frame, "BOTTOMLEFT", 8, 5,
        function()
            if FQL.selectedQuestID then
                AbandonSelectedQuest(FQL.selectedQuestID, FQL.selectedQuestTitle)
            end
        end,
        ABANDON_QUEST or "Abandon Quest",
        "Abandon the selected quest."
    )

    frame.shareBtn = CreateBottomButton(
        SHARE_QUEST_ABBREV or "Push Quest",
        96,
        frame.abandonBtn, "BOTTOMRIGHT", 5, 0,
        function()
            if FQL.selectedQuestID then
                ShareSelectedQuest(FQL.selectedQuestID)
            end
        end,
        SHARE_QUEST or "Share Quest",
        "Share the selected quest with your party members."
    )

    frame.trackBtn = CreateBottomButton(
        TRACK_QUEST_ABBREV or "Track",
        96,
        frame.shareBtn, "BOTTOMRIGHT", 5, 0,
        function()
            if FQL.selectedQuestID then
                local logIndex = GetLogIndexForQuest(FQL.selectedQuestID)
                ToggleQuestWatchByID(FQL.selectedQuestID, logIndex)
                FQL:Refresh()
            end
        end,
        TRACK_QUEST or "Track Quest",
        "Toggle tracking this quest in the Objective Tracker.\n(Tip: Shift-Click any quest in the list to toggle tracking or link in chat.)"
    )

    frame.trackAllBtn = CreateBottomButton(
        "Track All",
        104,
        frame.trackBtn, "BOTTOMRIGHT", 5, 0,
        function()
            FQL:ToggleTrackAllQuests()
        end,
        "Track / Untrack All Quests",
        "Track all quests in your Quest Log, or untrack all quests if any quests are currently tracked."
    )

    frame.mapBtn = CreateBottomButton(
        "Show Map",
        96,
        frame.trackAllBtn, "BOTTOMRIGHT", 5, 0,
        function()
            if FQL.selectedQuestID then
                ShowQuestOnWorldMap(FQL.selectedQuestID)
            end
        end,
        "Show on World Map",
        "Open the World Map to the selected quest's zone and set it as your active waypoint."
    )

    frame.exitBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.exitBtn:SetSize(84, 22)
    frame.exitBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 5)
    frame.exitBtn:SetText(EXIT or CLOSE or "Close")
    frame.exitBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Bottom-Right Scale Grip (drag to scale 0.6x-1.6x, right-click to reset)
    local grip = CreateFrame("Button", nil, frame)
    frame.resizeGrip = grip
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local x = GetCursorPosition()
        self.startX = x
        self.startScale = frame:GetScale() or 1
        self.unit = (frame:GetWidth() or DEFAULT_WIDTH) * (UIParent:GetEffectiveScale() or 1)
        self.dragging = true
    end)
    grip:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            FQL:SetScale(1.0)
        end
        if self.dragging then
            self.dragging = false
            FQL:SetScale(frame:GetScale() or 1)
        end
    end)
    grip:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            self.dragging = false
            FQL:SetScale(frame:GetScale() or 1)
            return
        end
        local x = GetCursorPosition()
        local newScale = self.startScale + 2 * (x - self.startX) / self.unit
        if newScale < MIN_SCALE then newScale = MIN_SCALE end
        if newScale > MAX_SCALE then newScale = MAX_SCALE end
        frame:SetScale(newScale)
    end)
    grip:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Resize Quest Log", 1, 0.82, 0.27)
        GameTooltip:AddLine("Drag to resize.\nRight-click to reset to 100%.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    self:SetupDefaultPanelHooks()
    self:RestorePosition()
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.scale then
        self:SetScale(shupazForeverQuestLogDB.scale)
    end

    -- Optional BlizzMove registration if user uses BlizzMove
    if _G.BlizzMoveAPI and _G.BlizzMoveAPI.RegisterFrames then
        pcall(function()
            _G.BlizzMoveAPI:RegisterFrames({
                ["shupaz_ForeverQuestLogFrame"] = {
                    Versions = { [_G.BlizzMoveAPI.Versions.Fallback] = true },
                },
            })
        end)
    end

    return frame
end

-- ============================================================
-- Quest List & Detail Rendering
-- ============================================================

local function AcquireListRow(frame, index)
    local row = frame.listRows[index]
    if row then return row end

    row = CreateFrame("Button", nil, frame.listContent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    row:SetHeight(22)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bg:Hide()

    row.collapseIcon = row:CreateTexture(nil, "ARTWORK")
    row.collapseIcon:SetSize(14, 14)
    row.collapseIcon:SetPoint("LEFT", 4, 0)

    row.trackCheck = row:CreateTexture(nil, "OVERLAY")
    row.trackCheck:SetSize(14, 14)
    row.trackCheck:SetPoint("RIGHT", -4, 0)
    row.trackCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.statusText:SetPoint("RIGHT", row.trackCheck, "LEFT", -2, 0)
    row.statusText:SetJustifyH("RIGHT")

    row.titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.titleText:SetPoint("LEFT", 20, 0)
    row.titleText:SetPoint("RIGHT", row.statusText, "LEFT", -4, 0)
    row.titleText:SetJustifyH("LEFT")
    row.titleText:SetWordWrap(false)

    row:SetScript("OnClick", function(self, button)
        if self.isHeader then
            PlayClickSound()
            local hKey = self.headerTitle
            if hKey and shupazForeverQuestLogCharDB and shupazForeverQuestLogCharDB.collapsedHeaders then
                shupazForeverQuestLogCharDB.collapsedHeaders[hKey] = not shupazForeverQuestLogCharDB.collapsedHeaders[hKey] or nil
                FQL:RefreshQuestList()
            end
            return
        end

        local qEntry = self.questEntry
        if not qEntry or not qEntry.questID then return end

        if button == "RightButton" then
            FQL:SelectQuest(qEntry.questID, qEntry.logIndex)
            FQL:ShowQuestContextMenu(self, qEntry)
            return
        end

        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            if TryInsertQuestChatLink(qEntry.questID, qEntry.title, qEntry.level) then
                return
            end
            PlayClickSound()
            ToggleQuestWatchByID(qEntry.questID, qEntry.logIndex)
            FQL:Refresh()
            return
        end

        if IsControlKeyDown and IsControlKeyDown() then
            PlayClickSound()
            SetQuestSuperTracked(qEntry.questID)
            FQL:SelectQuest(qEntry.questID, qEntry.logIndex)
            return
        end

        PlayClickSound()
        FQL:SelectQuest(qEntry.questID, qEntry.logIndex)
    end)

    row:SetScript("OnDoubleClick", function(self, button)
        if button == "LeftButton" and not self.isHeader and self.questEntry and self.questEntry.questID then
            SetQuestSuperTracked(self.questEntry.questID)
            FQL:Refresh()
        end
    end)

    row:SetScript("OnEnter", function(self)
        if self.isHeader or not self.questEntry or not GameTooltip then return end
        if shupazForeverQuestLogDB and shupazForeverQuestLogDB.showTooltips == false then return end
        local q = self.questEntry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local r, g, b = GetDifficultyColor(q.level)
        GameTooltip:SetText(q.title, r, g, b)
        local tagStr = q.tagName and (" (" .. q.tagName .. ")") or ""
        GameTooltip:AddLine("Level " .. tostring(q.level or "?") .. tagStr .. (q.headerTitle and (" - " .. q.headerTitle) or ""), 0.85, 0.82, 0.72)

        local _, _, objs = GetQuestTextAndObjectives(q.questID, q.logIndex)
        if #objs > 0 then
            GameTooltip:AddLine(" ")
            for _, o in ipairs(objs) do
                if o.finished then
                    GameTooltip:AddLine("• " .. o.text, 0.45, 0.85, 0.45, true)
                else
                    GameTooltip:AddLine("• " .. o.text, 0.92, 0.92, 0.92, true)
                end
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: View Details | Shift-Click: Track / Link | Right-Click: Menu", 0.55, 0.55, 0.55, true)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    frame.listRows[index] = row
    return row
end

function FQL:BuildStructuredLog()
    ExpandAllNativeHeaders()
    local numShown, numQuests = GetNumLogEntries()
    local sections = {}
    local currentSection = nil
    local allQuestsByID = {}
    local firstQuestID = nil
    local countedQuests = 0

    for i = 1, numShown do
        local info = GetLogEntryInfo(i)
        if info and not info.isHidden and not info.isBounty and not info.isTask then
            if info.isHeader then
                currentSection = {
                    title = info.title,
                    logIndex = i,
                    quests = {},
                }
                sections[#sections + 1] = currentSection
            elseif info.questID and info.questID > 0 then
                if not currentSection then
                    currentSection = {
                        title = "Quests",
                        logIndex = 0,
                        quests = {},
                    }
                    sections[#sections + 1] = currentSection
                end
                info.headerTitle = currentSection.title
                info.completeState = IsQuestCompleteOrFailed(info.questID, info.isComplete)
                info.tagName, info.tagAbbr = GetQuestTagDetails(info.questID, info)
                currentSection.quests[#currentSection.quests + 1] = info
                allQuestsByID[info.questID] = info
                countedQuests = countedQuests + 1
                if not firstQuestID then
                    firstQuestID = info.questID
                end
            end
        end
    end

    if numQuests == 0 and countedQuests > 0 then
        numQuests = countedQuests
    end

    return sections, allQuestsByID, firstQuestID, numQuests
end

function FQL:ToggleAllHeaders()
    local sections = self:BuildStructuredLog()
    shupazForeverQuestLogCharDB.collapsedHeaders = shupazForeverQuestLogCharDB.collapsedHeaders or {}
    local collapsed = shupazForeverQuestLogCharDB.collapsedHeaders

    local anyExpanded = false
    for _, sec in ipairs(sections) do
        if #sec.quests > 0 and not collapsed[sec.title] then
            anyExpanded = true
            break
        end
    end

    if anyExpanded then
        for _, sec in ipairs(sections) do
            collapsed[sec.title] = true
        end
    else
        wipe(collapsed)
    end

    self:RefreshQuestList()
end

function FQL:AreAllQuestsTracked()
    local _, allQuestsByID = self:BuildStructuredLog()
    local total = 0
    local tracked = 0
    for qid, q in pairs(allQuestsByID) do
        total = total + 1
        if IsQuestWatchedByID(qid, q.logIndex) then
            tracked = tracked + 1
        end
    end
    local hasAnyTracked = (tracked > 0)
    local allTracked = (total > 0 and tracked >= total)
    return hasAnyTracked, total, tracked, allTracked
end

function FQL:ToggleTrackAllQuests()
    local _, allQuestsByID = self:BuildStructuredLog()
    local hasAnyTracked, total = self:AreAllQuestsTracked()
    if total == 0 then return end

    -- If any quests are currently tracked, untrack them all. Otherwise, track all.
    local shouldWatch = not hasAnyTracked
    for qid, q in pairs(allQuestsByID) do
        SetQuestWatchedByID(qid, q.logIndex, shouldWatch)
    end
    if not shouldWatch and GetNumQuestWatches and RemoveQuestWatch then
        local numWatches = SafeNum(GetNumQuestWatches()) or 0
        for i = numWatches, 1, -1 do
            local qIndex = (GetQuestIndexForWatch and GetQuestIndexForWatch(i)) or i
            if qIndex then
                pcall(RemoveQuestWatch, qIndex)
            end
        end
    end
    if C_QuestLog and C_QuestLog.SortQuestWatches then
        pcall(C_QuestLog.SortQuestWatches)
    end
    self:Refresh()
    self:RefreshObjectiveTracker(true)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            FQL:Refresh()
            FQL:RefreshObjectiveTracker(true)
        end)
    end
end

function FQL:SelectQuest(questID, logIndex)
    questID = SafeNum(questID)
    if not questID or questID <= 0 then return end
    self.selectedQuestID = questID
    if shupazForeverQuestLogCharDB then
        shupazForeverQuestLogCharDB.selectedQuestID = questID
    end
    SelectLogQuest(questID, logIndex)
    self:Refresh()
end

function FQL:RefreshQuestList()
    local frame = self.frame
    if not frame then return end

    local sections, allQuestsByID, firstQuestID, numQuests = self:BuildStructuredLog()
    self.allQuestsByID = allQuestsByID

    local maxQuests = GetMaxQuests()
    if numQuests >= maxQuests then
        frame.countText:SetFormattedText("Quests: |cffff4444%d/%d|r", numQuests, maxQuests)
    else
        frame.countText:SetFormattedText("Quests: |cffffffff%d/%d|r", numQuests, maxQuests)
    end

    -- Ensure valid selectedQuestID
    if not self.selectedQuestID or not allQuestsByID[self.selectedQuestID] then
        local savedID = shupazForeverQuestLogCharDB and shupazForeverQuestLogCharDB.selectedQuestID
        if savedID and allQuestsByID[savedID] then
            self.selectedQuestID = savedID
        else
            self.selectedQuestID = firstQuestID
        end
    end

    local filter = self.searchFilter or ""
    local isFiltering = filter ~= ""
    local collapsed = (shupazForeverQuestLogCharDB and shupazForeverQuestLogCharDB.collapsedHeaders) or {}

    local rowIndex = 0
    local yOffset = 0
    local rowWidth = (frame.listScroll:GetWidth() or 280) - 4
    if rowWidth < 240 then rowWidth = 278 end
    frame.listContent:SetWidth(rowWidth)

    local anyExpanded = false

    for _, sec in ipairs(sections) do
        local matchingQuests = {}
        for _, q in ipairs(sec.quests) do
            if not isFiltering then
                matchingQuests[#matchingQuests + 1] = q
            else
                local matchTitle = q.title:lower():find(filter, 1, true)
                local matchZone = sec.title:lower():find(filter, 1, true)
                if matchTitle or matchZone then
                    matchingQuests[#matchingQuests + 1] = q
                end
            end
        end

        if #matchingQuests > 0 then
            local isSecCollapsed = (not isFiltering) and (collapsed[sec.title] == true)
            if not isSecCollapsed then
                anyExpanded = true
            end

            -- Header Row
            rowIndex = rowIndex + 1
            local hRow = AcquireListRow(frame, rowIndex)
            hRow.isHeader = true
            hRow.headerTitle = sec.title
            hRow.questEntry = nil
            hRow:SetWidth(rowWidth)
            hRow:ClearAllPoints()
            hRow:SetPoint("TOPLEFT", frame.listContent, "TOPLEFT", 0, -yOffset)

            hRow.bg:SetColorTexture(0.18, 0.13, 0.07, 0.85)
            hRow.bg:Show()
            hRow.collapseIcon:SetTexture(isSecCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            hRow.collapseIcon:Show()
            hRow.trackCheck:Hide()
            hRow.statusText:SetText("|cffb8a582(" .. tostring(#matchingQuests) .. ")|r")
            hRow.titleText:SetPoint("LEFT", 22, 0)
            hRow.titleText:SetText(sec.title)
            hRow.titleText:SetTextColor(1.0, 0.82, 0.18)
            hRow:Show()
            yOffset = yOffset + 23

            -- Quest Rows inside Section
            if not isSecCollapsed then
                for _, q in ipairs(matchingQuests) do
                    rowIndex = rowIndex + 1
                    local qRow = AcquireListRow(frame, rowIndex)
                    qRow.isHeader = false
                    qRow.headerTitle = nil
                    qRow.questEntry = q
                    qRow:SetWidth(rowWidth)
                    qRow:ClearAllPoints()
                    qRow:SetPoint("TOPLEFT", frame.listContent, "TOPLEFT", 0, -yOffset)

                    local isSelected = (q.questID == self.selectedQuestID)
                    local watched = IsQuestWatchedByID(q.questID, q.logIndex)
                    local superTracked = IsQuestSuperTracked(q.questID)
                    local r, g, b = GetDifficultyColor(q.level)

                    if isSelected then
                        qRow.bg:SetColorTexture(0.55, 0.42, 0.16, 0.48)
                        qRow.bg:Show()
                        self.selectedQuestTitle = q.title
                    else
                        qRow.bg:Hide()
                    end

                    qRow.collapseIcon:Hide()

                    if watched then
                        qRow.trackCheck:Show()
                        if superTracked then
                            qRow.trackCheck:SetVertexColor(1.0, 0.85, 0.2)
                        else
                            qRow.trackCheck:SetVertexColor(0.85, 0.85, 0.85)
                        end
                    else
                        qRow.trackCheck:Hide()
                    end

                    if q.completeState == 1 then
                        qRow.statusText:SetText("|cff40ff40(" .. (COMPLETE or "Complete") .. ")|r")
                    elseif q.completeState == -1 then
                        qRow.statusText:SetText("|cffff4040(" .. (FAILED or "Failed") .. ")|r")
                    else
                        qRow.statusText:SetText("")
                    end

                    local prefix = ""
                    if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.showQuestLevels ~= false then
                        local lvlStr = (q.level and q.level > 0) and tostring(q.level) or "?"
                        prefix = "[" .. lvlStr .. (q.tagAbbr or "") .. "] "
                    end

                    qRow.titleText:SetPoint("LEFT", 12, 0)
                    qRow.titleText:SetText(prefix .. q.title)
                    if isSelected then
                        qRow.titleText:SetTextColor(1.0, 1.0, 1.0)
                    else
                        qRow.titleText:SetTextColor(r, g, b)
                    end

                    qRow:Show()
                    yOffset = yOffset + 22
                end
            end

            yOffset = yOffset + 3
        end
    end

    for i = rowIndex + 1, #frame.listRows do
        frame.listRows[i]:Hide()
    end

    frame.collapseAllBtn.icon:SetTexture(anyExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    frame.emptyListText:SetShown(rowIndex == 0)
    frame.listContent:SetHeight(math.max(1, yOffset))

    if frame.trackAllBtn then
        local hasAnyTracked, totalQuests = self:AreAllQuestsTracked()
        if totalQuests == 0 then
            frame.trackAllBtn:Disable()
            frame.trackAllBtn:SetText("Track All")
        else
            frame.trackAllBtn:Enable()
            frame.trackAllBtn:SetText(hasAnyTracked and "Untrack All" or "Track All")
        end
    end
end

function FQL:RefreshQuestDetail()
    local frame = self.frame
    if not frame then return end

    local questID = self.selectedQuestID
    local qEntry = questID and self.allQuestsByID and self.allQuestsByID[questID]

    if not qEntry then
        frame.detailScroll:Hide()
        frame.noSelectionText:Show()
        frame.abandonBtn:Disable()
        frame.shareBtn:Disable()
        frame.trackBtn:Disable()
        frame.mapBtn:Disable()
        return
    end

    frame.noSelectionText:Hide()
    frame.detailScroll:Show()
    frame.abandonBtn:Enable()
    frame.trackBtn:Enable()
    frame.mapBtn:Enable()

    local logIndex = qEntry.logIndex
    local watched = IsQuestWatchedByID(questID, logIndex)
    frame.trackBtn:SetText(watched and (UNTRACK_QUEST_ABBREV or "Untrack") or (TRACK_QUEST_ABBREV or "Track"))

    local canShare = (C_QuestLog and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(questID))
    if canShare then
        frame.shareBtn:Enable()
    else
        frame.shareBtn:Disable()
    end

    local contentWidth = (frame.detailScroll:GetWidth() or 330) - 4
    if contentWidth < 260 then contentWidth = 326 end
    frame.detailContent:SetWidth(contentWidth)

    local objSummary, descText, objectives = GetQuestTextAndObjectives(questID, logIndex)
    local rewards = GetQuestRewardsData(questID, logIndex)

    local y = 0

    -- Special Quest Item button
    if rewards.specialItem and rewards.specialItem.icon then
        frame.specialItemBtn.logIndex = logIndex
        frame.specialItemBtn.itemLink = rewards.specialItem.link
        frame.specialItemBtn.icon:SetTexture(rewards.specialItem.icon)
        frame.specialItemBtn:ClearAllPoints()
        frame.specialItemBtn:SetPoint("TOPRIGHT", frame.detailContent, "TOPRIGHT", -2, -2)
        frame.specialItemBtn:Show()
    else
        frame.specialItemBtn:Hide()
    end

    -- Title
    local titleRightPad = frame.specialItemBtn:IsShown() and 44 or 0
    frame.detailTitle:ClearAllPoints()
    frame.detailTitle:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
    frame.detailTitle:SetWidth(contentWidth - titleRightPad)
    frame.detailTitle:SetText(qEntry.title)
    frame.detailTitle:Show()
    y = y + (frame.detailTitle:GetStringHeight() or 22) + 4

    -- Metadata line (Level, Tag, Group, Status)
    local metaParts = {}
    if qEntry.level and qEntry.level > 0 then
        metaParts[#metaParts + 1] = "Level " .. tostring(qEntry.level)
    end
    if qEntry.tagName then
        if qEntry.suggestedGroup and qEntry.suggestedGroup > 0 then
            metaParts[#metaParts + 1] = qEntry.tagName .. " (" .. tostring(qEntry.suggestedGroup) .. ")"
        else
            metaParts[#metaParts + 1] = qEntry.tagName
        end
    elseif qEntry.suggestedGroup and qEntry.suggestedGroup > 0 then
        metaParts[#metaParts + 1] = "Suggested Players [" .. tostring(qEntry.suggestedGroup) .. "]"
    end
    if qEntry.headerTitle then
        metaParts[#metaParts + 1] = qEntry.headerTitle
    end
    if qEntry.completeState == 1 then
        metaParts[#metaParts + 1] = "|cff147a14(" .. (COMPLETE or "Complete") .. ")|r"
    elseif qEntry.completeState == -1 then
        metaParts[#metaParts + 1] = "|cffa81818(" .. (FAILED or "Failed") .. ")|r"
    end

    frame.detailMeta:ClearAllPoints()
    frame.detailMeta:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
    frame.detailMeta:SetWidth(contentWidth - titleRightPad)
    frame.detailMeta:SetText(table.concat(metaParts, "  •  "))
    frame.detailMeta:Show()
    y = y + (frame.detailMeta:GetStringHeight() or 14) + 6

    -- Separator
    frame.detailSep:ClearAllPoints()
    frame.detailSep:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
    frame.detailSep:SetWidth(contentWidth)
    frame.detailSep:Show()
    y = y + 9

    -- Objective Summary
    if objSummary and objSummary ~= "" then
        frame.detailObjSummary:ClearAllPoints()
        frame.detailObjSummary:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
        frame.detailObjSummary:SetWidth(contentWidth)
        frame.detailObjSummary:SetText(objSummary)
        frame.detailObjSummary:Show()
        y = y + (frame.detailObjSummary:GetStringHeight() or 20) + 8
    else
        frame.detailObjSummary:Hide()
    end

    -- Objective Progress Lines + Required Money / Timer
    local objTextLines = {}
    for _, o in ipairs(objectives) do
        if o.finished then
            objTextLines[#objTextLines + 1] = "|cff2d5e20• " .. o.text .. " (" .. (COMPLETE or "Complete") .. ")|r"
        else
            objTextLines[#objTextLines + 1] = "• " .. o.text
        end
    end
    if rewards.requiredMoney and rewards.requiredMoney > 0 and GetCoinTextureString then
        local coinStr = GetCoinTextureString(rewards.requiredMoney)
        objTextLines[#objTextLines + 1] = (REQUIRED_MONEY or "Required Money:") .. " " .. (coinStr or tostring(rewards.requiredMoney))
    end
    if rewards.timeLeft and rewards.timeLeft > 0 and SecondsToTime then
        objTextLines[#objTextLines + 1] = (TIME_REMAINING or "Time Remaining:") .. " " .. SecondsToTime(rewards.timeLeft)
    end

    if #objTextLines > 0 then
        frame.detailObjLines:ClearAllPoints()
        frame.detailObjLines:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 4, -y)
        frame.detailObjLines:SetWidth(contentWidth - 4)
        frame.detailObjLines:SetText(table.concat(objTextLines, "\n"))
        frame.detailObjLines:Show()
        y = y + (frame.detailObjLines:GetStringHeight() or 16) + 12
    else
        frame.detailObjLines:Hide()
    end

    -- Description
    if descText and descText ~= "" then
        frame.detailDescHeader:ClearAllPoints()
        frame.detailDescHeader:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
        frame.detailDescHeader:Show()
        y = y + (frame.detailDescHeader:GetStringHeight() or 20) + 4

        frame.detailDescText:ClearAllPoints()
        frame.detailDescText:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
        frame.detailDescText:SetWidth(contentWidth)
        frame.detailDescText:SetText(descText)
        frame.detailDescText:Show()
        y = y + (frame.detailDescText:GetStringHeight() or 30) + 14
    else
        frame.detailDescHeader:Hide()
        frame.detailDescText:Hide()
    end

    -- Rewards Section
    local hasAnyReward = (#rewards.choices > 0) or (#rewards.fixed > 0) or (#rewards.spells > 0) or (rewards.xp > 0) or (rewards.money > 0)
    local btnIdx = 0

    local function PlaceRewardList(list, startY)
        local colWidth = math.floor((contentWidth - 6) / 2)
        for i, item in ipairs(list) do
            btnIdx = btnIdx + 1
            local btn = frame.rewardButtons[btnIdx]
            if not btn then
                btn = MakeRewardButton(frame.detailContent)
                frame.rewardButtons[btnIdx] = btn
            end
            btn:SetWidth(colWidth)
            btn.questID = questID
            btn.logIndex = logIndex
            btn.rewardType = item.rewardType
            btn.rewardIndex = item.index
            btn.itemID = item.itemID
            btn.spellID = item.spellID
            btn.icon:SetTexture(item.texture)
            btn.count:SetText((item.count and item.count > 1) and tostring(item.count) or "")

            local r, g, b = 1, 0.82, 0
            if item.itemID and GetItemQualityColor then
                local _, _, q = C_Item.GetItemInfo(item.itemID)
                local qual = SafeNum(q) or item.quality or 1
                local qr, qg, qb = GetItemQualityColor(qual)
                if qr then r, g, b = qr, qg, qb end
            end
            btn.name:SetText(item.name)
            btn.name:SetTextColor(r, g, b)

            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", col * (colWidth + 6), -(startY + row * 44))
            btn:Show()
        end
        local numRows = math.ceil(#list / 2)
        return startY + (numRows * 44) + 6
    end

    if hasAnyReward then
        frame.detailRewardsHeader:ClearAllPoints()
        frame.detailRewardsHeader:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
        frame.detailRewardsHeader:Show()
        y = y + (frame.detailRewardsHeader:GetStringHeight() or 20) + 6

        if #rewards.choices > 0 then
            frame.detailChoiceLabel:ClearAllPoints()
            frame.detailChoiceLabel:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
            frame.detailChoiceLabel:SetWidth(contentWidth)
            frame.detailChoiceLabel:Show()
            y = y + (frame.detailChoiceLabel:GetStringHeight() or 15) + 4
            y = PlaceRewardList(rewards.choices, y)
        else
            frame.detailChoiceLabel:Hide()
        end

        if #rewards.fixed > 0 then
            frame.detailFixedLabel:ClearAllPoints()
            frame.detailFixedLabel:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
            frame.detailFixedLabel:SetWidth(contentWidth)
            frame.detailFixedLabel:SetText((#rewards.choices > 0) and (REWARD_ITEMS or "You will also receive:") or (REWARD_ITEMS_ONLY or "You will receive:"))
            frame.detailFixedLabel:Show()
            y = y + (frame.detailFixedLabel:GetStringHeight() or 15) + 4
            y = PlaceRewardList(rewards.fixed, y)
        else
            frame.detailFixedLabel:Hide()
        end

        if #rewards.spells > 0 then
            frame.detailSpellLabel:ClearAllPoints()
            frame.detailSpellLabel:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
            frame.detailSpellLabel:SetWidth(contentWidth)
            frame.detailSpellLabel:Show()
            y = y + (frame.detailSpellLabel:GetStringHeight() or 15) + 4
            y = PlaceRewardList(rewards.spells, y)
        else
            frame.detailSpellLabel:Hide()
        end

        if rewards.xp and rewards.xp > 0 then
            frame.detailXPLine:ClearAllPoints()
            frame.detailXPLine:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
            frame.detailXPLine:SetText((EXPERIENCE_COLON or "Experience:") .. " " .. FormatNumber(rewards.xp) .. " XP")
            frame.detailXPLine:Show()
            y = y + (frame.detailXPLine:GetStringHeight() or 16) + 4
        else
            frame.detailXPLine:Hide()
        end

        if rewards.money and rewards.money > 0 and GetCoinTextureString then
            frame.detailMoneyLine:ClearAllPoints()
            frame.detailMoneyLine:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
            frame.detailMoneyLine:SetText((MONEY_COLON or "Money:") .. "  " .. GetCoinTextureString(rewards.money))
            frame.detailMoneyLine:Show()
            y = y + (frame.detailMoneyLine:GetStringHeight() or 16) + 6
        else
            frame.detailMoneyLine:Hide()
        end
    else
        frame.detailRewardsHeader:Hide()
        frame.detailChoiceLabel:Hide()
        frame.detailFixedLabel:Hide()
        frame.detailSpellLabel:Hide()
        frame.detailXPLine:Hide()
        frame.detailMoneyLine:Hide()
    end

    for i = btnIdx + 1, #frame.rewardButtons do
        frame.rewardButtons[i]:Hide()
    end

    frame.detailContent:SetHeight(math.max(1, y + 10))
    if self._lastRenderedQuestID ~= questID then
        self._lastRenderedQuestID = questID
        frame.detailScroll:SetVerticalScroll(0)
    end
end

function FQL:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self:RefreshQuestList()
    self:RefreshQuestDetail()
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
        if _G.QuestObjectiveTracker and _G.QuestObjectiveTracker._fqlActiveZones then
            AddZoneList(_G.QuestObjectiveTracker._fqlActiveZones)
        end
        if _G.CampaignQuestObjectiveTracker and _G.CampaignQuestObjectiveTracker._fqlActiveZones then
            AddZoneList(_G.CampaignQuestObjectiveTracker._fqlActiveZones)
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
    tracker._fqlZoneHeaders = tracker._fqlZoneHeaders or {}
    local hBtn = tracker._fqlZoneHeaders[index]
    if hBtn then return hBtn end

    local parent = tracker.ContentsFrame or tracker
    hBtn = CreateFrame("Button", nil, parent)
    hBtn._fqlZoneHeader = true
    hBtn:SetHeight(TRACKER_ZONE_HEADER_HEIGHT)
    hBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hBtn:SetHitRectInsets(-26, 0, 0, 0)

    -- Subtle dark-gold header bar background
    local bg = hBtn:CreateTexture(nil, "BACKGROUND")
    hBtn.bg = bg
    bg:SetPoint("TOPLEFT", -2, 0)
    bg:SetPoint("BOTTOMRIGHT", 2, 0)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetColorTexture(0.11, 0.08, 0.035, 0.52)

    -- Subtle bottom gold divider line
    local line = hBtn:CreateTexture(nil, "BORDER")
    hBtn.line = line
    line:SetPoint("BOTTOMLEFT", -2, 0)
    line:SetPoint("BOTTOMRIGHT", 2, 0)
    line:SetHeight(1)
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetColorTexture(0.76, 0.60, 0.22, 0.48)

    -- Collapse / Expand [+] / [-] button in the POI column (to the left of the header bar)
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

    -- Count badge on the right
    local countText = hBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hBtn.countText = countText
    countText:SetPoint("RIGHT", -4, 0)
    countText:SetJustifyH("RIGHT")

    -- Zone title text aligned with quest titles
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
            if tracker and (tracker._fqlMaxScrollIndex or 1) > 1 then
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

    tracker._fqlZoneHeaders[index] = hBtn
    return hBtn
end

local function HideAllTrackerZoneHeaders(tracker)
    if not tracker or not tracker._fqlZoneHeaders then return end
    for _, hBtn in ipairs(tracker._fqlZoneHeaders) do
        hBtn:Hide()
    end
end

local function IsRealTrackerBlock(block)
    if type(block) ~= "table" or not block.GetObjectType then return false end
    if block._fqlZoneHeader then return false end
    -- Exclude POIButtons which implement GetQuestID/SetQuestID and have no HeaderText/usedLines
    if (block.GetQuestID or block.SetQuestID) and not block.HeaderText and not block.usedLines then
        return false
    end
    if block.HeaderText ~= nil or block.HeaderButton ~= nil or block.usedLines ~= nil or block.AddObjective ~= nil or block.linePool ~= nil or block.parentModule ~= nil then
        return true
    end
    return false
end

local function CaptureBlockNativeAnchors(block, contents)
    local h = SafeNum(block.height) or SafeNum(block:GetHeight())
    if h and h > 8 then
        block._fqlHeight = h
    end
    if block._fqlNativeCaptured then return end
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

    block._fqlHorizPoints = horizPoints
    block._fqlLeftOffset = leftOffset or 0
    block._fqlRightOffset = rightOffset or 0
    if topOffset and topOffset > 0 and topOffset < 30 then
        block._fqlTopOffset = topOffset
    end
    local w = SafeNum(block:GetWidth())
    if w and w > 80 then
        block._fqlWidth = w
    end
    local h = SafeNum(block.height) or SafeNum(block:GetHeight())
    if h and h > 8 then
        block._fqlHeight = h
    end
    block._fqlNativeCaptured = true
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
        if not (fromActiveTable or block:IsShown() or block._fqlHiddenByZone or block.used) then return end

        local qid = ResolveBlockQuestID(block, keyQuestID)
        if not qid or qid <= 0 then return end

        -- Ignore stale pooled blocks whose quests are no longer watched or in the log
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

    -- 1. Walk tracker.firstBlock -> block.nextBlock linked list (11.0+ ObjectiveTrackerModuleMixin)
    if tracker.firstBlock then
        local curr = tracker.firstBlock
        local guard = 0
        while curr and guard < 200 do
            guard = guard + 1
            InspectCandidateBlock(curr, nil, true)
            curr = curr.nextBlock
        end
    end

    -- 2. Check tracker.usedBlocks table
    if type(tracker.usedBlocks) == "table" then
        for _, templateBlocks in pairs(tracker.usedBlocks) do
            if type(templateBlocks) == "table" then
                for k, block in pairs(templateBlocks) do
                    InspectCandidateBlock(block, k, block.used ~= false)
                end
            end
        end
    end

    -- 3. Also scan direct children of ContentsFrame
    if contents and contents.GetChildren then
        for _, child in ipairs({ contents:GetChildren() }) do
            InspectCandidateBlock(child, nil, false)
        end
    end

    -- 4. Collect POI buttons & special item buttons associated with each questID
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
            if not seenBlocks[child] and not child._fqlZoneHeader then
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
    if not tracker or not tracker.Header or tracker._fqlHeaderZoneBtn then return end
    local header = tracker.Header
    local minBtn = header.MinimizeButton or header.FilterButton
    local btn = CreateFrame("Button", nil, header)
    tracker._fqlHeaderZoneBtn = btn
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
    if not fs._fqlOrigFont then
        fs._fqlOrigFont = SafeStr(curFont) or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
        fs._fqlOrigSize = SafeNum(curSize) or 12
        fs._fqlOrigFlags = SafeStr(curFlags) or ""
    end
    local targetFont = fontPath or fs._fqlOrigFont
    local size = SafeNum(curSize) or fs._fqlOrigSize or 12
    local flags = SafeStr(curFlags) or fs._fqlOrigFlags or ""
    if curFont ~= targetFont then
        pcall(fs.SetFont, fs, targetFont, size, flags)
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

    if tracker.Header and tracker.Header.Text then
        ApplyFontToFontString(tracker.Header.Text, fontPath)
    end

    if tracker._fqlZoneHeaders then
        for _, hBtn in ipairs(tracker._fqlZoneHeaders) do
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

function FQL:SetTrackerFont(fontID)
    if shupazForeverQuestLogDB then
        shupazForeverQuestLogDB.trackerFont = fontID or "DEFAULT"
    end
    self:RefreshObjectiveTracker()
    if self.optionsPanel and self.optionsPanel.RefreshControls then
        self.optionsPanel:RefreshControls()
    end
end

local function GetMaxTrackerContentsHeight(tracker, contents)
    local container = _G.ObjectiveTrackerFrame
    local containerMax = nil

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

    if (not containerMax or containerMax <= 0 or containerMax >= 50000) and tracker._fqlNativeAvailableHeight then
        containerMax = tracker._fqlNativeAvailableHeight
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
    if tracker._fqlNativeAvailableHeight and tracker._fqlNativeAvailableHeight > 60 and tracker._fqlNativeAvailableHeight < maxH then
        maxH = tracker._fqlNativeAvailableHeight
    end

    -- Also ensure the list never overflows past the bottom of the screen (leave a 100px bottom margin)
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
    local maxIdx = tracker._fqlMaxScrollIndex or 1
    local clamped = math.max(1, math.min(maxIdx, math.floor((newIndex or 1) + 0.5)))
    if clamped ~= (tracker._fqlScrollIndex or 1) then
        tracker._fqlScrollIndex = clamped
        self:ApplyTrackerZoneLayout(tracker)
    end
end

function FQL:ScrollTrackerByDelta(tracker, delta)
    if not tracker then return end
    local maxIdx = tracker._fqlMaxScrollIndex or 1
    if maxIdx <= 1 then return end
    local cur = tracker._fqlScrollIndex or 1
    local step = (IsShiftKeyDown and IsShiftKeyDown()) and 3 or 1
    local nextIdx
    if (delta or 0) > 0 then
        nextIdx = math.max(1, cur - step)
    else
        nextIdx = math.min(maxIdx, cur + step)
    end
    if nextIdx ~= cur then
        tracker._fqlScrollIndex = nextIdx
        self:ApplyTrackerZoneLayout(tracker)
    end
end

local function AttachTrackerMouseWheel(frameObj, tracker)
    if not frameObj or frameObj._fqlMouseWheelHooked or not tracker then return end
    frameObj._fqlMouseWheelHooked = true
    frameObj._fqlWheelTracker = tracker
    pcall(function()
        if frameObj.EnableMouseWheel then
            frameObj:EnableMouseWheel(true)
        end
        if frameObj.GetScript and frameObj:GetScript("OnMouseWheel") then
            frameObj:HookScript("OnMouseWheel", function(self, delta)
                if FQL and FQL.ScrollTrackerByDelta then
                    FQL:ScrollTrackerByDelta(self._fqlWheelTracker or tracker, delta)
                end
            end)
        elseif frameObj.SetScript then
            frameObj:SetScript("OnMouseWheel", function(self, delta)
                if FQL and FQL.ScrollTrackerByDelta then
                    FQL:ScrollTrackerByDelta(self._fqlWheelTracker or tracker, delta)
                end
            end)
        end
    end)
end

local function EnsureTrackerScrollBar(tracker, contents)
    if not tracker or not contents then return nil end
    if tracker._fqlScrollBar then
        return tracker._fqlScrollBar
    end

    local sb = CreateFrame("Frame", nil, contents)
    tracker._fqlScrollBar = sb
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

    -- Up Arrow Button
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

    -- Down Arrow Button
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

    -- Track between Up and Down buttons
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

    -- Draggable Thumb
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
            local cur = tracker._fqlScrollIndex or 1
            local maxIdx = tracker._fqlMaxScrollIndex or 1
            local totalQ = tracker._fqlTotalTrackedQuests or 0
            local shownQ = tracker._fqlShownTrackedQuests or 0
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
            local maxIdx = tracker._fqlMaxScrollIndex or 1
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

    -- Clicking the track above/below the thumb pages up/down
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
            FQL:SetTrackerScrollIndex(tracker, (tracker._fqlScrollIndex or 1) - 3)
        elseif thumbBot and cursorY < thumbBot then
            FQL:SetTrackerScrollIndex(tracker, (tracker._fqlScrollIndex or 1) + 3)
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

    self:ApplyTrackerStyle(tracker)
    AttachTrackerMouseWheel(contents, tracker)

    local function HideTrackerQuestEntry(entry)
        if not entry then return end
        local b = entry.block
        if b then
            b._fqlHiddenByZone = true
            if CanChangeFrame(b) then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", contents, "TOPLEFT", 0, 0)
                b:Hide()
            else
                FQL._needsTrackerCombatRefresh = true
            end
        end
        for _, att in ipairs(entry.attachments or {}) do
            att._fqlHiddenByZone = true
            if CanChangeFrame(att) then
                att:Hide()
            end
        end
    end

    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerByZone == false then
        HideAllTrackerZoneHeaders(tracker)
        if tracker._fqlHeaderZoneBtn then tracker._fqlHeaderZoneBtn:Hide() end
        if tracker._fqlScrollBar then tracker._fqlScrollBar:Hide() end
        if contents.GetChildren then
            for _, child in ipairs({ contents:GetChildren() }) do
                if child._fqlHiddenByZone then
                    child._fqlHiddenByZone = nil
                    if CanChangeFrame(child) then child:Show() end
                end
            end
        end
        return
    end

    -- If the entire Quests module or ObjectiveTrackerFrame is collapsed, hide zone headers
    if (tracker.IsCollapsed and tracker:IsCollapsed()) or not contents:IsShown() then
        HideAllTrackerZoneHeaders(tracker)
        if tracker._fqlHeaderZoneBtn then tracker._fqlHeaderZoneBtn:Hide() end
        if tracker._fqlScrollBar then tracker._fqlScrollBar:Hide() end
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
        if tracker._fqlHeaderZoneBtn then tracker._fqlHeaderZoneBtn:Hide() end
        if tracker._fqlScrollBar then tracker._fqlScrollBar:Hide() end
        self._inTrackerLayout = false
        return
    end

    self:EnsureTrackerHeaderZoneButton(tracker)
    if tracker._fqlHeaderZoneBtn then
        tracker._fqlHeaderZoneBtn:Show()
    end

    -- Determine horizontal offsets and width from captured block metrics
    local defaultLeftOffset = 0
    local defaultRightOffset = 0
    local defaultWidth = SafeNum(contents:GetWidth()) or 235
    local startY = 10

    for _, entry in ipairs(questBlocks) do
        local b = entry.block
        if b._fqlLeftOffset ~= nil then
            defaultLeftOffset = b._fqlLeftOffset
            defaultRightOffset = b._fqlRightOffset or 0
            if b._fqlWidth and b._fqlWidth > 80 then
                defaultWidth = b._fqlWidth
            end
            if b._fqlTopOffset then
                startY = math.max(10, b._fqlTopOffset)
            end
            break
        end
    end

    -- Group active quest blocks by Zone
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

    -- Build the flat ordered list of renderable items (Zone Headers + expanded Quest Blocks)
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
                local bHeight = SafeNum(b.height) or b._fqlHeight or SafeNum(b:GetHeight()) or 36
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

    -- Helper to compute whether rendering from startIdx..#renderItems fits in maxContentsHeight
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

    tracker._fqlMaxScrollIndex = maxScrollIndex
    local scrollIndex = math.max(1, math.min(maxScrollIndex, tracker._fqlScrollIndex or 1))
    tracker._fqlScrollIndex = scrollIndex

    local scrollbarPad = (maxScrollIndex > 1) and 9 or 0
    local effectiveRightOffset = defaultRightOffset - scrollbarPad

    -- Hide any quest blocks above scrollIndex
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

    -- If scrollIndex starts on a QUEST item, pin its Zone Header at the top first
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
            local prevIsHeader = (i == scrollIndex) or (renderItems[i - 1] and renderItems[i - 1].type == "HEADER")
            local gap = prevIsHeader and TRACKER_ZONE_HEADER_GAP_BOTTOM or TRACKER_BLOCK_GAP
            local bHeight = it.height
            local fits = (not overflowReached) and ((estimatedHeight + gap + bHeight <= maxContentsHeight) or visibleItemCount == 0)

            if not fits then
                overflowReached = true
                HideTrackerQuestEntry(entry)
            else
                b._fqlHiddenByZone = nil
                local bWidth = b._fqlWidth or defaultWidth
                local bLeft = SafeNum(b.offsetX) or b._fqlLeftOffset or defaultLeftOffset

                if CanChangeFrame(b) then
                    b:ClearAllPoints()
                    b:SetPoint("TOP", prevAnchorFrame, "BOTTOM", 0, -gap)
                    if b._fqlHorizPoints and #b._fqlHorizPoints > 0 and scrollbarPad == 0 then
                        for _, hp in ipairs(b._fqlHorizPoints) do
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
                    att._fqlHiddenByZone = nil
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

    for i = headerIdx + 1, #(tracker._fqlZoneHeaders or {}) do
        tracker._fqlZoneHeaders[i]:Hide()
    end

    if tracker._fqlHeaderZoneBtn and tracker._fqlHeaderZoneBtn.icon then
        tracker._fqlHeaderZoneBtn.icon:SetTexture(anyZoneExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    end

    tracker._fqlActiveZones = activeZoneNames
    tracker._fqlTotalTrackedQuests = #questBlocks
    tracker._fqlShownTrackedQuests = shownTrackedQuests
    if #activeZoneNames > 0 then
        self._lastTrackerZones = activeZoneNames
    end

    local finalHeight = math.min(maxContentsHeight, math.max(24, estimatedHeight + 6))
    tracker.contentsHeight = finalHeight
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

local function ForceUnlimitedTrackerHeight(self)
    local cur = SafeNum(self.availableHeight)
    if cur and cur > 40 and cur < 50000 then
        self._fqlNativeAvailableHeight = cur
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
    if not tracker or tracker._fqlTrackerHooked then return end
    tracker._fqlTrackerHooked = true

    if tracker.BeginLayout then
        hooksecurefunc(tracker, "BeginLayout", function(self)
            self._fqlOrigAvailableHeight = self.availableHeight
            ForceUnlimitedTrackerHeight(self)
            local cFrame = self.ContentsFrame or self
            if cFrame and cFrame.GetChildren then
                for _, child in ipairs({ cFrame:GetChildren() }) do
                    if child._fqlHiddenByZone then
                        child._fqlHiddenByZone = nil
                    end
                end
            end
        end)
    end

    -- In ObjectiveTrackerModuleMixin:Update(availableHeight, dirtyUpdate),
    -- Blizzard sets `self.availableHeight = availableHeight` AFTER `self:BeginLayout()`.
    -- Hook all pre-block-fit methods inside `LayoutContents()` so `self.availableHeight`
    -- is always restored to 100000 before `CanFitHeader()` / `CanFitBlock()` runs,
    -- preventing the tracker from truncating quests after ~2 zones.
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
            -- If Blizzard still skipped any blocks due to height budget, immediately retry with 100000 height
            if NeedsFullHeightRetry(self) then
                if not self._fqlRetryingFullHeight and not (InCombatLockdown and InCombatLockdown()) and self.Update then
                    self._fqlRetryingFullHeight = true
                    pcall(self.Update, self, 100000, false)
                    self._fqlRetryingFullHeight = false
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
        hooksecurefunc(tracker, "Update", function(self, availableHeight, dirtyUpdate)
            if dirtyUpdate and not self._fqlRetryingFullHeight and not (InCombatLockdown and InCombatLockdown()) then
                FQL:ApplyTrackerZoneLayout(self)
            end
        end)
    end
end

local function SetupObjectiveTrackerHooks()
    if _G.QuestObjectiveTracker then
        HookSingleTrackerModule(_G.QuestObjectiveTracker)
    end
    if _G.CampaignQuestObjectiveTracker then
        HookSingleTrackerModule(_G.CampaignQuestObjectiveTracker)
    end
    if _G.ObjectiveTrackerFrame and not _G.ObjectiveTrackerFrame._fqlContainerHooked then
        _G.ObjectiveTrackerFrame._fqlContainerHooked = true
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

function FQL:RefreshObjectiveTracker(forceFullRebuild)
    SetupObjectiveTrackerHooks()
    local inCombat = (InCombatLockdown and InCombatLockdown())
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerByZone == false then
        -- Hide custom zone headers first, then ask native tracker to re-layout blocks
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
    subtitle:SetText("Standalone Dual-Pane Quest Log & Zone-Grouped Objective Tracker  |cff888888(v1.0.0)|r")

    -- Top-Right Action Buttons
    local openLogBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    openLogBtn:SetSize(140, 24)
    openLogBtn:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -18, -18)
    openLogBtn:SetText("Toggle Quest Log")
    openLogBtn:SetScript("OnClick", function()
        FQL:Toggle()
    end)

    local resetDefaultsBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    resetDefaultsBtn:SetSize(130, 24)
    resetDefaultsBtn:SetPoint("RIGHT", openLogBtn, "LEFT", -8, 0)
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
    CreateSectionHeader(bg, "Standalone Quest Log Window", -66)

    -- Window Scale Slider + Buttons
    local scaleLabel = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleLabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 26, -92)
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

    CreateOptionCheckbox(
        bg, -118,
        "Show Quest Levels & Type Tags",
        "Prefixes quest titles with their level and tag indicator (e.g. [60D] for Dungeon, [60G] for Group, [60R] for Raid).",
        "showQuestLevels",
        function()
            FQL:Refresh()
        end
    )

    CreateOptionCheckbox(
        bg, -154,
        "Show Quest Row Hover Tooltips",
        "Displays a quick summary tooltip with objectives, zone, and click shortcuts when hovering over a quest in the list.",
        "showTooltips",
        function()
            FQL:Refresh()
        end
    )

    CreateOptionCheckbox(
        bg, -190,
        "Lock Quest Log Window Position",
        "Prevents the standalone Quest Log window from being dragged on screen.",
        "lockWindow",
        nil
    )

    -- ========================================================
    -- Section 2: World Map Integration
    -- ========================================================
    CreateSectionHeader(bg, "World Map Integration", -232)

    CreateOptionCheckbox(
        bg, -256,
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
    CreateSectionHeader(bg, "Objective Tracker (Scale, Font & Zone Grouping)", -300)

    -- Objective Tracker Scale Row
    local tScaleLabel = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tScaleLabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 26, -326)
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

    -- Popup Dropdown Menu for Font Selection
    local fontMenu = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    fontMenu:SetFrameStrata("TOOLTIP")
    fontMenu:SetToplevel(true)
    fontMenu:SetPoint("TOPLEFT", fontDropdownBtn, "BOTTOMLEFT", 0, -2)
    fontMenu:SetWidth(248)
    SetBackdrop(fontMenu, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    fontMenu:SetBackdropColor(0.06, 0.05, 0.04, 0.98)
    fontMenu:SetBackdropBorderColor(0.65, 0.52, 0.24, 0.95)
    fontMenu:Hide()
    fontMenu.rows = {}

    local function PopulateAndToggleFontMenu()
        if fontMenu:IsShown() then
            fontMenu:Hide()
            return
        end
        local fonts = FQL:GetTrackerFonts()
        local currentID = (shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerFont) or "DEFAULT"
        local rowH = 22
        local maxRows = math.min(#fonts, 14)

        for i = 1, maxRows do
            local fEntry = fonts[i]
            local r = fontMenu.rows[i]
            if not r then
                r = CreateFrame("Button", nil, fontMenu)
                r:SetHeight(rowH)
                r:SetPoint("TOPLEFT", fontMenu, "TOPLEFT", 4, -4 - (i - 1) * rowH)
                r:SetPoint("TOPRIGHT", fontMenu, "TOPRIGHT", -4, -4 - (i - 1) * rowH)
                r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

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
        for i = maxRows + 1, #fontMenu.rows do
            fontMenu.rows[i]:Hide()
        end
        fontMenu:SetHeight(maxRows * rowH + 8)
        fontMenu:Show()
    end

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
        if shupazForeverQuestLogCharDB and shupazForeverQuestLogCharDB.collapsedTrackerZones then
            wipe(shupazForeverQuestLogCharDB.collapsedTrackerZones)
        end
        FQL:RefreshObjectiveTracker()
    end)

    local collapseTrackerBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    collapseTrackerBtn:SetSize(165, 24)
    collapseTrackerBtn:SetPoint("LEFT", expandTrackerBtn, "RIGHT", 10, 0)
    collapseTrackerBtn:SetText("Collapse Tracker Zones")
    collapseTrackerBtn:SetScript("OnClick", function()
        if not shupazForeverQuestLogCharDB then return end
        shupazForeverQuestLogCharDB.collapsedTrackerZones = shupazForeverQuestLogCharDB.collapsedTrackerZones or {}
        if _G.QuestObjectiveTracker and _G.QuestObjectiveTracker._fqlZoneHeaders then
            for _, hdr in ipairs(_G.QuestObjectiveTracker._fqlZoneHeaders) do
                if hdr:IsShown() and hdr.zoneName then
                    shupazForeverQuestLogCharDB.collapsedTrackerZones[hdr.zoneName] = true
                end
            end
        end
        if _G.CampaignQuestObjectiveTracker and _G.CampaignQuestObjectiveTracker._fqlZoneHeaders then
            for _, hdr in ipairs(_G.CampaignQuestObjectiveTracker._fqlZoneHeaders) do
                if hdr:IsShown() and hdr.zoneName then
                    shupazForeverQuestLogCharDB.collapsedTrackerZones[hdr.zoneName] = true
                end
            end
        end
        FQL:RefreshObjectiveTracker()
    end)

    local expandLogBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    expandLogBtn:SetSize(165, 24)
    expandLogBtn:SetPoint("LEFT", collapseTrackerBtn, "RIGHT", 10, 0)
    expandLogBtn:SetText("Expand Quest Log Zones")
    expandLogBtn:SetScript("OnClick", function()
        FQL:SetAllHeadersCollapsed(false)
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
-- Event Handling
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
