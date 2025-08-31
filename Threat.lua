--[[
  Threat
  By: Ollowain.
	Credit: Fury.lua by Bhaerau.
]]--

-- Variables
local RevengeReadyUntil = 0;
local OPReadyUntil = 0;
local TankMode = 0;
local DoSlam = 1;

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
  return t ~= nil and t == "Elemental"   -- enUS/enGB
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


function Threat()
  if (not UnitIsCivilian("target") and UnitClass("player") == CLASS_WARRIOR_THREAT) then

    local rage = UnitMana("player");

    if (not ThreatAttack) then
      Debug("Starting AutoAttack");
      AttackTarget();
    end
	
	local sunders = 0
	sunders = SunderCount("target");

    -- if (activestance() ~= 2 and TankMode == 1) then
      -- debug("changing to def stance");
      -- castspellbyname(ability_defensive_stance_threat);
    -- end

    if (SpellReady(ABILITY_BATTLE_SHOUT_THREAT) and not HasBuff("player", "Ability_Warrior_BattleShout") and rage >= 10) then
      Debug("Battle Shout");
      CastSpellByName(ABILITY_BATTLE_SHOUT_THREAT);
    elseif (SpellReady(ABILITY_SHIELD_SLAM_THREAT) and rage >= 20 and ShieldSlamLearned()) then
      Debug("Shield slam");
      CastSpellByName(ABILITY_SHIELD_SLAM_THREAT);
	  
	elseif (SpellReady(ABILITY_OVERPOWER_THREAT) and OPAvail() and rage >= 10) then
      Debug("OverPower");
      CastSpellByName(ABILITY_OVERPOWER_THREAT);
    elseif (SpellReady(ABILITY_REVENGE_THREAT) and RevengeAvail() and rage >= 5 and TankMode == 1) then
      Debug("Revenge");
      CastSpellByName(ABILITY_REVENGE_THREAT);
	  
    elseif (SpellReady(ABILITY_REND_THREAT) and not HasDebuff("target", "Ability_Gouge") and rage >= 10 and not IsTargetElemental()) then
      Debug("Rend");
      CastSpellByName(ABILITY_REND_THREAT);
	  
	  -- Only do 5 Sunders if the Target is Elite
    elseif (SpellReady(ABILITY_SUNDER_ARMOR_THREAT) and rage >= 15 and sunders < 5 and IsElite()) then
      Debug("Sunder armor");
      CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
	  
    -- Sunder to 3 if non Elite
	elseif (SpellReady(ABILITY_SUNDER_ARMOR_THREAT) and rage >= 15 and sunders < 3 and not IsElite()) then
      Debug("Sunder armor");
      CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
	  	  
	elseif (SpellReady(ABILITY_SLAM_THREAT) and rage >= 20 and DoSlam == 1) then
      Debug("Slam");
      CastSpellByName(ABILITY_SLAM_THREAT);
	  
    elseif (SpellReady(ABILITY_HEROIC_STRIKE_THREAT) and rage >= 25) then
      Debug("Heroic strike");
      CastSpellByName(ABILITY_HEROIC_STRIKE_THREAT);
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
  elseif (command == "tankmode") then
	  TankMode = 1;
	  Print("Tank Mode On");
  elseif (command == "dpsmode") then
      TankMode = 0;
	  Print("Tank Mode Off");
  elseif (command == "slamtoggle") then
	  if DoSlam == 0 then
	    DoSlam = 1;
		Print("Slamming");
	  else
	    DoSlam = 0;
		Print("Not Slamming");
	  end	  
  else	  
    Print(SLASH_THREAT_HELP)
  end
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
	 Print("Dodged");
	 OPReadyUntil = GetTime() + 4; 
	end
  end
end
