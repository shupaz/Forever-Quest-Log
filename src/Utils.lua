local ADDON_NAME, FQL = ...
if type(FQL) ~= "table" then
    FQL = {}
end
_G.shupaz_ForeverQuestLog = FQL

FQL.ADDON_NAME = ADDON_NAME or "shupaz_ForeverQuestLog"
FQL.VERSION = "1.0.4"

local MIN_SCALE, MAX_SCALE = 0.6, 1.6
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 730, 520
FQL.MIN_SCALE = MIN_SCALE
FQL.MAX_SCALE = MAX_SCALE
FQL.DEFAULT_WIDTH = DEFAULT_WIDTH
FQL.DEFAULT_HEIGHT = DEFAULT_HEIGHT

local DB_DEFAULTS = {
    scale = 1.0,
    lockWindow = true,
    useDefaultPosition = true,
    wowheadBarPosition = "HIDE",
    hideMapQuestLog = true,
    showQuestLevels = true,
    showTooltips = true,
    questLogFontScale = 1.0,
    trackerByZone = true,
    trackerCurrentZoneFirst = true,
    trackerShowZoneCount = true,
    trackerScale = 1.0,
    trackerFont = "DEFAULT",
    trackerFontScale = 1.0,
}
FQL.DB_DEFAULTS = DB_DEFAULTS

local CHAR_DEFAULTS = {
    collapsedHeaders = {},
    collapsedTrackerZones = {},
    selectedQuestID = nil,
}
FQL.CHAR_DEFAULTS = CHAR_DEFAULTS

-- ============================================================
-- Tracker Fonts (Dynamic Discovery of User's Installed Fonts)
-- ============================================================

local KNOWN_FONT_NAMES = {
    ["frizqt__.ttf"]     = "Friz Quadrata",
    ["frizqt___cyr.ttf"] = "Friz Quadrata (Cyrillic)",
    ["arialn.ttf"]       = "Arial Narrow",
    ["morpheus.ttf"]     = "Morpheus",
    ["morpheus_cyr.ttf"] = "Morpheus (Cyrillic)",
    ["skurri.ttf"]       = "Skurri",
    ["skurri_cyr.ttf"]   = "Skurri (Cyrillic)",
    ["nim_____.ttf"]     = "Nimrod MT",
    ["2002.ttf"]         = "2002",
    ["2002b.ttf"]        = "2002 Bold",
    ["k_pagetext.ttf"]   = "MoK",
    ["arhei.ttf"]        = "AR Crystalzcuhei",
    ["arkai_t.ttf"]      = "AR Zhongkai",
    ["arkai_c.ttf"]      = "AR Heiti",
    ["bhei00m.ttf"]      = "AR Leisu",
    ["bhei01b.ttf"]      = "AR Yuan",
    ["blei00d.ttf"]      = "AR Mingti",
}

local fontProbeFS

local function NormalizeFontPath(path)
    if type(path) ~= "string" then return "" end
    return path:gsub("/", "\\"):lower()
end

local function IsFontPathAvailable(path)
    if type(path) ~= "string" or path == "" then return false end
    if not fontProbeFS and UIParent then
        local f = CreateFrame("Frame", nil, UIParent)
        f:Hide()
        fontProbeFS = f:CreateFontString(nil, "OVERLAY")
    end
    if not fontProbeFS then return true end
    local ok, applied = pcall(fontProbeFS.SetFont, fontProbeFS, path, 12, "")
    return ok and applied ~= false
end

local function FormatFontLabelFromPath(path)
    local file = path:match("([^\\/]+)$") or path
    local lowerFile = file:lower()
    if KNOWN_FONT_NAMES[lowerFile] then
        return KNOWN_FONT_NAMES[lowerFile]
    end
    local stem = file:gsub("%.[tT][tT][fF]$", ""):gsub("%.[oO][tT][fF]$", "")
    stem = stem:gsub("[_%-]+", " ")
    return stem
end

function FQL:GetTrackerFonts()
    local list = {}
    local seenPaths = {}
    local seenLabels = {}

    -- 1. Current Active Default UI Font
    local defaultPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if _G.GameFontNormal and type(_G.GameFontNormal.GetFont) == "function" then
        local ok, p = pcall(_G.GameFontNormal.GetFont, _G.GameFontNormal)
        if ok and type(p) == "string" and p ~= "" then
            defaultPath = p
        end
    end
    local defaultLabel = FormatFontLabelFromPath(defaultPath) .. " (Default)"
    list[#list + 1] = {
        id = "DEFAULT",
        label = defaultLabel,
        path = defaultPath,
    }
    seenPaths[NormalizeFontPath(defaultPath)] = true
    seenLabels[defaultLabel:lower()] = true

    local extraEntries = {}
    local function AddFontCandidate(id, label, path)
        if type(path) ~= "string" or path == "" then return end
        local normPath = NormalizeFontPath(path)
        if seenPaths[normPath] then return end
        if not IsFontPathAvailable(path) then return end

        label = (type(label) == "string" and label ~= "") and label or FormatFontLabelFromPath(path)
        local normLabel = label:lower()
        if seenLabels[normLabel] then return end

        seenPaths[normPath] = true
        seenLabels[normLabel] = true
        extraEntries[#extraEntries + 1] = {
            id = id,
            label = label,
            path = path,
        }
    end

    -- 2. Fonts registered in LibSharedMedia-3.0 by the user's installed addons
    if _G.LibStub then
        local ok, lsm = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm and type(lsm.List) == "function" and type(lsm.Fetch) == "function" then
            local names = lsm:List("font")
            if type(names) == "table" then
                for _, name in ipairs(names) do
                    local path = lsm:Fetch("font", name)
                    AddFontCandidate("LSM:" .. name, name, path)
                end
            end
        end
    end

    -- 3. Fonts currently loaded in the user's WoW client via GetFonts()
    if type(_G.GetFonts) == "function" then
        local ok, fontNames = pcall(_G.GetFonts)
        if ok and type(fontNames) == "table" then
            for _, fName in ipairs(fontNames) do
                local fObj = (type(fName) == "string") and _G[fName] or nil
                if fObj and type(fObj.GetFont) == "function" then
                    local okF, fPath = pcall(fObj.GetFont, fObj)
                    if okF and type(fPath) == "string" and fPath ~= "" then
                        local lbl = FormatFontLabelFromPath(fPath)
                        AddFontCandidate("FONT:" .. NormalizeFontPath(fPath), lbl, fPath)
                    end
                end
            end
        end
    end

    -- 4. Standard client font globals if present on the user's client
    for _, gPath in ipairs({
        _G.STANDARD_TEXT_FONT,
        _G.UNIT_NAME_FONT,
        _G.DAMAGE_TEXT_FONT,
        _G.NAMEPLATE_FONT,
    }) do
        if type(gPath) == "string" and gPath ~= "" then
            AddFontCandidate("FONT:" .. NormalizeFontPath(gPath), FormatFontLabelFromPath(gPath), gPath)
        end
    end

    table.sort(extraEntries, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    for _, entry in ipairs(extraEntries) do
        list[#list + 1] = entry
    end

    return list
end

function FQL:GetTrackerFontEntry(fontID)
    fontID = fontID or (shupazForeverQuestLogDB and shupazForeverQuestLogDB.trackerFont) or "DEFAULT"
    local fonts = self:GetTrackerFonts()
    local lowerID = tostring(fontID):lower()
    for i, entry in ipairs(fonts) do
        if entry.id == fontID or entry.id:lower() == lowerID or entry.label:lower() == lowerID then
            return entry, i, fonts
        end
    end
    for i, entry in ipairs(fonts) do
        if entry.path and entry.path:lower():find(lowerID, 1, true) then
            return entry, i, fonts
        end
    end
    return fonts[1], 1, fonts
end

function FQL:GetTrackerFontPath()
    local entry = self:GetTrackerFontEntry()
    if not entry or entry.id == "DEFAULT" then
        return nil
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
    if IsSecret(v) then
        return nil
    end
    if type(v) == "number" then
        return v
    end
    if type(v) == "string" then
        return tonumber(v)
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

local function ExpandAllNativeHeaders()
    -- Only call ExpandQuestHeader(0) if a native header is actually collapsed.
    -- Calling ExpandQuestHeader(0) unconditionally fires QUEST_LOG_UPDATE on every
    -- refresh and causes an infinite event loop!
    if not ExpandQuestHeader then return end
    local numShown = GetNumLogEntries()
    local hasCollapsed = false
    for i = 1, numShown do
        if C_QuestLog and C_QuestLog.GetInfo then
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            if ok and type(info) == "table" and info.isHeader and info.isCollapsed then
                hasCollapsed = true
                break
            end
        end
    end
    if hasCollapsed then
        local prev = FQL._isRefreshing
        FQL._isRefreshing = true
        pcall(ExpandQuestHeader, 0)
        FQL._isRefreshing = prev
    end
end

local function GetLogEntryInfo(index)
    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if ok and type(info) == "table" then
            local qid = SafeNum(info.questID) or 0
            local lvl = SafeNum(info.difficultyLevel) or 0
            if lvl <= 0 then
                lvl = SafeNum(info.level) or 0
            end
            if lvl <= 0 and qid > 0 and C_QuestLog.GetQuestDifficultyLevel then
                local ok2, dLvl = pcall(C_QuestLog.GetQuestDifficultyLevel, qid)
                if ok2 and SafeNum(dLvl) and dLvl > 0 then
                    lvl = dLvl
                end
            end
            return {
                logIndex = index,
                title = SafeStr(info.title) or "Unknown",
                level = lvl,
                suggestedGroup = SafeNum(info.suggestedGroup) or 0,
                isHeader = info.isHeader == true,
                isCollapsed = info.isCollapsed == true,
                isComplete = info.isComplete,
                frequency = SafeNum(info.frequency),
                questID = qid,
                isOnMap = info.isOnMap == true,
                hasLocalPOI = info.hasLocalPOI == true,
                isTask = info.isTask == true,
                isBounty = info.isBounty == true,
                isHidden = info.isHidden == true,
                isScaling = info.isScaling == true,
                difficultyLevel = SafeNum(info.difficultyLevel) or lvl,
            }
        end
    end
    if GetQuestLogTitle then
        local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, _, _, isOnMap, hasLocalPOI, isTask, isBounty, _, isHidden, isScaling = pcall(GetQuestLogTitle, index)
        if ok and SafeStr(title) then
            local qid = SafeNum(questID) or 0
            local lvl = SafeNum(level) or 0
            if lvl <= 0 and qid > 0 and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
                local ok2, dLvl = pcall(C_QuestLog.GetQuestDifficultyLevel, qid)
                if ok2 and SafeNum(dLvl) and dLvl > 0 then
                    lvl = dLvl
                end
            end
            return {
                logIndex = index,
                title = title,
                level = lvl,
                suggestedGroup = SafeNum(suggestedGroup) or 0,
                isHeader = isHeader == true or isHeader == 1,
                isCollapsed = isCollapsed == true or isCollapsed == 1,
                isComplete = SafeNum(isComplete),
                frequency = SafeNum(frequency),
                questID = qid,
                isOnMap = isOnMap == true or isOnMap == 1,
                hasLocalPOI = hasLocalPOI == true or hasLocalPOI == 1,
                isTask = isTask == true or isTask == 1,
                isBounty = isBounty == true or isBounty == 1,
                isHidden = isHidden == true or isHidden == 1,
                isScaling = isScaling == true or isScaling == 1,
                difficultyLevel = lvl,
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
    if not questID or questID <= 0 then return end
    local prev = FQL._isRefreshing
    FQL._isRefreshing = true
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        local cur = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        if cur ~= questID then
            pcall(C_QuestLog.SetSelectedQuest, questID)
        end
    elseif SelectQuestLogEntry then
        logIndex = SafeNum(logIndex) or GetLogIndexForQuest(questID)
        if logIndex and logIndex > 0 then
            pcall(SelectQuestLogEntry, logIndex)
        end
    end
    FQL._isRefreshing = prev
end

local function IsQuestCompleteOrFailed(questID, infoComplete)
    -- Rely on info.isComplete from C_QuestLog.GetInfo(index).
    -- Do NOT call C_QuestLog.IsComplete(questID) on every quest in the log, because
    -- uncached quests (e.g. id=26799) trigger QuestCache server queries that get rate-limited
    -- ("Deny" in QuestCache.log), firing QUEST_LOG_UPDATE in a 10Hz infinite loop and
    -- blocking Quest Giver Gossip dialogs!
    if infoComplete == 1 or infoComplete == true then
        return 1
    elseif infoComplete == -1 then
        return -1
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

local function GetDifficultyColor(level, questID)
    level = SafeNum(level) or 0
    if level <= 0 and questID and questID > 0 and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
        local ok, dLvl = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
        if ok and SafeNum(dLvl) and dLvl > 0 then
            level = dLvl
        end
    end

    local playerLevel = UnitLevel and SafeNum(UnitLevel("player")) or 1
    if playerLevel <= 0 then playerLevel = 1 end

    -- 1. Try native GetQuestDifficultyColor(level)
    if GetQuestDifficultyColor and level > 0 then
        local ok, c = pcall(GetQuestDifficultyColor, level)
        if ok and type(c) == "table" and c.r and c.g and c.b then
            return c.r, c.g, c.b
        end
    end

    -- 2. Try C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)
    if questID and questID > 0 and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer then
        local ok, diff = pcall(C_PlayerInfo.GetContentDifficultyQuestForPlayer, questID)
        if ok and diff and _G.GetDifficultyColor then
            local ok2, c = pcall(_G.GetDifficultyColor, diff)
            if ok2 and type(c) == "table" and c.r and c.g and c.b then
                return c.r, c.g, c.b
            end
        end
    end

    if level <= 0 then
        return 1.0, 0.82, 0.18
    end

    -- 3. Robust Classic / Modern level-differential calculation
    local levelDiff = level - playerLevel

    -- Determine trivial (grey) range
    local greyRange = 5
    if UnitQuestTrivialLevelRangeScaling then
        local ok, gr = pcall(UnitQuestTrivialLevelRangeScaling, "player")
        if ok and SafeNum(gr) and gr > 0 then
            greyRange = gr
        end
    elseif GetQuestGreenRange then
        local ok, gr = pcall(GetQuestGreenRange, playerLevel)
        if ok and SafeNum(gr) and gr > 0 then
            greyRange = gr
        end
    else
        if playerLevel <= 5 then
            greyRange = 2
        elseif playerLevel <= 39 then
            greyRange = math.floor(playerLevel / 10) + 3
        elseif playerLevel <= 59 then
            greyRange = math.floor(playerLevel / 5) - 1
        else
            greyRange = 9
        end
    end

    local qdc = _G.QuestDifficultyColors
    if levelDiff >= 5 then
        if qdc and qdc["impossible"] then return qdc["impossible"].r, qdc["impossible"].g, qdc["impossible"].b end
        return 1.00, 0.20, 0.20 -- Red (Impossible / Very Hard)
    elseif levelDiff >= 3 then
        if qdc and qdc["verydifficult"] then return qdc["verydifficult"].r, qdc["verydifficult"].g, qdc["verydifficult"].b end
        return 1.00, 0.50, 0.25 -- Orange (Hard)
    elseif levelDiff >= -2 then
        if qdc and qdc["difficult"] then return qdc["difficult"].r, qdc["difficult"].g, qdc["difficult"].b end
        return 1.00, 0.82, 0.18 -- Yellow (Normal)
    elseif -levelDiff <= greyRange then
        if qdc and qdc["standard"] then return qdc["standard"].r, qdc["standard"].g, qdc["standard"].b end
        return 0.25, 0.85, 0.25 -- Green (Easy)
    else
        if qdc and qdc["trivial"] then return qdc["trivial"].r, qdc["trivial"].g, qdc["trivial"].b end
        return 0.60, 0.60, 0.60 -- Grey (Trivial)
    end
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

    if GetQuestLogRewardXP then
        local ok, xp = pcall(GetQuestLogRewardXP, questID)
        if not ok or not SafeNum(xp) or xp <= 0 then
            ok, xp = pcall(GetQuestLogRewardXP)
        end
        if ok and SafeNum(xp) and xp > 0 then
            data.xp = xp
        end
    end

    if GetQuestLogRewardMoney then
        local ok, money = pcall(GetQuestLogRewardMoney, questID)
        if not ok or not SafeNum(money) or money <= 0 then
            ok, money = pcall(GetQuestLogRewardMoney)
        end
        if ok and SafeNum(money) and money > 0 then
            data.money = money
        end
    end

    if GetQuestLogRequiredMoney then
        local ok, reqMoney = pcall(GetQuestLogRequiredMoney, questID)
        if not ok or not SafeNum(reqMoney) then
            ok, reqMoney = pcall(GetQuestLogRequiredMoney)
        end
        if ok and SafeNum(reqMoney) and reqMoney > 0 then
            data.requiredMoney = reqMoney
        end
    end

    if GetQuestLogTimeLeft then
        local ok, timeLeft = pcall(GetQuestLogTimeLeft, logIndex)
        if ok and SafeNum(timeLeft) and timeLeft > 0 then
            data.timeLeft = timeLeft
        end
    end

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

local function ExecuteAbandonAllQuests()
    ExpandAllNativeHeaders()
    local numEntries = GetNumLogEntries()
    local quests = {}
    for i = numEntries, 1, -1 do
        local info = GetLogEntryInfo(i)
        if info and not info.isHeader and not info.isBounty and not info.isHidden and info.questID and info.questID > 0 then
            quests[#quests + 1] = { questID = info.questID, logIndex = i }
        end
    end

    for _, q in ipairs(quests) do
        local canAbandon = true
        if C_QuestLog and C_QuestLog.CanAbandonQuest then
            local ok, res = pcall(C_QuestLog.CanAbandonQuest, q.questID)
            if ok and res == false then
                canAbandon = false
            end
        end
        if canAbandon then
            SelectLogQuest(q.questID, q.logIndex)
            if C_QuestLog and C_QuestLog.SetAbandonQuest then
                pcall(C_QuestLog.SetAbandonQuest)
            elseif SetAbandonQuest then
                pcall(SetAbandonQuest)
            end
            if C_QuestLog and C_QuestLog.AbandonQuest then
                pcall(C_QuestLog.AbandonQuest)
            elseif AbandonQuest then
                pcall(AbandonQuest)
            end
        end
    end
end

local function AbandonAllQuests()
    if StaticPopupDialogs and not StaticPopupDialogs["SHUPAZ_FQL_ABANDON_ALL_QUESTS"] then
        StaticPopupDialogs["SHUPAZ_FQL_ABANDON_ALL_QUESTS"] = {
            text = "Are you sure you want to abandon ALL quests in your Quest Log?",
            button1 = YES or "Yes",
            button2 = NO or "No",
            OnAccept = function()
                ExecuteAbandonAllQuests()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    if StaticPopup_Show then
        StaticPopup_Show("SHUPAZ_FQL_ABANDON_ALL_QUESTS")
    else
        ExecuteAbandonAllQuests()
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

    -- Force small (windowed) World Map without embedded quest log
    if FQL.SetQuestLogCVarClosed then
        FQL.SetQuestLogCVarClosed()
    end
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "miniWorldMap", "1")
    elseif SetCVar then
        pcall(SetCVar, "miniWorldMap", "1")
    end

    if WorldMapFrame and WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() then
        if WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.Minimize then
            pcall(WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.Minimize, WorldMapFrame.BorderFrame.MaximizeMinimizeFrame)
        elseif WorldMapFrame.Minimize then
            pcall(WorldMapFrame.Minimize, WorldMapFrame)
        end
    end

    if C_Map and C_Map.OpenWorldMap then
        pcall(C_Map.OpenWorldMap, mapID)
    elseif ToggleWorldMap then
        if not (WorldMapFrame and WorldMapFrame:IsShown()) then
            pcall(ToggleWorldMap)
        end
        if mapID and WorldMapFrame and WorldMapFrame.SetMapID then
            pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
        end
    end

    -- Ensure WorldMapFrame is minimized if OpenWorldMap restored maximized state
    if WorldMapFrame and WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() then
        if WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.Minimize then
            pcall(WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.Minimize, WorldMapFrame.BorderFrame.MaximizeMinimizeFrame)
        elseif WorldMapFrame.Minimize then
            pcall(WorldMapFrame.Minimize, WorldMapFrame)
        end
    end

    -- Keep Forever Quest Log open side-by-side with the small World Map
    if FQL.frame then
        if not FQL.frame:IsShown() then
            FQL.frame:Show()
        elseif FQL.UpdateDefaultPanelPosition then
            FQL:UpdateDefaultPanelPosition()
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
FQL.AbandonAllQuests          = AbandonAllQuests
FQL.ShareSelectedQuest        = ShareSelectedQuest
FQL.ShowQuestOnWorldMap       = ShowQuestOnWorldMap
