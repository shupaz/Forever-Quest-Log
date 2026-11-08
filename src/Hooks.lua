local ADDON_NAME, FQL = ...

local CanChangeFrame = FQL.CanChangeFrame

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

    -- Ensure Escape closes the Quest Log window seamlessly
    if type(_G.CloseSpecialWindows) == "function" then
        hooksecurefunc("CloseSpecialWindows", function()
            if FQL.frame and FQL.frame:IsShown() then
                FQL.frame:Hide()
            end
        end)
    end

    if type(_G.CloseAllWindows) == "function" then
        hooksecurefunc("CloseAllWindows", function()
            if FQL.frame and FQL.frame:IsShown() then
                FQL.frame:Hide()
            end
        end)
    end

    if type(_G.ToggleGameMenu) == "function" then
        hooksecurefunc("ToggleGameMenu", function()
            if FQL.frame and FQL.frame:IsShown() then
                FQL.frame:Hide()
                if _G.GameMenuFrame and _G.GameMenuFrame:IsShown() then
                    if HideUIPanel then
                        pcall(HideUIPanel, _G.GameMenuFrame)
                    else
                        pcall(_G.GameMenuFrame.Hide, _G.GameMenuFrame)
                    end
                end
            end
        end)
    end
end



-- ============================================================
-- Export Hooks to FQL Namespace
-- ============================================================

FQL.SetQuestLogCVarClosed      = SetQuestLogCVarClosed
FQL.GetMapSidePanelToggle      = GetMapSidePanelToggle
FQL.SuppressMapQuestLog        = SuppressMapQuestLog
FQL.UpdateKeybindOverrides     = UpdateKeybindOverrides
FQL.InitializeMicroMenuButtons = InitializeMicroMenuButtons
FQL.SetupMapAndBindingHooks    = SetupMapAndBindingHooks
