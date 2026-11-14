-- Forever Hide Names: when the interface is hidden with the "hide interface"
-- key (Alt+Z), every name and nameplate in the world disappears too, and
-- (configurable) chat bubbles and damage numbers. When the interface comes
-- back, so do they, exactly as they were. /names toggles them by hand.
--
-- The original value of every setting the addon turned off is kept in
-- SavedVariables until it is restored, so a crash, logout or /reload with
-- hidden names restores them on the next login.
local ADDON = ...

-- Every setting that draws something over the 3D world, by group. Settings
-- the client does not know are skipped. "option" = db key that switches the
-- group on or off (no option: always hidden).
local GROUPS = {
    { -- names over heads
        "UnitNameOwn", "UnitNameNPC", "UnitNameHostleNPC", "UnitNameInteractiveNPC",
        "UnitNameFriendlySpecialNPCName", "UnitNameNonCombatCreatureName",
        "UnitNameFriendlyPlayerName", "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName",
        "UnitNameFriendlyTotemName", "UnitNameFriendlyMinionName",
        "UnitNameEnemyPlayerName", "UnitNameEnemyPetName", "UnitNameEnemyGuardianName",
        "UnitNameEnemyTotemName", "UnitNameEnemyMinionName",
        "UnitNamePlayerGuild", "UnitNamePlayerPVPTitle", "UnitNameGuildTitle",
    },
    { -- nameplates
        "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriends",
        "nameplateShowFriendlyNPCs", "nameplateShowSelf",
    },
    { option = "hideBubbles", "chatBubbles", "chatBubblesParty" },
    { option = "hideDamage", "floatingCombatTextCombatDamage" },
}

local DEFAULTS = { hideBubbles = true, hideDamage = true }

-- the client refuses to switch nameplates in combat; these wait until it ends
local function CombatLocked(name) return name:find("^nameplate") ~= nil end

local GetCVarValue = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVarValue = (C_CVar and C_CVar.SetCVar) or SetCVar

local L = (GetLocale and GetLocale() == "deDE") and {
    title = "Forever Hide Names",
    hidden = "Namen ausgeblendet.",
    shown = "Namen wieder eingeblendet.",
    waitCombat = "Namensplaketten folgen nach dem Kampf.",
    on = "|cff33ff33an|r", off = "|cffff5555aus|r",
    header = "Zusammen mit den Namen ausblenden",
    hideBubbles = "Sprechblasen",
    hideBubblesTip = "Blendet auch die Sprechblasen über den Köpfen aus.",
    hideDamage = "Schadenszahlen",
    hideDamageTip = "Blendet auch die Schadenszahlen über deinen Zielen aus.",
    status = "Sprechblasen ausblenden: %s · Schadenszahlen ausblenden: %s",
    help = "|cffffffff/names|r blendet alle Namen ein/aus (mit Alt+Z passiert das automatisch). "
        .. "|cffffffff/names bubbles|r und |cffffffff/names damage|r: Sprechblasen bzw. Schadenszahlen mit ausblenden an/aus. "
        .. "|cffffffff/names options|r: Einstellungen.",
} or {
    title = "Forever Hide Names",
    hidden = "Names hidden.",
    shown = "Names shown again.",
    waitCombat = "Nameplates follow after combat.",
    on = "|cff33ff33on|r", off = "|cffff5555off|r",
    header = "Hide together with the names",
    hideBubbles = "Chat bubbles",
    hideBubblesTip = "Also hides the chat bubbles over heads.",
    hideDamage = "Damage numbers",
    hideDamageTip = "Also hides the damage numbers over your targets.",
    status = "Hide chat bubbles: %s · Hide damage numbers: %s",
    help = "|cffffffff/names|r hides/shows all names (hiding the interface with Alt+Z does this automatically). "
        .. "|cffffffff/names bubbles|r and |cffffffff/names damage|r: also hide chat bubbles / damage numbers on/off. "
        .. "|cffffffff/names options|r: settings.",
}

local function Print(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Forever Hide Names:|r " .. msg) end
end

local db                -- ForeverHideNamesDB: options + saved = { cvar = original }
local manual = false    -- hidden by /names
local uiHidden = false  -- hidden with Alt+Z
local pending = false   -- some settings still wait for the end of combat

-- false while the client refuses the change (nameplates in combat)
local function Set(name, value)
    if CombatLocked(name) and InCombatLockdown and InCombatLockdown() then
        pending = true
        return false
    end
    pcall(SetCVarValue, name, value)
    return true
end

local function WantHidden() return manual or uiHidden end

-- Brings every setting into the wanted state: turned off while hidden and
-- its group is enabled, else back to the player's own value. Also used when
-- an option changes while the names are hidden.
local function Apply()
    pending = false
    local hide = WantHidden()
    for _, group in ipairs(GROUPS) do
        local enabled = not group.option or db[group.option]
        for _, name in ipairs(group) do
            if hide and enabled then
                if db.saved[name] == nil then
                    -- remember the player's own value once, before touching it
                    db.saved[name] = GetCVarValue(name)
                end
                if db.saved[name] ~= nil then Set(name, "0") end
            elseif db.saved[name] ~= nil then
                if Set(name, db.saved[name]) then db.saved[name] = nil end
            end
        end
    end
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

-- ---------------------------------------------------------------- settings page

local category

local function RegisterOptions()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    category = Settings.RegisterVerticalLayoutCategory(L.title)
    if Settings.RegisterInitializer and CreateSettingsListSectionHeaderInitializer then
        Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(L.header))
    end
    for _, key in ipairs({ "hideBubbles", "hideDamage" }) do
        local ok, setting = pcall(Settings.RegisterAddOnSetting, category, "FOREVER_HIDE_NAMES_" .. key:upper(), key,
            db, Settings.VarType.Boolean, L[key], DEFAULTS[key] and Settings.Default.True or Settings.Default.False)
        if ok and setting then
            setting:SetValueChangedCallback(Apply)
            Settings.CreateCheckbox(category, setting, L[key .. "Tip"])
        end
    end
    Settings.RegisterAddOnCategory(category)
end

local function OpenOptions()
    if not (category and Settings and Settings.OpenToCategory) then
        Print(L.status:format(db.hideBubbles and L.on or L.off, db.hideDamage and L.on or L.off))
        return
    end
    if not pcall(Settings.OpenToCategory, category:GetID()) then pcall(Settings.OpenToCategory, category) end
end

-- ---------------------------------------------------------------- events

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        ForeverHideNamesDB = ForeverHideNamesDB or {}
        db = ForeverHideNamesDB
        db.saved = db.saved or {}
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
    elseif event == "PLAYER_LOGIN" then
        if SetUIVisibility then
            hooksecurefunc("SetUIVisibility", OnUIVisibility)
        else
            UIParent:HookScript("OnHide", function() OnUIVisibility(false) end)
        end
        UIParent:HookScript("OnShow", function() OnUIVisibility(true) end)
        RegisterOptions()
        -- left hidden by a crash, logout or /reload: bring everything back
        uiHidden = false
        Apply()
    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        Apply()
    end
end)

local function ToggleOption(key)
    db[key] = not db[key]
    Apply()
    Print(L.status:format(db.hideBubbles and L.on or L.off, db.hideDamage and L.on or L.off))
end

SLASH_FOREVERHIDENAMES1 = "/names"
SLASH_FOREVERHIDENAMES2 = "/namen"
SLASH_FOREVERHIDENAMES3 = "/hidenames"
SlashCmdList.FOREVERHIDENAMES = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "help" or msg == "hilfe" or msg == "?" then
        Print(L.help)
    elseif msg == "bubbles" or msg == "blasen" or msg == "sprechblasen" then
        ToggleOption("hideBubbles")
    elseif msg == "damage" or msg == "schaden" then
        ToggleOption("hideDamage")
    elseif msg == "options" or msg == "config" or msg == "optionen" then
        OpenOptions()
    else
        manual = not WantHidden()
        if not manual then uiHidden = false end
        Apply()
        Print((WantHidden() and L.hidden or L.shown) .. (pending and (" " .. L.waitCombat) or ""))
    end
end
