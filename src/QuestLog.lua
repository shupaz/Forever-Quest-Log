local ADDON_NAME, FQL = ...

local SafeNum                   = FQL.SafeNum
local SafeStr                   = FQL.SafeStr
local IsSecret                  = FQL.IsSecret
local CanChangeFrame            = FQL.CanChangeFrame
local SetBackdrop               = FQL.SetBackdrop
local AddClassicParchment        = FQL.AddClassicParchment
local FormatNumber              = FQL.FormatNumber
local PlayOpenSound             = FQL.PlayOpenSound
local PlayCloseSound            = FQL.PlayCloseSound
local PlayClickSound            = FQL.PlayClickSound

local GetMaxQuests              = FQL.GetMaxQuests
local ExpandAllNativeHeaders    = FQL.ExpandAllNativeHeaders
local GetNumLogEntries          = FQL.GetNumLogEntries
local GetLogEntryInfo           = FQL.GetLogEntryInfo
local GetLogIndexForQuest       = FQL.GetLogIndexForQuest
local SelectLogQuest            = FQL.SelectLogQuest
local IsQuestCompleteOrFailed   = FQL.IsQuestCompleteOrFailed
local IsQuestWatchedByID        = FQL.IsQuestWatchedByID
local SetQuestWatchedByID       = FQL.SetQuestWatchedByID
local ToggleQuestWatchByID      = FQL.ToggleQuestWatchByID
local IsQuestSuperTracked       = FQL.IsQuestSuperTracked
local SetQuestSuperTracked      = FQL.SetQuestSuperTracked
local GetQuestTagDetails        = FQL.GetQuestTagDetails
local GetDifficultyColor        = FQL.GetDifficultyColor
local GetQuestTextAndObjectives = FQL.GetQuestTextAndObjectives
local GetQuestRewardsData       = FQL.GetQuestRewardsData

local TryInsertQuestChatLink    = FQL.TryInsertQuestChatLink
local InsertOrOpenQuestChatLink = FQL.InsertOrOpenQuestChatLink
local GetQuestWebURL            = FQL.GetQuestWebURL
local AbandonSelectedQuest      = FQL.AbandonSelectedQuest
local AbandonAllQuests          = FQL.AbandonAllQuests
local ShareSelectedQuest        = FQL.ShareSelectedQuest
local ShowQuestOnWorldMap       = FQL.ShowQuestOnWorldMap

local MIN_SCALE                 = FQL.MIN_SCALE or 0.6
local MAX_SCALE                 = FQL.MAX_SCALE or 1.6
local DEFAULT_WIDTH             = FQL.DEFAULT_WIDTH or 730
local DEFAULT_HEIGHT            = FQL.DEFAULT_HEIGHT or 520

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

        eb:SetScript("OnKeyDown", function(self, key)
            if key == "C" and IsControlKeyDown and IsControlKeyDown() then
                box.hint:SetText("|cff00ff00Copied to clipboard!|r")
            end
        end)
    end

    box.title:SetText(titleText or "Quest Link")
    box.hint:SetText("Press Ctrl+C to copy:")
    box.editBox:SetText(urlText or "")
    box:Show()
    box.editBox:SetFocus()
    box.editBox:HighlightText()
end

function FQL:GetOrCreateLinkHoverCard()
    if self.linkHoverCard then return self.linkHoverCard end

    local card = CreateFrame("Frame", "shupaz_ForeverQuestLogHoverCard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.linkHoverCard = card
    card:SetSize(350, 66)
    card:SetFrameStrata("TOOLTIP")
    card:SetToplevel(true)
    card:EnableMouse(true)
    card:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "shupaz_ForeverQuestLogHoverCard")

    SetBackdrop(card, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    card:SetBackdropColor(0.07, 0.06, 0.045, 0.98)
    card:SetBackdropBorderColor(0.85, 0.68, 0.28, 1)

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.title = title
    title:SetPoint("TOPLEFT", 10, -7)
    title:SetTextColor(1, 0.82, 0)
    title:SetText("Wowhead Quest Link")

    local hint = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.hint = hint
    hint:SetPoint("TOPRIGHT", -10, -7)
    hint:SetTextColor(0.35, 1, 0.35)
    hint:SetText("Press Ctrl+C to copy")

    local eb = CreateFrame("EditBox", nil, card, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card.editBox = eb
    eb:SetSize(330, 22)
    eb:SetPoint("TOPLEFT", 10, -24)
    eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(6, 6, 0, 0)
    SetBackdrop(eb, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    eb:SetBackdropColor(0.04, 0.04, 0.03, 1)
    eb:SetBackdropBorderColor(0.55, 0.45, 0.25, 1)

    local subHint = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.subHint = subHint
    subHint:SetPoint("BOTTOMLEFT", 10, 5)
    subHint:SetText("Click to pin | Shift-Click for chat link")
    subHint:SetTextColor(0.65, 0.60, 0.50)

    eb:SetScript("OnKeyDown", function(self, key)
        if key == "C" and IsControlKeyDown and IsControlKeyDown() then
            card.hint:SetText("|cff00ff00Copied to clipboard!|r")
            card.hint:SetTextColor(0.2, 1.0, 0.2)
        elseif key == "ESCAPE" then
            self:ClearFocus()
            card:Hide()
        end
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        card:Hide()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        card:Hide()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        if not card.isPinned and not card:IsMouseOver() and (not card.anchor or not card.anchor:IsMouseOver()) then
            card:Hide()
        end
    end)

    card:SetScript("OnEnter", function(self)
        self.mouseInside = true
    end)
    card:SetScript("OnLeave", function(self)
        self.mouseInside = false
        if not self.isPinned then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    if not card.isPinned and not card:IsMouseOver() and (not card.anchor or not card.anchor:IsMouseOver()) then
                        card.editBox:ClearFocus()
                        card:Hide()
                    end
                end)
            else
                card.editBox:ClearFocus()
                card:Hide()
            end
        end
    end)

    card:Hide()
    return card
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
                FQL:ShowCopyPopup(questEntry.title, GetQuestWebURL(questID))
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

local QL_FontCache = setmetatable({}, { __mode = "k" })

local function ApplyScaledFont(fs, defaultFont, defaultSize, defaultFlags)
    if not fs or type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then return end
    local ok, curFont, curSize, curFlags = pcall(fs.GetFont, fs)
    if not ok then return end
    local cached = QL_FontCache[fs]
    if not cached then
        local sz = SafeNum(curSize) or defaultSize or 12
        if sz <= 0 then sz = defaultSize or 12 end
        cached = {
            font = SafeStr(curFont) or defaultFont or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"),
            size = sz,
            flags = SafeStr(curFlags) or defaultFlags or "",
        }
        QL_FontCache[fs] = cached
    end
    local scale = (shupazForeverQuestLogDB and SafeNum(shupazForeverQuestLogDB.questLogFontScale)) or 1.0
    if scale < 0.5 then scale = 0.5 elseif scale > 2.5 then scale = 2.5 end
    local targetSize = math.max(8, math.floor(cached.size * scale + 0.5))
    if curFont ~= cached.font or curSize ~= targetSize then
        pcall(fs.SetFont, fs, cached.font, targetSize, cached.flags)
    end
end

function FQL:SetQuestLogFontScale(scale)
    scale = tonumber(scale) or 1.0
    if scale < 0.80 then scale = 0.80 end
    if scale > 1.60 then scale = 1.60 end
    scale = math.floor(scale * 100 + 0.5) / 100
    if shupazForeverQuestLogDB then
        shupazForeverQuestLogDB.questLogFontScale = scale
    end
    self:Refresh()
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

-- Dynamically inspect Blizzard's UIPanelWindows registry and ShowUIPanel/HideUIPanel
-- so we never have to hardcode individual frame names.
local hookedBlizzardPanels = {}

local function IsFrameShownSafe(f)
    if not f or type(f.IsShown) ~= "function" then return false end
    local ok, shown = pcall(f.IsShown, f)
    return ok and shown == true
end

local function GetUIPanelWidthAndArea(frameName, f, info)
    -- Small (windowed / minimized) WorldMapFrame can sit side-by-side with Forever Quest Log
    if f == _G.WorldMapFrame or frameName == "WorldMapFrame" then
        local isMax = false
        if f and type(f.IsMaximized) == "function" then
            local okM, m = pcall(f.IsMaximized, f)
            if okM and m == true then isMax = true end
        end
        if not isMax then
            local okW, width = pcall(f.GetWidth, f)
            local wNum = (okW and SafeNum(width) and width > 100) and width or 702
            return wNum, false
        else
            return 1000, true
        end
    end

    local area = (type(info) == "table" and SafeStr(info.area)) or "left"
    local wNum = nil

    local okW, width = pcall(f.GetWidth, f)
    if okW and SafeNum(width) and width > 100 then
        wNum = width
    end
    if not wNum and type(info) == "table" then
        wNum = SafeNum(info.width)
        local extra = SafeNum(info.extraWidth)
        if wNum and extra then wNum = wNum + extra end
    end
    if not wNum then
        wNum = (area == "doublewide" or area == "full") and 800 or 352
    end

    local isWide = (area == "doublewide" or area == "full" or wNum >= 650)
    return wNum, isWide
end

local function GetPanelRightEdge(frameName, f, info, myScale)
    local fScale = 1
    if f.GetEffectiveScale then
        local okS, s = pcall(f.GetEffectiveScale, f)
        if okS and SafeNum(s) and s > 0 then fScale = s end
    end

    local okR, right = pcall(f.GetRight, f)
    local rNum = okR and SafeNum(right) or nil
    if rNum and rNum > 0 then
        return math.floor((rNum * fScale) / (myScale > 0 and myScale or 1))
    end

    local wNum = GetUIPanelWidthAndArea(frameName, f, info)
    return math.floor(((16 + wNum) * fScale) / (myScale > 0 and myScale or 1))
end

local function HookPanelHideOnce(f)
    if not f or hookedBlizzardPanels[f] or type(f.HookScript) ~= "function" then return end
    hookedBlizzardPanels[f] = true
    f:HookScript("OnShow", function()
        if FQL.frame and IsFrameShownSafe(FQL.frame) then
            FQL:UpdateDefaultPanelPosition()
        end
    end)
    f:HookScript("OnHide", function()
        if FQL.frame and IsFrameShownSafe(FQL.frame) then
            FQL:UpdateDefaultPanelPosition()
        end
    end)
    if f == _G.WorldMapFrame then
        f:HookScript("OnSizeChanged", function()
            if FQL.frame and IsFrameShownSafe(FQL.frame) then
                FQL:UpdateDefaultPanelPosition()
            end
        end)
    end
end

local function GetActiveBlizzardPanels()
    local narrowPanels = {}
    local widePanels = {}
    local seen = {}

    local function CheckFrame(frameName, f, info)
        if not f or f == FQL.frame or seen[f] or not IsFrameShownSafe(f) then return end
        seen[f] = true
        HookPanelHideOnce(f)
        local _, isWide = GetUIPanelWidthAndArea(frameName, f, info)
        if isWide then
            widePanels[#widePanels + 1] = { name = frameName, frame = f, info = info }
        else
            narrowPanels[#narrowPanels + 1] = { name = frameName, frame = f, info = info }
        end
    end

    -- 1. Check UIParent's active slot attributes first
    if UIParent and UIParent.GetAttribute then
        for _, slot in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
            local ok, slotFrame = pcall(UIParent.GetAttribute, UIParent, slot)
            if ok and type(slotFrame) == "table" then
                local name = slotFrame.GetName and slotFrame:GetName()
                local info = (name and _G.UIPanelWindows and _G.UIPanelWindows[name]) or { area = slot }
                CheckFrame(name or slot, slotFrame, info)
            end
        end
    end

    -- 2. Also scan Blizzard's UIPanelWindows table for any shown panel
    if type(_G.UIPanelWindows) == "table" then
        for frameName, info in pairs(_G.UIPanelWindows) do
            local f = _G[frameName]
            if f then
                CheckFrame(frameName, f, info)
            end
        end
    end

    return narrowPanels, widePanels
end

function FQL:PrepareForDefaultPanelOpen()
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.useDefaultPosition == false then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local narrowPanels, widePanels = GetActiveBlizzardPanels()

    for _, entry in ipairs(widePanels) do
        if CanChangeFrame(entry.frame) then
            if HideUIPanel then
                pcall(HideUIPanel, entry.frame)
            else
                pcall(entry.frame.Hide, entry.frame)
            end
        end
    end

    if #narrowPanels >= 2 then
        for i = 2, #narrowPanels do
            local f = narrowPanels[i].frame
            if CanChangeFrame(f) then
                if HideUIPanel then
                    pcall(HideUIPanel, f)
                else
                    pcall(f.Hide, f)
                end
            end
        end
    end
end

function FQL:UpdateDefaultPanelPosition()
    if not self.frame then return end
    if shupazForeverQuestLogDB and shupazForeverQuestLogDB.useDefaultPosition == false then
        return
    end

    local narrowPanels, widePanels = GetActiveBlizzardPanels()

    if IsFrameShownSafe(self.frame) and (#widePanels > 0 or #narrowPanels >= 2) then
        self:Close()
        return
    end

    local xOff = 16
    local yOff = -116
    local myScale = 1
    if self.frame.GetEffectiveScale then
        local okS, s = pcall(self.frame.GetEffectiveScale, self.frame)
        if okS and SafeNum(s) and s > 0 then myScale = s end
    end

    for _, entry in ipairs(narrowPanels) do
        local rightEdge = GetPanelRightEdge(entry.name, entry.frame, entry.info, myScale)
        if rightEdge + 12 > xOff then
            xOff = rightEdge + 12
        end
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOff, yOff)
end

function FQL:HookKnownPanels()
    for _, name in ipairs({ "GameMenuFrame", "SettingsPanel" }) do
        local f = _G[name]
        if f and not hookedBlizzardPanels[f] and type(f.HookScript) == "function" then
            hookedBlizzardPanels[f] = true
            f:HookScript("OnShow", function()
                FQL:Close()
            end)
        end
    end
end

function FQL:SetupDefaultPanelHooks()
    self:HookKnownPanels()
    if self._defaultPanelHooksInstalled then return end
    self._defaultPanelHooksInstalled = true

    if type(_G.ShowUIPanel) == "function" then
        hooksecurefunc("ShowUIPanel", function(panelFrame)
            if panelFrame and panelFrame ~= FQL.frame then
                HookPanelHideOnce(panelFrame)
            end
            if FQL.frame and IsFrameShownSafe(FQL.frame) then
                FQL:UpdateDefaultPanelPosition()
            end
        end)
    end

    if type(_G.HideUIPanel) == "function" then
        hooksecurefunc("HideUIPanel", function()
            if FQL.frame and IsFrameShownSafe(FQL.frame) then
                FQL:UpdateDefaultPanelPosition()
            end
        end)
    end

    if type(_G.UpdateUIPanelPositions) == "function" then
        hooksecurefunc("UpdateUIPanelPositions", function()
            if FQL.frame and IsFrameShownSafe(FQL.frame) then
                FQL:UpdateDefaultPanelPosition()
            end
        end)
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

    _G["shupaz_ForeverQuestLogFrame"] = frame

    local alreadyInSpecial = false
    if UISpecialFrames then
        for _, name in ipairs(UISpecialFrames) do
            if name == "shupaz_ForeverQuestLogFrame" then
                alreadyInSpecial = true
                break
            end
        end
        if not alreadyInSpecial then
            tinsert(UISpecialFrames, "shupaz_ForeverQuestLogFrame")
        end
    end

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
        if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.lockWindow ~= false then return end
        self.isDraggingFQL = true
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        if not self.isDraggingFQL then return end
        self.isDraggingFQL = false
        self:StopMovingOrSizing()
        FQL:SavePosition()
    end)

    frame:SetScript("OnShow", function()
        PlayOpenSound()
        FQL:SetupDefaultPanelHooks()
        if not shupazForeverQuestLogDB or shupazForeverQuestLogDB.useDefaultPosition ~= false then
            FQL:PrepareForDefaultPanelOpen()
            FQL:UpdateDefaultPanelPosition()
        end
        FQL:Refresh()
    end)
    frame:SetScript("OnHide", function()
        PlayCloseSound()
        if FQL.contextMenu then FQL.contextMenu:Hide() end
        if FQL.linkHoverCard then
            FQL.linkHoverCard.editBox:ClearFocus()
            FQL.linkHoverCard:Hide()
        end
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

    -- ========================================================
    -- DEDICATED WOWHEAD URL BAR (Dockable at Bottom or Top)
    -- ========================================================
    local wowheadBar = CreateFrame("Frame", "shupaz_ForeverQuestLogWowheadBar", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.wowheadBar = wowheadBar
    wowheadBar:SetHeight(26)
    SetBackdrop(wowheadBar, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    wowheadBar:SetBackdropColor(0.07, 0.06, 0.045, 0.98)
    wowheadBar:SetBackdropBorderColor(0.55, 0.43, 0.22, 1)

    local whLabel = wowheadBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wowheadBar.label = whLabel
    whLabel:SetPoint("LEFT", 10, 0)
    whLabel:SetText("|cffffd200Wowhead URL:|r")

    local whHint = wowheadBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wowheadBar.hint = whHint
    whHint:SetPoint("RIGHT", -10, 0)
    whHint:SetText("Hover or Click + Ctrl+C to copy")
    whHint:SetTextColor(0.78, 0.74, 0.62)

    local whEditBox = CreateFrame("EditBox", "shupaz_ForeverQuestLogWowheadEditBox", wowheadBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    wowheadBar.editBox = whEditBox
    whEditBox:SetHeight(20)
    whEditBox:SetPoint("LEFT", whLabel, "RIGHT", 8, 0)
    whEditBox:SetPoint("RIGHT", whHint, "LEFT", -10, 0)
    whEditBox:SetFontObject("ChatFontNormal")
    whEditBox:SetTextColor(0.45, 0.88, 1.0)
    whEditBox:SetAutoFocus(false)
    whEditBox:SetTextInsets(8, 8, 0, 0)
    SetBackdrop(whEditBox, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 8, 2)
    whEditBox:SetBackdropColor(0.03, 0.03, 0.025, 1)
    whEditBox:SetBackdropBorderColor(0.42, 0.34, 0.18, 1)

    whEditBox:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.95, 0.78, 0.28, 1)
        if self.currentURL and self.currentURL ~= "" then
            whHint:SetText("|cff55ff55Press Ctrl+C to copy|r")
            self:SetFocus()
            self:HighlightText()
        end
    end)
    whEditBox:SetScript("OnLeave", function(self)
        if not self.isPinnedFocus then
            self:SetBackdropBorderColor(0.42, 0.34, 0.18, 1)
            self:ClearFocus()
            whHint:SetText("Hover or Click + Ctrl+C to copy")
            whHint:SetTextColor(0.78, 0.74, 0.62)
        end
    end)
    whEditBox:SetScript("OnMouseDown", function(self)
        self.isPinnedFocus = true
    end)
    whEditBox:SetScript("OnMouseUp", function(self)
        if self.currentURL and self.currentURL ~= "" then
            self:SetFocus()
            self:HighlightText()
            whHint:SetText("|cff55ff55Press Ctrl+C to copy|r")
        end
    end)
    whEditBox:SetScript("OnEditFocusLost", function(self)
        self.isPinnedFocus = false
        self:SetBackdropBorderColor(0.42, 0.34, 0.18, 1)
        self:HighlightText(0, 0)
        whHint:SetText("Hover or Click + Ctrl+C to copy")
        whHint:SetTextColor(0.78, 0.74, 0.62)
    end)
    whEditBox:SetScript("OnEscapePressed", function(self)
        self.isPinnedFocus = false
        self:ClearFocus()
    end)
    whEditBox:SetScript("OnEnterPressed", function(self)
        self.isPinnedFocus = false
        self:ClearFocus()
    end)
    whEditBox:SetScript("OnChar", function(self)
        if self.currentURL then
            self:SetText(self.currentURL)
            self:HighlightText()
        end
    end)
    whEditBox:SetScript("OnKeyDown", function(self, key)
        if key == "C" and IsControlKeyDown and IsControlKeyDown() then
            whHint:SetText("|cff00ff00Copied to clipboard!|r")
        elseif key == "ESCAPE" then
            self.isPinnedFocus = false
            self:ClearFocus()
        end
    end)

    -- Clickable Quest Title (supports hover tooltip, click to copy URL, shift-click for chat link)
    local dTitleBtn = CreateFrame("Button", nil, detailContent)
    frame.detailTitleBtn = dTitleBtn
    dTitleBtn:SetAllPoints(dTitle)
    dTitleBtn:SetScript("OnEnter", function(self)
        local qID = FQL.selectedQuestID
        if not GameTooltip or not qID then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, -4)
        GameTooltip:SetText(FQL.selectedQuestTitle or "Quest", 1, 0.82, 0)
        GameTooltip:AddLine(GetQuestWebURL(qID), 0.3, 0.8, 1, false)
        GameTooltip:AddLine("Click to open copy popup | Shift-Click to link in chat", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    dTitleBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    dTitleBtn:SetScript("OnClick", function(self, button)
        local qID = FQL.selectedQuestID
        if not qID then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            InsertOrOpenQuestChatLink(qID, FQL.selectedQuestTitle, FQL.selectedQuestLevel)
            return
        end
        PlayClickSound()
        FQL:ShowCopyPopup(FQL.selectedQuestTitle, GetQuestWebURL(qID))
    end)

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
            if IsShiftKeyDown and IsShiftKeyDown() then
                if AbandonAllQuests then
                    AbandonAllQuests()
                end
                return
            end
            if FQL.selectedQuestID then
                AbandonSelectedQuest(FQL.selectedQuestID, FQL.selectedQuestTitle)
            end
        end,
        ABANDON_QUEST or "Abandon Quest",
        "Abandon the selected quest.\n|cffffd200Shift-Click:|r Abandon ALL quests in your Quest Log."
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
    self:UpdateWowheadBarLayout()
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

function FQL:UpdateWowheadBarLayout()
    local frame = self.frame
    if not frame or not frame.wowheadBar or not frame.leftPane or not frame.rightPane then return end

    local pos = (shupazForeverQuestLogDB and shupazForeverQuestLogDB.wowheadBarPosition) or "HIDE"
    local bar = frame.wowheadBar
    bar:ClearAllPoints()
    frame.leftPane:ClearAllPoints()
    frame.rightPane:ClearAllPoints()

    if pos == "TOP" then
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -56)
        bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -56)
        bar:Show()

        frame.leftPane:SetPoint("TOPLEFT", 8, -85)
        frame.leftPane:SetPoint("BOTTOMLEFT", 8, 30)
        frame.rightPane:SetPoint("TOPLEFT", frame.leftPane, "TOPRIGHT", 6, 0)
        frame.rightPane:SetPoint("BOTTOMRIGHT", -8, 30)
    elseif pos == "HIDE" then
        bar:Hide()

        frame.leftPane:SetPoint("TOPLEFT", 8, -60)
        frame.leftPane:SetPoint("BOTTOMLEFT", 8, 30)
        frame.rightPane:SetPoint("TOPLEFT", frame.leftPane, "TOPRIGHT", 6, 0)
        frame.rightPane:SetPoint("BOTTOMRIGHT", -8, 30)
    else
        bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 30)
        bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 30)
        bar:Show()

        frame.leftPane:SetPoint("TOPLEFT", 8, -60)
        frame.leftPane:SetPoint("BOTTOMLEFT", 8, 59)
        frame.rightPane:SetPoint("TOPLEFT", frame.leftPane, "TOPRIGHT", 6, 0)
        frame.rightPane:SetPoint("BOTTOMRIGHT", -8, 59)
    end
end

function FQL:SetWowheadBarPosition(pos)
    if pos ~= "TOP" and pos ~= "BOTTOM" and pos ~= "HIDE" then
        pos = "HIDE"
    end
    if shupazForeverQuestLogDB then
        shupazForeverQuestLogDB.wowheadBarPosition = pos
    end
    self:UpdateWowheadBarLayout()
    if self.optionsPanel and self.optionsPanel.RefreshControls then
        self.optionsPanel:RefreshControls()
    end
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
    row.trackCheck:SetPoint("TOPRIGHT", -4, -4)
    row.trackCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.statusText:SetPoint("TOPRIGHT", row.trackCheck, "TOPLEFT", -2, 0)
    row.statusText:SetJustifyH("RIGHT")

    row.titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.titleText:SetPoint("TOPLEFT", 12, -4)
    row.titleText:SetJustifyH("LEFT")
    row.titleText:SetWordWrap(true)

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
            PlayClickSound()
            FQL:SelectQuest(self.questEntry.questID, self.questEntry.logIndex)
            ShowQuestOnWorldMap(self.questEntry.questID)
        end
    end)

    row:SetScript("OnEnter", function(self)
        if self.isHeader or not self.questEntry or not GameTooltip then return end
        if shupazForeverQuestLogDB and shupazForeverQuestLogDB.showTooltips == false then return end
        local q = self.questEntry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local r, g, b = GetDifficultyColor(q.level, q.questID)
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
        GameTooltip:AddLine("Left-Click: View Details | Double-Click: Show Map | Shift-Click: Track / Link | Right-Click: Menu", 0.55, 0.55, 0.55, true)
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
                if (not info.level or info.level <= 0) and info.questID and info.questID > 0 and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
                    local ok, dLvl = pcall(C_QuestLog.GetQuestDifficultyLevel, info.questID)
                    if ok and SafeNum(dLvl) and dLvl > 0 then
                        info.level = dLvl
                        info.difficultyLevel = dLvl
                    end
                end
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

function FQL:SetAllHeadersCollapsed(shouldCollapse)
    if not shupazForeverQuestLogCharDB then return end
    shupazForeverQuestLogCharDB.collapsedHeaders = shupazForeverQuestLogCharDB.collapsedHeaders or {}
    local collapsed = shupazForeverQuestLogCharDB.collapsedHeaders
    wipe(collapsed)
    if shouldCollapse then
        local sections = self:BuildStructuredLog()
        for _, sec in ipairs(sections) do
            if sec.title then
                collapsed[sec.title] = true
            end
        end
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
    if frame.countText then
        ApplyScaledFont(frame.countText)
    end
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
            hRow.collapseIcon:ClearAllPoints()
            hRow.collapseIcon:SetPoint("LEFT", 4, 0)
            hRow.collapseIcon:SetTexture(isSecCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            hRow.collapseIcon:Show()
            hRow.trackCheck:Hide()
            hRow.statusText:ClearAllPoints()
            hRow.statusText:SetPoint("RIGHT", -6, 0)
            ApplyScaledFont(hRow.statusText)
            hRow.statusText:SetText("|cffb8a582(" .. tostring(#matchingQuests) .. ")|r")
            hRow.titleText:ClearAllPoints()
            hRow.titleText:SetPoint("LEFT", 22, 0)
            hRow.titleText:SetPoint("RIGHT", hRow.statusText, "LEFT", -4, 0)
            hRow.titleText:SetWordWrap(false)
            ApplyScaledFont(hRow.titleText)
            hRow.titleText:SetText(sec.title)
            hRow.titleText:SetTextColor(1.0, 0.82, 0.18)
            local hStringHeight = math.ceil(hRow.titleText:GetStringHeight() or 14)
            local hRowHeight = math.max(22, hStringHeight + 6)
            hRow:SetHeight(hRowHeight)
            hRow:Show()
            yOffset = yOffset + hRowHeight + 1

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
                    local r, g, b = GetDifficultyColor(q.level, q.questID)

                    if isSelected then
                        qRow.bg:SetColorTexture(0.55, 0.42, 0.16, 0.48)
                        qRow.bg:Show()
                        self.selectedQuestTitle = q.title
                    else
                        qRow.bg:Hide()
                    end

                    qRow.collapseIcon:Hide()

                    if watched then
                        qRow.trackCheck:ClearAllPoints()
                        qRow.trackCheck:SetPoint("TOPRIGHT", qRow, "TOPRIGHT", -4, -4)
                        qRow.trackCheck:Show()
                        if superTracked then
                            qRow.trackCheck:SetVertexColor(1.0, 0.85, 0.2)
                        else
                            qRow.trackCheck:SetVertexColor(0.85, 0.85, 0.85)
                        end
                        qRow.statusText:ClearAllPoints()
                        qRow.statusText:SetPoint("TOPRIGHT", qRow.trackCheck, "TOPLEFT", -2, 0)
                    else
                        qRow.trackCheck:Hide()
                        qRow.statusText:ClearAllPoints()
                        qRow.statusText:SetPoint("TOPRIGHT", qRow, "TOPRIGHT", -4, -4)
                    end

                    ApplyScaledFont(qRow.statusText)
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

                    local rightPad = 6
                    if watched then
                        rightPad = 22
                    end
                    local statusTextStr = qRow.statusText:GetText()
                    if statusTextStr and statusTextStr ~= "" then
                        local sWidth = qRow.statusText:GetStringWidth() or 0
                        rightPad = rightPad + sWidth + 4
                    end

                    local availWidth = math.max(120, rowWidth - 12 - rightPad)

                    qRow.titleText:ClearAllPoints()
                    qRow.titleText:SetPoint("TOPLEFT", qRow, "TOPLEFT", 12, -4)
                    qRow.titleText:SetWidth(availWidth)
                    qRow.titleText:SetWordWrap(true)
                    ApplyScaledFont(qRow.titleText)
                    qRow.titleText:SetText(prefix .. q.title)
                    qRow.titleText:SetTextColor(r, g, b)

                    local stringHeight = math.ceil(qRow.titleText:GetStringHeight() or 14)
                    local rowHeight = math.max(22, stringHeight + 8)
                    qRow:SetHeight(rowHeight)

                    qRow:Show()
                    yOffset = yOffset + rowHeight
                end
            end

            yOffset = yOffset + 3
        end
    end

    for i = rowIndex + 1, #frame.listRows do
        frame.listRows[i]:Hide()
    end

    frame.collapseAllBtn.icon:SetTexture(anyExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    if frame.emptyListText then
        ApplyScaledFont(frame.emptyListText)
    end
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
        self.selectedQuestTitle = nil
        self.selectedQuestLevel = nil
        frame.detailScroll:Hide()
        ApplyScaledFont(frame.noSelectionText)
        frame.noSelectionText:Show()
        frame.abandonBtn:Disable()
        frame.shareBtn:Disable()
        frame.trackBtn:Disable()
        frame.mapBtn:Disable()
        if frame.wowheadBar and frame.wowheadBar.editBox then
            frame.wowheadBar.editBox.currentURL = ""
            frame.wowheadBar.editBox:SetText("Select a quest to view its Wowhead URL")
            frame.wowheadBar.editBox:SetTextColor(0.55, 0.50, 0.42)
        end
        if self.linkHoverCard then
            self.linkHoverCard.editBox:ClearFocus()
            self.linkHoverCard:Hide()
        end
        return
    end

    self.selectedQuestTitle = qEntry.title
    self.selectedQuestLevel = qEntry.level
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

    ApplyScaledFont(frame.detailTitle)
    ApplyScaledFont(frame.detailMeta)
    ApplyScaledFont(frame.detailObjSummary)
    ApplyScaledFont(frame.detailObjLines)
    ApplyScaledFont(frame.detailDescHeader)
    ApplyScaledFont(frame.detailDescText)
    ApplyScaledFont(frame.detailRewardsHeader)
    ApplyScaledFont(frame.detailChoiceLabel)
    ApplyScaledFont(frame.detailFixedLabel)
    ApplyScaledFont(frame.detailSpellLabel)
    ApplyScaledFont(frame.detailXPLine)
    ApplyScaledFont(frame.detailMoneyLine)

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

    -- Update Dedicated Wowhead URL Bar
    local questUrl = GetQuestWebURL(questID)
    if frame.wowheadBar and frame.wowheadBar.editBox then
        local eb = frame.wowheadBar.editBox
        eb.currentURL = questUrl
        eb:SetTextColor(0.45, 0.88, 1.0)
        eb:SetText(questUrl)
        if eb:HasFocus() then
            eb:HighlightText()
        end
    end

    -- Title
    local titleRightPad = frame.specialItemBtn:IsShown() and 44 or 0
    frame.detailTitle:ClearAllPoints()
    frame.detailTitle:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
    frame.detailTitle:SetWidth(contentWidth - titleRightPad)
    frame.detailTitle:SetWordWrap(true)
    frame.detailTitle:SetText(qEntry.title)
    frame.detailTitle:Show()
    if frame.detailTitleBtn then
        frame.detailTitleBtn:ClearAllPoints()
        frame.detailTitleBtn:SetAllPoints(frame.detailTitle)
    end
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
            ApplyScaledFont(btn.name)
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
    if self._isRefreshing then return end
    self._isRefreshing = true
    self:RefreshQuestList()
    self:RefreshQuestDetail()
    self._isRefreshing = false
end

