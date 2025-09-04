--[[
  Threat
  By: Ollowain.
	Credit: Fury.lua by Bhaerau.
]]--

-- Variables
local RevengeReadyUntil = 0;
local OPReadyUntil = 0;
local TankMode = 0;
local DoSlam = 0;
local casterGUID, targetGUID, evtype, spellId, castMS;
local _castBy = {}
local GroupMode = 0;

function Threat_Configuration_Init()
  if (not Threat_Configuration) then
    Threat_Configuration = { };
  end

  if (Threat_Configuration["Debug"] == nil) then
    Threat_Configuration["Debug"] = false;
  end
end

-- Normal Functions

local function Print(msg)
  if (not DEFAULT_CHAT_FRAME) then
    return;
  end
  DEFAULT_CHAT_FRAME:AddMessage(msg);
end

local function Debug(msg)
  if (Threat_Configuration["Debug"]) then
    if (not DEFAULT_CHAT_FRAME) then
      return;
    end
    DEFAULT_CHAT_FRAME:AddMessage(msg);
  end
end

--------------------------------------------------

function SpellId(spellname)
  local id = 1;
  for i = 1, GetNumSpellTabs() do
    local _, _, _, numSpells = GetSpellTabInfo(i);
    for j = 1, numSpells do
      local spellName = GetSpellName(id, BOOKTYPE_SPELL);
      if (spellName == spellname) then
        return id;
      end
      id = id + 1;
    end
  end
  return nil;
end

function SpellReady(spellname)
  local id = SpellId(spellname);
  if (id) then
    local start, duration = GetSpellCooldown(id, 0);
    if (start == 0 and duration == 0 and ThreatLastSpellCast + 1 <= GetTime()) then
      return true;
    end
  end
  return nil;
end

function HasBuff(unit, texturename)
  local id = 1;
  while (UnitBuff(unit, id)) do
    local buffTexture = UnitBuff(unit, id);
    if (string.find(buffTexture, texturename)) then
      return true;
    end
    id = id + 1;
  end
  return nil;
end

function ActiveStance()
  for i = 1, 3 do
    local _, _, active = GetShapeshiftFormInfo(i);
    if (active) then
      return i;
    end
  end
  return nil;
end

function HasDebuff(unit, texturename)
  local id = 1;
  while (UnitDebuff(unit, id)) do
    local debuffTexture = UnitDebuff(unit, id);
    if (string.find(debuffTexture, texturename)) then
      return true;
    end
    id = id + 1;
  end
  return nil;
end


local function _SunderCountInner(unit)
  local i = 1;
  local count = 0;
  while (UnitDebuff(unit, i)) do
    local debuffTexture, count = UnitDebuff(unit, i);
    if (string.find(debuffTexture, "Sunder")) then
      return (count and count > 1) and count or 0
    end
    i = i + 1
  end
  return 0
end

function SunderCount(unit)
  local ok, val = pcall(_SunderCountInner, unit)
  if ok then
    return val
  else
    return 0
  end
end

function HasFiveSunderArmors(unit)
  local id = 1;
  while (UnitDebuff(unit, id)) do
    local debuffTexture, debuffAmount = UnitDebuff(unit, id);
    if (string.find(debuffTexture, "Sunder")) then
      if (debuffAmount >= 5) then
        return true;
      else
        return nil;
      end
    end
    id = id + 1;
  end
  return nil;
end

function RevengeAvail()
  if GetTime() < RevengeReadyUntil then
    return true;
  else
    return nil;
  end
end

function OPAvail()
  if GetTime() < OPReadyUntil then
    return true;
  else
    return nil;
  end
end

function IsElite()
  if UnitClassification("target") == "elite" then
    return true;
  else
    return nil;
  end
end

function IsTargetElemental()
  local t = UnitCreatureType("target")
  return t ~= nil and (t == "Elemental" or t == "Mechanical" or t == "Undead")   -- enUS/enGB
end


function ShieldSlamLearned()
  if UnitClass("player") == "Warrior" then
    local _, _, _, _, ss = GetTalentInfo(3,17);
    if (ss == 1) then
      return true;
    else
      return nil;
    end
  end
end

function GetTargetHPPercent()
    if not UnitExists("target") then
        return nil
    end
    local hp  = UnitHealth("target")      -- current health
    local max = UnitHealthMax("target")   -- max health
    if max == 0 then
        return 0
    end
    return (hp / max) * 100
end


local function WhatsInMelee(spell, counter)
  -- pick a default melee spell per class if none provided (enUS strings)
  if not spell then
    local _, class = UnitClass("player")
    if class == "WARRIOR" then       spell = "Hamstring"
    elseif class == "ROGUE" then     spell = "Sinister Strike"
    elseif class == "HUNTER" then    spell = "Raptor Strike"
    elseif class == "DRUID" then     spell = "Claw"      -- cat form
    else spell = nil  -- paladin/shaman/mage/priest/warlock fallback to interact distance
    end
  end

  local function inMelee(unit)
    if not UnitExists(unit) or UnitIsDead(unit) or not UnitCanAttack("player", unit) then
      return false
    end
    if spell and IsSpellInRange then
      return IsSpellInRange(spell, unit) == 1
    end
    -- Fallback ~10y check
    return CheckInteractDistance and CheckInteractDistance(unit, 3) == 1 or false
  end

  -- dedupe without using #
  local seen, seenCount = {}, 0
  local function addIfClose(unit)
    if inMelee(unit) then
      for i = 1, seenCount do
        if UnitIsUnit(seen[i], unit) then return end
      end
      seenCount = seenCount + 1
      seen[seenCount] = unit
    end
  end

  addIfClose("target")
  addIfClose("mouseover")
  addIfClose("pettarget")

  local p = GetNumPartyMembers and GetNumPartyMembers() or 0
  for i = 1, p do addIfClose("party"..i.."target") end

  local r = GetNumRaidMembers and GetNumRaidMembers() or 0
  for i = 1, r do addIfClose("raid"..i.."target") end

  return (seenCount >= counter)
end

function Threat()
  if (not UnitIsCivilian("target") and UnitClass("player") == CLASS_WARRIOR_THREAT) then

    local rage = UnitMana("player");

    if (not ThreatAttack) then
      Debug("Starting AutoAttack");
      AttackTarget();
    end
	
	local sunders = 0
	sunders = SunderCount("target");
	


	
	-- Always Battle Shout
    if (SpellReady(ABILITY_BATTLE_SHOUT_THREAT) and not HasBuff("player", "Ability_Warrior_BattleShout") and rage >= 10) then
      Debug("Battle Shout");
      CastSpellByName(ABILITY_BATTLE_SHOUT_THREAT);
	end
	  
	
	-- Time to clean up the Rotation.  We now can get Mob Percent health, so we can stop wasting Rage on Sunders if mob is lower

	-- Tanking Rotation
	if (TankMode == 1) then
	    if (ActiveStance() ~= 2) then
			Debug("changing to def stance");
			CastSpellByName(ABILITY_DEFENSIVE_STANCE_THREAT);
		end
		-- Highest Prio Shield, use a "Toggle" that when we fire an attack, skip to the end, dont rage dump on less prio things
		if (SpellReady(ABILITY_SHIELD_SLAM_THREAT) and rage >= 20 and ShieldSlamLearned() and AttackQueued == 0) then
			Debug("Shield slam");
			CastSpellByName(ABILITY_SHIELD_SLAM_THREAT);
			AttackQueued = 1;
		-- Ignore Queue for Revenge, its bis
		elseif (SpellReady(ABILITY_REVENGE_THREAT) and RevengeAvail() and rage >= 5) then
			Debug("Revenge");
			CastSpellByName(ABILITY_REVENGE_THREAT);
			AttackQueued = 1;					

		-- Only do 5 Sunders if the Target is Elite
		-- Also, stop sundering if a mob is under 30%, to save rage dump
		elseif (SpellReady(ABILITY_SUNDER_ARMOR_THREAT) and rage >= 15 and sunders < 5 and IsElite() and GetTargetHPPercent() > 31 and AttackQueued == 0) then
		  Debug("Sunder armor");
		  CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
		  
		-- Sunder to 3 if non Elite, Still checking mob HP due to better rage spenders
		elseif (SpellReady(ABILITY_SUNDER_ARMOR_THREAT) and rage >= 15 and sunders < 3 and not IsElite() and GetTargetHPPercent() > 31 and AttackQueued == 0) then
		  Debug("Sunder armor");
		  CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
		
				  
		elseif (SpellReady(ABILITY_HEROIC_STRIKE_THREAT) and rage >= 25 and AttackQueued == 0) then
		  Debug("Heroic strike");
		  CastSpellByName(ABILITY_HEROIC_STRIKE_THREAT);
		end
	-- DPS Rotation
	else 
		if (SpellReady(ABILITY_OVERPOWER_THREAT) and OPAvail() and rage >= 5) then
		  Debug("OverPower");
		  CastSpellByName(ABILITY_OVERPOWER_THREAT);	  
			
		elseif (SpellReady(ABILITY_EXECUTE_THREAT) and rage >= 15 and GetTargetHPPercent() < 20 and AttackQueued == 0) then
		  Debug("Execute");
		  CastSpellByName(ABILITY_EXECUTE_THREAT);
				  
		  -- Only Rend in DPS Mode, waste of rage for Tank
		elseif (SpellReady(ABILITY_REND_THREAT) and not HasDebuff("target", "Ability_Gouge") and rage >= 10 and not IsTargetElemental() and GroupMode == 0 and AttackQueued == 0) then
		  Debug("Rend");
		  CastSpellByName(ABILITY_REND_THREAT);
		  
		  -- Only do 5 Sunders if the Target is Elite
		elseif (SpellReady(ABILITY_SUNDER_ARMOR_THREAT) and rage >= 15 and sunders < 5 and IsElite() and GetTargetHPPercent() > 30 and AttackQueued == 0) then
		  Debug("Sunder armor");
		  CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
		  
		-- Sunder to 3 if non Elite
		elseif (SpellReady(ABILITY_SUNDER_ARMOR_THREAT) and rage >= 15 and sunders < 3 and not IsElite() and GetTargetHPPercent() > 30 and AttackQueued == 0) then
		  Debug("Sunder armor");
		  CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
		
		elseif (ABILITY_CLEAVE_THREAT) and rage > 20 and WhatsInMelee("hamstring", 2) and AttackQueued == 0 then
		  Debug("Cleave");
		  CastSpellByName(ABILITY_CLEAVE_THREAT);
		
		-- Toggle Slam	
		-- Commenting out Slam, seems never to be useful
		-- elseif (SpellReady(ABILITY_SLAM_THREAT) and rage >= 20 and DoSlam == 1) then
		  -- Debug("Slam");
		  -- CastSpellByName(ABILITY_SLAM_THREAT);
		  
		elseif (SpellReady(ABILITY_HEROIC_STRIKE_THREAT) and rage >= 25) then
		  Debug("Heroic strike");
		  CastSpellByName(ABILITY_HEROIC_STRIKE_THREAT);
		end
	-- End Dps/Tank If
	end
	
  end
end

-- Chat Handlers

function Threat_SlashCommand(msg)
  local _, _, command, options = string.find(msg, "([%w%p]+)%s*(.*)$");
  if (command) then
    command = string.lower(command);
  end
  if (command == nil or command == "") then
    Threat();
  elseif (command == "debug") then
    if (Threat_Configuration["Debug"]) then
      Threat_Configuration["Debug"] = false;
      Print(BINDING_HEADER_THREAT .. ": " .. SLASH_THREAT_DEBUG .. " " .. SLASH_THREAT_DISABLED .. ".")
    else
      Threat_Configuration["Debug"] = true;
      Print(BINDING_HEADER_THREAT .. ": " .. SLASH_THREAT_DEBUG .. " " .. SLASH_THREAT_ENABLED .. ".")
    end
  elseif (command == "tankmode" or command == "dps" or command == "tank" or command == "dpsmode" ) then
	  if TankMode == 0 then
	    TankMode = 1;
		Print("Tanking");
	  else
	    TankMode = 0;
		Print("DPSn");
	  end
  elseif (command == "slam") then
	  if DoSlam == 0 then
	    DoSlam = 1;
		Print("Slamming");
	  else
	    DoSlam = 0;
		Print("Not Slamming");
	  end	  
  elseif (command == "group" or command == "solo") then
	  if GroupMode == 0 then
	    GroupMode = 1;
		Print("Group DPS");
	  else
	    GroupMode = 0;
		Print("Solo DPS");
	  end	
  else	  
    Print(SLASH_THREAT_HELP)
  end
end

function TargetIsCasting()
  if not UnitGUID then return false end -- needs SuperWoW
  local g = UnitGUID("target")
  if not g then return false end
  local rec = _castBy[g]
  if not rec then return false end

  local now = GetTime()*1000
  local left = (rec.tEnd or now) - now
  if left <= 0 then
    _castBy[g] = nil
    return false
  end
  local name = (GetSpellInfo and GetSpellInfo(rec.spellId)) or ("SpellID "..tostring(rec.spellId))
  return true, name, left
end


function CheckSpell(casterGUID, targetGUID, evtype, spellId, castMS)
  -- only care about "START" (cast begin)
  --print(evtype);
  if evtype ~= "START" then return end

  -- compare the caster to your current "target" via GUID (SuperWoW exposes UnitGUID)
  local myTarget = UnitGUID and UnitGUID("target")
  --print("Target" + myTarget);
  --print("spelltaret" + targetGUID);
  
  if not myTarget or casterGUID ~= myTarget then return end

  -- try to get a spell name if available; fall back to the ID
  local spellName = (GetSpellInfo and (GetSpellInfo(spellId))) or ("SpellID "..tostring(spellId))

  Print("|cff33ff99Target casting:|r %s (%s ms)", tostring(spellName), tostring(castMS or "?"));
end

-- Event Handlers

function Threat_OnLoad()
  this:RegisterEvent("VARIABLES_LOADED");
  this:RegisterEvent("PLAYER_ENTER_COMBAT");
  this:RegisterEvent("PLAYER_LEAVE_COMBAT");
  this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES");
  this:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF");
  this:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES");
  this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE");
  this:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF");
  this:RegisterEvent("UNIT_CASTEVENT");
  this:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS");
  
  ThreatLastSpellCast = GetTime();
  ThreatLastStanceCast = GetTime();
  SlashCmdList["THREAT"] = Threat_SlashCommand;
  SLASH_THREAT1 = "/threat";
end

function Threat_OnEvent(event)
  if (event == "VARIABLES_LOADED") then
    Threat_Configuration_Init()
  elseif (event == "PLAYER_ENTER_COMBAT") then
    ThreatAttack = true;
  elseif (event == "PLAYER_LEAVE_COMBAT") then
    ThreatAttack = nil;
  elseif (event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")then
    if string.find(arg1,"You block")
    or string.find(arg1,"You parry")
    or string.find(arg1,"You dodge") then
      Debug("Revenge soon ready");
      RevengeReadyUntil = GetTime() + 4;
    end
  elseif event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_COMBAT_SELF_MISSES" then
	if string.find(arg1,"dodge") then
	 Debug("Enemy Dodged");
	 OPReadyUntil = GetTime() + 4; 
	end
	local _, _, spell, outcome = string.find(arg1, "^Your%s+(.+)%s+(hits.+)$")
	if spell then
        Debug(string.format("|cffff6666Ability|r: %s -> %s", spell, outcome))
		AttackQueued = 0;
    end
  elseif event == "UNIT_CASTEVENT" then
	casterGUID, targetGUID, evtype, spellId, castMS = arg1, arg2, arg3, arg4, arg5;
	CheckSpell(casterGUID, targetGUID, evtype, spellId, castMS);
	-- local now = GetTime()*1000
    -- if evtype == "START" or evtype == "CHANNEL" then
	 -- _castBy[casterGUID] = { spellId = spellId, tEnd = now + (tonumber(castMS) or 0) }
	-- elseif evtype == "CAST" or evtype == "FAIL" or evtype == "INTERRUPT" or evtype == "STOP" then
	 -- _castBy[casterGUID] = nil
	-- end
  end
end
