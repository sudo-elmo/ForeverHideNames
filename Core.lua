-- Forever Hide Names: when the interface is hidden with the "hide interface"
-- key (Alt+Z), every name, nameplate and chat bubble in the world disappears
-- too; when the interface comes back, so do they, exactly as they were.
-- /names toggles them by hand.
--
-- The original settings are kept in SavedVariables while hidden, so a crash,
-- logout or /reload with hidden names restores them on the next login.
local ADDON = ...

-- Every setting that draws something over the 3D world. Settings the client
-- does not know are skipped.
local CVARS = {
    -- names over heads
    "UnitNameOwn", "UnitNameNPC", "UnitNameHostleNPC", "UnitNameInteractiveNPC",
    "UnitNameFriendlySpecialNPCName", "UnitNameNonCombatCreatureName",
    "UnitNameFriendlyPlayerName", "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName",
    "UnitNameFriendlyTotemName", "UnitNameFriendlyMinionName",
    "UnitNameEnemyPlayerName", "UnitNameEnemyPetName", "UnitNameEnemyGuardianName",
    "UnitNameEnemyTotemName", "UnitNameEnemyMinionName",
    "UnitNamePlayerGuild", "UnitNamePlayerPVPTitle", "UnitNameGuildTitle",
    -- nameplates
    "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriends",
    "nameplateShowFriendlyNPCs", "nameplateShowSelf",
    -- chat bubbles and damage numbers over targets
    "chatBubbles", "chatBubblesParty", "floatingCombatTextCombatDamage",
}

-- the client refuses to switch nameplates in combat; these wait until it ends
local function CombatLocked(name) return name:find("^nameplate") ~= nil end

local GetCVarValue = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVarValue = (C_CVar and C_CVar.SetCVar) or SetCVar

local L = (GetLocale and GetLocale() == "deDE") and {
    hidden = "Namen ausgeblendet.",
    shown = "Namen wieder eingeblendet.",
    waitCombat = "Namensplaketten folgen nach dem Kampf.",
    help = "|cffffffff/names|r blendet alle Namen ein/aus. Mit Alt+Z (Oberfläche ausblenden) passiert das automatisch.",
} or {
    hidden = "Names hidden.",
    shown = "Names shown again.",
    waitCombat = "Nameplates follow after combat.",
    help = "|cffffffff/names|r hides/shows all names. Hiding the interface (Alt+Z) does this automatically.",
}

local function Print(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Forever Hide Names:|r " .. msg) end
end

local db                -- ForeverHideNamesDB: { saved = { cvar = original } | nil }
local manual = false    -- hidden by /names
local uiHidden = false  -- hidden with Alt+Z
local pending = false   -- some settings still wait for the end of combat

local function Set(name, value)
    if CombatLocked(name) and InCombatLockdown and InCombatLockdown() then
        pending = true
        return
    end
    pcall(SetCVarValue, name, value)
end

local function Hide()
    if not db.saved then
        -- remember the player's own settings once, before touching anything
        local saved = {}
        for _, name in ipairs(CVARS) do
            local v = GetCVarValue(name)
            if v ~= nil then saved[name] = v end
        end
        db.saved = saved
    end
    for name in pairs(db.saved) do Set(name, "0") end
end

local function Restore()
    if not db.saved then return end
    for name, v in pairs(db.saved) do Set(name, v) end
    if not pending then db.saved = nil end   -- keep them until everything is back
end

local function WantHidden() return manual or uiHidden end

local function Apply()
    pending = false
    if WantHidden() then Hide() else Restore() end
end

-- Alt+Z runs SetUIVisibility(false/true). Other addons that hide UIParent on
-- their own (e.g. Forever Fishing while fishing) do not hide the names, but
-- the names always come back together with the interface.
local function OnUIVisibility(shown)
    shown = shown and true or false
    if uiHidden == not shown then return end
    uiHidden = not shown
    Apply()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        ForeverHideNamesDB = ForeverHideNamesDB or {}
        db = ForeverHideNamesDB
    elseif event == "PLAYER_LOGIN" then
        if SetUIVisibility then
            hooksecurefunc("SetUIVisibility", OnUIVisibility)
        else
            UIParent:HookScript("OnHide", function() OnUIVisibility(false) end)
        end
        UIParent:HookScript("OnShow", function() OnUIVisibility(true) end)
        -- left hidden by a crash, logout or /reload: bring everything back
        uiHidden = not UIParent:IsShown() and db.saved ~= nil
        Apply()
    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        Apply()
    end
end)

SLASH_FOREVERHIDENAMES1 = "/names"
SLASH_FOREVERHIDENAMES2 = "/namen"
SLASH_FOREVERHIDENAMES3 = "/hidenames"
SlashCmdList.FOREVERHIDENAMES = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "help" or msg == "hilfe" or msg == "?" then Print(L.help) return end
    manual = not WantHidden()
    if not manual then uiHidden = false end
    Apply()
    Print((WantHidden() and L.hidden or L.shown) .. (pending and (" " .. L.waitCombat) or ""))
end
