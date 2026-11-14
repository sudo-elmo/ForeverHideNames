-- Simulated WoW API: Alt+Z, combat, /names, options, crash recovery. Run: lua5.1 tests/core_test.lua Core.lua
local cv = { UnitNameOwn="1", UnitNameNPC="0", nameplateShowEnemies="1", chatBubbles="1", floatingCombatTextCombatDamage="1" }
local orig = {} for k,v in pairs(cv) do orig[k]=v end
GetCVar = function(n) return cv[n] end
SetCVar = function(n,v) if cv[n]==nil then error("unknown") end cv[n]=tostring(v) end
GetLocale = function() return "deDE" end
local combat=false
InCombatLockdown=function() return combat end
DEFAULT_CHAT_FRAME={AddMessage=function(_,m) print(m) end}
SlashCmdList={}
local hooks={} hooksecurefunc=function(n,fn) local o=_G[n] _G[n]=function(...) o(...) fn(...) end end
local shown=true
local uiScripts={}
UIParent={IsShown=function() return shown end, HookScript=function(_,s,fn) uiScripts[s]=fn end}
SetUIVisibility=function(v) shown=v; if v and uiScripts.OnShow then uiScripts.OnShow() end end
local ev
CreateFrame=function() return {RegisterEvent=function() end, SetScript=function(_,_,fn) ev=fn end} end
local function load() local chunk=assert(loadfile(arg[1])) chunk("ForeverHideNames") ev(nil,"ADDON_LOADED","ForeverHideNames") ev(nil,"PLAYER_LOGIN") end
local fails=0
local function eq(a,b,m) if a~=b then fails=fails+1 print("FAIL "..m..": "..tostring(a).." ~= "..tostring(b)) end end
load()
SetUIVisibility(false)
eq(cv.UnitNameOwn,"0","alt+z hides names"); eq(cv.nameplateShowEnemies,"0","and plates"); eq(cv.chatBubbles,"0","and bubbles")
SetUIVisibility(true)
for k,v in pairs(orig) do eq(cv[k],v,"restored "..k) end
eq(next(ForeverHideNamesDB.saved),nil,"saved cleared")
-- combat
combat=true; SetUIVisibility(false)
eq(cv.UnitNameOwn,"0","combat: names hidden"); eq(cv.nameplateShowEnemies,"1","combat: plates wait")
combat=false; ev(nil,"PLAYER_REGEN_ENABLED")
eq(cv.nameplateShowEnemies,"0","after combat: plates hidden")
combat=true; SetUIVisibility(true)
eq(cv.UnitNameOwn,"1","combat restore names"); eq(cv.nameplateShowEnemies,"0","plates still wait")
combat=false; ev(nil,"PLAYER_REGEN_ENABLED")
for k,v in pairs(orig) do eq(cv[k],v,"restored after combat "..k) end
-- fishing-style UIParent hide does nothing
-- manual
SlashCmdList.FOREVERHIDENAMES("") eq(cv.UnitNameOwn,"0","/names hides")
SlashCmdList.FOREVERHIDENAMES("") eq(cv.UnitNameOwn,"1","/names shows")
-- crash while hidden -> next login restores
SetUIVisibility(false)
local db=ForeverHideNamesDB
shown=true; ForeverHideNamesDB=db; load(); ForeverHideNamesDB=db
for k,v in pairs(orig) do eq(cv[k],v,"restored on relog "..k) end
-- options: bubbles / damage configurable
eq(ForeverHideNamesDB.hideBubbles,true,"bubbles default on"); eq(ForeverHideNamesDB.hideDamage,true,"damage default on")
SlashCmdList.FOREVERHIDENAMES("bubbles")
SetUIVisibility(false)
eq(cv.chatBubbles,"1","bubbles stay when option off"); eq(cv.floatingCombatTextCombatDamage,"0","damage hidden"); eq(cv.UnitNameOwn,"0","names hidden")
SlashCmdList.FOREVERHIDENAMES("damage")
eq(cv.floatingCombatTextCombatDamage,"1","damage back right away when option turned off while hidden")
SlashCmdList.FOREVERHIDENAMES("bubbles")
eq(cv.chatBubbles,"0","bubbles hidden right away when option turned on while hidden")
SetUIVisibility(true)
for k,v in pairs(orig) do eq(cv[k],v,"restored with options "..k) end
eq(next(ForeverHideNamesDB.saved),nil,"nothing left saved")
print(fails==0 and "all ok" or (fails.." failed")); if fails > 0 then os.exit(1) end
