-- *** Version information
VERSION = "1.0.0";

-- *** Local variables
local showDebug = 0; -- 1 = show debugs in general chat, 0 turns off debug
local initialized = false;
local cycleNumber = 0;
local timeCounter = 0;
local updateFrame = CreateFrame("frame");
local updateDelay = 2;

-- *** Functions

-- **************************************************************************
-- DESC : Debug function to print message to chat frame
-- VARS : Message = message to print to chat frame
-- **************************************************************************
function debugMessage(Message, override)
  if ((showDebug == 1 or override == 1) and Message ~= lastDebug) then
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorRed .."GS: " .. Message);
    lastDebug = Message;
  end
end

-- **************************************************************************
-- DESC : Registers the plugin upon it loading
-- **************************************************************************
function GSC_OnLoad(self)
  debugMessage("Loading GearStatistics", 0);
  
    -- Register the events we need
  self:RegisterEvent("PLAYER_ENTERING_WORLD");
  self:RegisterEvent("PLAYER_LOGOUT");
  self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
  self:RegisterEvent("PLAYER_LEVEL_UP");
end

-- **************************************************************************
-- DESC : GearStat event handler
-- **************************************************************************
function GSC_OnEvent(self, event, a1, ...)

  debugMessage("Event: "..event, 0)

  -- Handle events
  if (initialized == true and (event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP")) then
    updateGearScore("player", 0);
    if (GSC_CharFrame:IsVisible()) then
      GSC_CharFrame:Hide();
      GSC_CharFrame:Show();
    end
    return;
  end
    
  if (event == "PLAYER_ENTERING_WORLD") then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD");
    
    initialise();
    initialized = true;
    return;
  end

  if (event == "PLAYER_LOGOUT") then
    self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
    self:UnregisterEvent("PLAYER_LEVEL_UP");
      
    GSC.currentPlayer = {};
    return;
  end
end

-- **************************************************************************
-- DESC : Initialise GearStatistics
-- **************************************************************************
function initialise()
  debugMessage("Initialising GearStatistics", 0);
  
  -- setup data block
  if (GSC == nil) then
    GSC = {};
    GSC.currentPlayer = {};
    GSC.Data = {};
  end
  if(GSC.Data.version == nil or not (GSC.Data.version == VERSION)) then
    GSC = {};
    GSC.currentPlayer = {};
    GSC.Data = {}; -- zap all prior history if not current version
    GSC.Data.version = VERSION;
    GSC.Data.lastUpdated = time();
  end
  GSC.thisRealm = GetRealmName();
  if(GSC.Data[GSC.thisRealm] == nil) then
    GSC.Data[GSC.thisRealm] = {};
  end
  
  -- Register our slash command
  SlashCmdList["GEARSTATISTICS"] = function(msg)
    slashCommandHandler(msg);
  end
  SLASH_GEARSTATISTICS1 = "/gs";

  hookTooltips();
  GSC_Frame:Hide();
  
  updateFrame:SetScript("OnUpdate", GSC_OnUpdate)
  debugMessage("slash registered", 0);
  DEFAULT_CHAT_FRAME:AddMessage("|c".. colorOrange .."".. TEXT_LOADED .. VERSION .. TEXT_USE_COMMANDS);
end

-- **************************************************************************
-- DESC : Handle slash commands
-- **************************************************************************
function slashCommandHandler(msg)
  debugMessage("Received slash command: "..msg, 0);
  
  -- handles slash commands
  msg = string.lower(msg)
  if(msg == CMD_VERSION) then
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorYellow .. VERSION_TEXT .. VERSION .. VERSION_WOWVERSION);
  elseif(msg == CMD_RELOADUI or msg == CMD_RL) then
    ReloadUI();
  elseif(msg == "debug") then
    showCurrentPlayerData();
  elseif(msg == CMD_SHOW or msg == CMD_HIDE) then
    GSC_CharFrame_Toggle();
  elseif(msg == CMD_UPDATE) then
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorYellow .. TEXT_UPDATING_GEAR);
    updateGearScore("player", 1);
--  elseif(msg == "showdb") then
-- TODO    GearStat_ShowDB();
  else
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorOrange .. CMD_TEXT_HEADLINE);
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorYellow .. CMD_TEXT_VERSION);
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorYellow .. CMD_TEXT_UPDATE);
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorYellow .. CMD_TEXT_SHOW);
    DEFAULT_CHAT_FRAME:AddMessage("|c".. colorYellow .. CMD_TEXT_RL);
  end
end

-- **************************************************************************
-- DESC : Update cache after <GSC_UpdateDelay> seconds
-- **************************************************************************
function GSC_OnUpdate(self, elapsed)
  debugMessage("Trying to update gear cache", 0);
  
  if (elapsed == nil ) then
    elapsed = 0.01
  end
  timeCounter = timeCounter + elapsed
  if (timeCounter >= updateDelay and cycleNumber == 0) then
    debugMessage("first update!", 0)
    timeCounter = 0
    cycleNumber = 1;
  end
  if (timeCounter >= updateDelay and cycleNumber == 1) then
    debugMessage("second update! - updating gear, timecounter: ".. timeCounter, 0)
    updateGearScore("player", 1);
    timeCounter = 0
    updateFrame:SetScript("OnUpdate", nil)
  end
end

-- **************************************************************************
-- DESC : Update database with player stats
-- **************************************************************************
function updateGearScore(unit, override)
  debugMessage("Updating unit: "..unit.." - override: "..override, 0);

  if ((UnitExists(unit) and UnitIsPlayer(unit)) or override == 1) then
    local name = UnitName(unit);
    debugMessage("Updating data for "..name, 0);
    
    GSC.currentPlayer = {};
    GSC.currentPlayer.realmName = GetRealmName();
    GSC.currentPlayer.playerName = UnitName(unit);
    GSC.currentPlayer.playerLevel = UnitLevel(unit);
    GSC.currentPlayer.class = UnitClass(unit);
    GSC.currentPlayer.gender = UnitSex(unit);
    GSC.currentPlayer.race = UnitRace(unit);
    GSC.currentPlayer.guild = GetGuildInfo(unit);
    GSC.currentPlayer.faction = UnitFactionGroup(unit);
    if(GSC.currentPlayer.guild == nil) then
      GSC.currentPlayer.guild = TEXT_NO_GUILD;
    end
    GSC.currentPlayer.twoHandWeapon = false;
    updateCurrentPlayerProfessions(unit);
    updateCurrentPlayerItemList(unit);
    GSC.currentPlayer.recordedTime = time();
    addPlayerRecord(GSC.currentPlayer);
    
    if(unit ~= GSC_TEXT_PLAYER) then
      GSC.currentPlayer = getPlayerRecord(UnitName(GSC_TEXT_PLAYER));
    end
  end
end

-- **************************************************************************
-- DESC : Add player record to Data
-- **************************************************************************
function addPlayerRecord(playerRecord)
  -- will check if player exists if not adds player to array.
  if (playerRecord ~= nil) then
    if(GSC.Data[GSC.thisRealm][playerRecord.playerName] == nil) then
      GSC.Data[GSC.thisRealm][playerRecord.playerName] = {};
    end
    debugMessage("Adding player record: "..playerRecord.playerName.." to saved variables", 0 )
    GSC.Data[GSC.thisRealm][playerRecord.playerName] = playerRecord;
    GSC.Data.lastUpdated = time();
  end
end

-- **************************************************************************
-- DESC : return the player record from variables
-- **************************************************************************
function getPlayerRecord(playerName, currentPlayer)
  if (playerName == nil) then
    return nil;
  end
  if(currentPlayer == 1) then
    return GSC.currentPlayer
  end
  local record = GSC.Data[GSC.thisRealm][playerName];
  
  return record;
end

-- **************************************************************************
-- DESC : Update currentPlayers professions
-- **************************************************************************
function updateCurrentPlayerProfessions(unit)
  if(unit == GSC_TEXT_PLAYER) then
    GSC.currentPlayer.professions = {}
  
    prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions();
    if(prof1) then
      name1, texture1, rank1, maxRank1, numSpells1, spelloffset1, skillLine1, rankModifier1 = GetProfessionInfo(prof1)
      debugMessage("\nProfession 1:\nName: "..name1.."\nTexture: "..texture1.."\nRank: "..rank1.."\nMax rank: "..maxRank1.."\nNum. spells: "..numSpells1.."\nSpellOffset: "..spelloffset1.."\nSkillline: "..skillLine1.."\nRankModifier: "..rankModifier1, 0)
      GSC.currentPlayer.professions.profession1 = {};
      GSC.currentPlayer.professions.profession1.name = name1;
      GSC.currentPlayer.professions.profession1.rank = rank1;
      GSC.currentPlayer.professions.profession1.rankModifier = rankModifier1;
      GSC.currentPlayer.professions.profession1.maxRank = maxRank1;
    end
    if(prof2) then
      name2, texture2, rank2, maxRank2, numSpells2, spelloffset2, skillLine2, rankModifier2 = GetProfessionInfo(prof2)
      debugMessage("\nProfession 2:\nName: "..name2.."\nTexture: "..texture2.."\nRank: "..rank2.."\nMax rank: "..maxRank2.."\nNum. spells: "..numSpells2.."\nSpellOffset: "..spelloffset2.."\nSkillline: "..skillLine2.."\nRankModifier: "..rankModifier2, 0)
      GSC.currentPlayer.professions.profession2 = {};
      GSC.currentPlayer.professions.profession2.name = name2;
      GSC.currentPlayer.professions.profession2.rank = rank2;
      GSC.currentPlayer.professions.profession2.rankModifier = rankModifier2;
      GSC.currentPlayer.professions.profession2.maxRank = maxRank2;
    end
    if(archaeology) then
      name3, texture3, rank3, maxRank3, numSpells3, spelloffset3, skillLine3, rankModifier3 = GetProfessionInfo(archaeology)
      debugMessage("\nArchaeology:\nName: "..name3.."\nTexture: "..texture3.."\nRank: "..rank3.."\nMax rank: "..maxRank3.."\nNum. spells: "..numSpells3.."\nSpellOffset: "..spelloffset3.."\nSkillline: "..skillLine3.."\nRankModifier: "..rankModifier3, 0)
      GSC.currentPlayer.professions.archaeology = {};
      GSC.currentPlayer.professions.archaeology.name = name3;
      GSC.currentPlayer.professions.archaeology.rank = rank3;
      GSC.currentPlayer.professions.archaeology.rankModifier = rankModifier3;
      GSC.currentPlayer.professions.archaeology.maxRank = maxRank3;
    end
    if(fishing) then
      name4, texture4, rank4, maxRank4, numSpells4, spelloffset4, skillLine4, rankModifier4 = GetProfessionInfo(fishing)
      debugMessage("\nFishing:\nName: "..name4.."\nTexture: "..texture4.."\nRank: "..rank4.."\nMax rank: "..maxRank4.."\nNum. spells: "..numSpells4.."\nSpellOffset: "..spelloffset4.."\nSkillline: "..skillLine4.."\nRankModifier: "..rankModifier4, 0)
      GSC.currentPlayer.professions.fishing = {};
      GSC.currentPlayer.professions.fishing.name = name4;
      GSC.currentPlayer.professions.fishing.rank = rank4;
      GSC.currentPlayer.professions.fishing.rankModifier = rankModifier4;
      GSC.currentPlayer.professions.fishing.maxRank = maxRank4;
    end
    if(cooking) then
      name5, texture5, rank5, maxRank5, numSpells5, spelloffset5, skillLine5, rankModifier5 = GetProfessionInfo(cooking)
      debugMessage("\nCooking:\nName: "..name5.."\nTexture: "..texture5.."\nRank: "..rank5.."\nMax rank: "..maxRank5.."\nNum. spells: "..numSpells5.."\nSpellOffset: "..spelloffset5.."\nSkillline: "..skillLine5.."\nRankModifier: "..rankModifier5, 0)
      GSC.currentPlayer.professions.cooking = {};
      GSC.currentPlayer.professions.cooking.name = name5;
      GSC.currentPlayer.professions.cooking.rank = rank5;
      GSC.currentPlayer.professions.cooking.rankModifier = rankModifier5;
      GSC.currentPlayer.professions.cooking.maxRank = maxRank5;
    end
  end
end

-- **************************************************************************
-- DESC : Updates GS.currentPlayer.itemList, GS.currentPlayer.totalItemLevel, GS.currentPlayer.totalItemScore,
--                GS.currentPlayer.averageItemLevel, GS.currentPlayer.averageItemScore
-- **************************************************************************
function updateCurrentPlayerItemList(unit)
  debugMessage("Updating gear", 0);
  local totalItemScore = 0;
  local totalItemLevel = 0;
  local averageItemScore = 0;
  local averageItemLevel = 0;
  local minItemLevel = 0;
  local maxItemLevel = 0;
  local twoHandWeapon = false;
  local unitLevel = UnitLevel(unit);
  local missingText = "";
  local legionArtifact = 0;
  GSC.currentPlayer.itemList = {};
  local itemLevel = 0;
  
  for index in ipairs(GEARLIST) do
    GEARLIST[index].id = GetInventorySlotInfo(GEARLIST[index].name);
    local slotLink = GetInventoryItemLink(unit, GEARLIST[index].id);
    if (slotLink ~= nil) then
      local itemName, itemLink, itemRarity, iLvl, itemMinLevel, itemType, itemSubType = GetItemInfo(slotLink);
      local itemScore = 0;
      legionArtifact = legionArtifact + isLegionArtifactWeapon(GEARLIST[index].desc, itemName);

      if(GEARLIST[index].minLevel >= 0 and itemLink and isLegionArtifactWeapon(GEARLIST[index].desc, itemName) == 0) then
        local enchantScore, enchantText = getItemEnchantScore(slotLink)
        local gemScore, gemText = getItemGemScore(slotLink)
        itemScore = getItemScore(slotLink) + enchantScore + gemScore
      
        -- compensate for 2H weapons
        if(isWeaponTwoHand(itemSubType) == 1) then
          -- compensate for warrior with dual 2H weapons equipped
          if(twoHandWeapon == true) then
            twoHandWeapon = false;
          else    
            twoHandWeapon = true;
          end
        end

        missingText = missingText..enchantText..gemText;
        totalItemScore = totalItemScore + itemScore;
        -- fix for itemlevels with '+', eg. 385+
        string.gsub(iLvl, "+", "")
        itemLevel = tonumber(iLvl)

        totalItemLevel = totalItemLevel + itemLevel;
        if(itemLevel < minItemLevel and itemLevel > 0) then
          minItemLevel = itemLevel
        end
        if(itemLevel > maxItemLevel) then
          maxItemLevel = itemLevel
        end

        -- Update cache
        GSC.currentPlayer.itemList[GEARLIST[index].name] = {};
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemName = itemName;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemLink = itemLink;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemRarity = itemRarity;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemLevel = itemLevel;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemType = itemType;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemSubType = itemSubType;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemScore = itemScore;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemMissingText = missingText;
        GSC.currentPlayer.itemList[GEARLIST[index].name].levelColor = colorBlue;
        missingText = "";
      else -- set passive legion artifact itemSlot to empty
        GSC.currentPlayer.itemList[GEARLIST[index].name] = {};
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemName = TEXT_NO_ITEM_EQUIPPED;
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemLink = "";
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemRarity = "";
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemLevel = "";
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemType = "";
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemSubType = "";
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemScore = "";
        GSC.currentPlayer.itemList[GEARLIST[index].name].itemMissingText = "";
        GSC.currentPlayer.itemList[GEARLIST[index].name].levelColor = colorBlue;
      end
    else
      GSC.currentPlayer.itemList[GEARLIST[index].name] = {};
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemName = TEXT_NO_ITEM_EQUIPPED;
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemLink = "";
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemRarity = "";
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemLevel = "";
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemType = "";
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemSubType = "";
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemScore = "";
      GSC.currentPlayer.itemList[GEARLIST[index].name].itemMissingText = "";
      GSC.currentPlayer.itemList[GEARLIST[index].name].levelColor = colorBlue;
    end
  end

  -- Calculate score
  local itemCount = getMaxItemsForLevel(unitLevel);

  -- compensate for two hand weapon
  if(twoHandWeapon == true or legionArtifact == 1) then
    itemCount = itemCount -1;
    GSC.currentPlayer.twoHandWeapon = true;
  end
  
  averageItemLevel = totalItemLevel/itemCount;
  averageItemScore = totalItemScore/itemCount;

  -- Update cache
  for index in ipairs(GEARLIST) do
    if (GSC.currentPlayer.itemList[GEARLIST[index].name].itemName ~= TEXT_NO_ITEM_EQUIPPED) then
      debugMessage("itemName: ".. GSC.currentPlayer.itemList[GEARLIST[index].name].itemName, 0)
      debugMessage("itemLevel: ".. GSC.currentPlayer.itemList[GEARLIST[index].name].itemLevel, 0)
      debugMessage("averageItemLevel: "..averageItemLevel, 0)
      GSC.currentPlayer.itemList[GEARLIST[index].name].levelColor =
                                       getLevelColor(GSC.currentPlayer.itemList[GEARLIST[index].name].itemLevel, averageItemLevel);
    end
  end
  GSC.currentPlayer.averageItemScore = averageItemScore;
  GSC.currentPlayer.averageItemLevel = averageItemLevel;
  GSC.currentPlayer.minItemLevel = minItemLevel;
  GSC.currentPlayer.maxItemLevel = maxItemLevel;
  GSC.currentPlayer.totalItemScore = totalItemScore;
  GSC.currentPlayer.totalItemLevel = totalItemLevel;
  
  debugMessage("Update complete", 0)
end

-- **************************************************************************
-- DESC : Returns true, if the weapon is a legion artifact (two hand equipped as 1-hand). 
--         in order to only show ilvl and score for 1 slot, main or offhand, depending on the weapon
-- **************************************************************************
function isLegionArtifactWeapon(itemSlot, itemName)
  
  debugMessage("Legion artifact, slot: "..itemSlot.." - itemName: "..itemName, 0)

  if(itemSlot and itemName and (itemSlot == GEAR_OFFHAND or itemSlot == GEAR_MAINHAND)) then
    for index in ipairs(ARTIFACT_WEAPONS) do
      for w in gmatch(itemName, ARTIFACT_WEAPONS[index].text) do
        return 1;
      end
    end
  end
  return 0;
end

-- **************************************************************************
-- DESC : Returns score for enchants, text if enchant is missing and possible
-- **************************************************************************
function getItemEnchantScore(itemLink)
  return 0, ""
  
  --TODO EnchantScore
end


-- **************************************************************************
-- DESC : Returns score for gems, text if gem is possible and missing
-- **************************************************************************
function getItemGemScore(itemLink)
  return 0, ""
  
  --TODO GemScore
end


-- **************************************************************************
-- DESC : Returns the combined stats for the item, for the stats defined in STATTYPES
-- **************************************************************************
function getItemScore(itemLink)
  local score = 0

  -- Create the tooltip:
  local scantip = CreateFrame("GameTooltip", "MyScanningTooltip", nil, "GameTooltipTemplate")
  scantip:SetOwner(UIParent, "ANCHOR_NONE")

  -- Pass the item link to the tooltip:
  scantip:SetHyperlink(itemLink)

  -- Scan the tooltip:
  for i = 2, scantip:NumLines() do -- Line 1 is always the name so you can skip it.
    local text = _G["MyScanningTooltipTextLeft"..i]:GetText()
    debugMessage("debug text: "..text.." - numlines: "..i.."/"..scantip:NumLines(), 0)

    for index in ipairs(STATTYPES) do
      for w in gmatch(text, "([%d,%d-]+) ".. STATTYPES[index].text) do
        w = gsub(w, ",", "", 1)
        local num = tonumber(w)
        if(num) then
          score = score + num
        end
        debugMessage("text: "..text.." - w: "..w.." - score: "..score, 0)
      end
    end    
  end
  return score
end

-- **************************************************************************
-- DESC : Returns 1 if the itemSubType is a twohand weapon
-- **************************************************************************
function isWeaponTwoHand(itemSubType)
  debugMessage("itemSubType: "..itemSubType, 0)

  for index in ipairs(TWOHAND_WEAPONS) do
    for w in gmatch(itemSubType, TWOHAND_WEAPONS[index].text) do
      return 1;
    end
  end
  
  return 0;
end

-- **************************************************************************
-- DESC : Returns maximum possible gear items for the given level
-- **************************************************************************
function getMaxItemsForLevel(level)
  local count = 0;
  for index in ipairs(GEARLIST) do
    if (GEARLIST[index].minLevel > 0 and GEARLIST[index].minLevel <= level) then
      count = count +1;
    end 
  end
  debugMessage("GetMaxItemsForLevel: "..level.." is returning: "..count, 0);
  return count;
end

-- **************************************************************************
-- DESC : Get color for tooltip, based on the players average ilvl and the items iLlv
-- **************************************************************************
function getLevelColor(itemLevel, playerAverageItemLevel)
  local color = colorBlue;

  if (itemLevel == nil or playerAverageItemLevel == nil) then
    return colorBlue;
  end

  -- fix for itemlevels with '+', eg. 385+
  string.gsub(itemLevel, "+", "")
  local iLvl = tonumber(itemLevel)
  local iLevelDiff = (iLvl-playerAverageItemLevel);
  debugMessage("iLevelDiff: "..iLevelDiff, 0)

  for index in ipairs(AVG_GEAR_ILVL_COLOR_LIMIT) do
    if (iLevelDiff > AVG_GEAR_ILVL_COLOR_LIMIT[index].limit) then
      return AVG_GEAR_ILVL_COLOR_LIMIT[index].color;
    end
  end

  return color;
end

-- **************************************************************************
-- DESC :Get  color for tooltip, based on the difference in ilvl for the players equipped gear
-- colors and limits for colors defined in variables.lua AVG_GEAR_ILVL_COLOR_LIMIT
-- the function is used by TitanGearStatistics
-- **************************************************************************
function calculateColorTitan(iLevelDiff)
  local color = colorBlue;

  for index in ipairs(AVG_GEAR_ILVL_COLOR_LIMIT) do
    if (iLevelDiff > AVG_GEAR_ILVL_COLOR_LIMIT[index].limit) then
      return AVG_GEAR_ILVL_COLOR_LIMIT[index].color;
    end
  end

  return color;
end

-- **************************************************************************
-- DESC : DEBUG, show detailed information
-- **************************************************************************
function showCurrentPlayerData()
  -- write currentPlayer data to chat
  DEFAULT_CHAT_FRAME:AddMessage("Realm: ".. GSC.currentPlayer.realmName);
  DEFAULT_CHAT_FRAME:AddMessage("Faction: ".. GSC.currentPlayer.faction);
  DEFAULT_CHAT_FRAME:AddMessage("Player name: ".. GSC.currentPlayer.playerName);
  DEFAULT_CHAT_FRAME:AddMessage("Player level: ".. GSC.currentPlayer.playerLevel);
  DEFAULT_CHAT_FRAME:AddMessage("Class: ".. GSC.currentPlayer.class);
  DEFAULT_CHAT_FRAME:AddMessage("Gender: ".. GSC.currentPlayer.gender);
  DEFAULT_CHAT_FRAME:AddMessage("Race: ".. GSC.currentPlayer.race);
  DEFAULT_CHAT_FRAME:AddMessage("Guild: ".. GSC.currentPlayer.guild);
  DEFAULT_CHAT_FRAME:AddMessage("totalItemLevel: ".. GSC.currentPlayer.totalItemLevel);
  DEFAULT_CHAT_FRAME:AddMessage("totalItemScore: ".. GSC.currentPlayer.totalItemScore);
  DEFAULT_CHAT_FRAME:AddMessage("averageItemLevel: ".. GSC.currentPlayer.averageItemLevel);
  DEFAULT_CHAT_FRAME:AddMessage("averageItemScore: ".. GSC.currentPlayer.averageItemScore);
  DEFAULT_CHAT_FRAME:AddMessage("minItemLevel: ".. GSC.currentPlayer.minItemLevel);
  DEFAULT_CHAT_FRAME:AddMessage("maxItemLevel: ".. GSC.currentPlayer.maxItemLevel);
  DEFAULT_CHAT_FRAME:AddMessage("recordedTime: ".. GSC.currentPlayer.recordedTime);
  for index in ipairs(GEARLIST) do
    if(GSC.currentPlayer.itemList[GEARLIST[index].name].itemName) then
      DEFAULT_CHAT_FRAME:AddMessage("itemList: ".. GSC.currentPlayer.itemList[GEARLIST[index].name].itemName);
    end
  end
  
  DEFAULT_CHAT_FRAME:AddMessage("Data.Version: ".. GSC.Data.version);
end