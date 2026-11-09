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

local hookedMapFrames = {}

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
        if not hookedMapFrames[toggle] then
            hookedMapFrames[toggle] = true
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
        if not hookedMapFrames[_G.QuestMapFrame] then
            hookedMapFrames[_G.QuestMapFrame] = true
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
        local btn = CreateFrame("Button", "shupaz_ForeverQuestLogBindingButton")
        btn:RegisterForClicks("AnyDown")
        btn:SetScript("OnClick", function()
            FQL:Toggle()
        end)
        FQL.bindingOwner = btn
    end
    if ClearOverrideBindings then
        ClearOverrideBindings(FQL.bindingOwner)
    end
    if GetBindingKey and SetOverrideBindingClick then
        local key1, key2 = GetBindingKey("TOGGLEQUESTLOG")
        if key1 and key1 ~= "" then
            SetOverrideBindingClick(FQL.bindingOwner, false, key1, "shupaz_ForeverQuestLogBindingButton")
        end
        if key2 and key2 ~= "" then
            SetOverrideBindingClick(FQL.bindingOwner, false, key2, "shupaz_ForeverQuestLogBindingButton")
        end
    end
end

local function SetupMapAndBindingHooks()
    if FQL._hooksInstalled then return end
    FQL._hooksInstalled = true

    SuppressMapQuestLog()
    UpdateKeybindOverrides()

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            SuppressMapQuestLog()
        end)
    end

    -- Redirect ONLY QuestLogMicroButton to Forever Quest Log using standard Up-clicks
    -- (never touch other MicroMenu buttons and never use "AnyDown").
    if _G.QuestLogMicroButton and CanChangeFrame(_G.QuestLogMicroButton) then
        if _G.QuestLogMicroButton.RegisterForClicks then
            _G.QuestLogMicroButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        _G.QuestLogMicroButton:SetScript("OnClick", function(_, button)
            if button == "RightButton" then return end
            FQL:Toggle()
        end)
    end

    if type(_G.CloseAllWindows) == "function" then
        hooksecurefunc("CloseAllWindows", function()
            if FQL.frame and FQL.frame:IsShown() then
                FQL.frame:Hide()
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
FQL.SetupMapAndBindingHooks    = SetupMapAndBindingHooks
