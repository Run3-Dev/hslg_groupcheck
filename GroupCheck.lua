-- GroupCheck.lua (Retail)
-- Posts a formatted group utility summary when a NEW member joins the party.
-- Only posts if YOU are the party leader.

local ADDON = ...
local f = CreateFrame("Frame")

-- Classes that provide a battle resurrection option (class-based pragmatic check)
local BATTLE_RES_CLASSES = {
  DRUID = true,
  DEATHKNIGHT = true,
  WARLOCK = true, -- Soulstone counts as "we have a BR option" for most groups
}

-- Classes that can provide Heroism/Bloodlust (HT)
local HERO_CLASSES = {
  SHAMAN = true,
  MAGE = true,
  HUNTER = true,  -- via pet
  EVOKER = true,
}

-- State
local knownGUIDs = {}     -- set of GUIDs currently in group
local initialized = false -- prevents posting on first roster scan after login/reload
local lastPostAt = 0      -- basic anti-spam throttle (seconds)

local function AnalyzeGroup()
  local classCount = {}
  local brCount = 0
  local hasHero = false

  local function addUnit(unit)
    if not UnitExists(unit) then return end
    local _, classTag = UnitClass(unit)
    if not classTag then return end

    classCount[classTag] = (classCount[classTag] or 0) + 1
    if BATTLE_RES_CLASSES[classTag] then
      brCount = brCount + 1
    end
    if HERO_CLASSES[classTag] then
      hasHero = true
    end
  end

  -- 5-man party: player + party1..party4
  addUnit("player")
  for i = 1, 4 do addUnit("party" .. i) end

  -- Build stacking summary
  local stackedParts = {}
  for classTag, count in pairs(classCount) do
    if count > 1 then
      local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classTag]) or classTag
      table.insert(stackedParts, string.format("%d %s", count, className))
    end
  end
  table.sort(stackedParts)

  local stackingText
  if #stackedParts > 0 then
    stackingText = "yes: " .. table.concat(stackedParts, ", ")
  else
    stackingText = "no"
  end

  return brCount, hasHero, stackingText
end

local function PostSummary()
  if not IsInGroup() or IsInRaid() then return end

  -- Only leader posts
  if not UnitIsGroupLeader("player") then return end

  local brCount, hasHero, stackingText = AnalyzeGroup()

  -- 4 separate chat lines (most reliable; single-message newlines can be flaky)
  SendChatMessage("HSLG GroupCheck", "PARTY")
  SendChatMessage(string.format("Available BattleRes: %d", brCount), "PARTY")
  SendChatMessage(string.format("Available Bloodlust: %s", hasHero and "yes" or "no"), "PARTY")
  SendChatMessage(string.format("Class stacking: %s", stackingText), "PARTY")
end

local function BuildCurrentGUIDSet()
  local current = {}

  -- player
  local pg = UnitGUID("player")
  if pg then current[pg] = true end

  -- party1..party4
  for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists(unit) then
      local g = UnitGUID(unit)
      if g then current[g] = true end
    end
  end

  return current
end

local function HasNewMember(oldSet, newSet)
  for guid, _ in pairs(newSet) do
    if not oldSet[guid] then
      return true
    end
  end
  return false
end

local function CheckRosterAndMaybePost()
  if not IsInGroup() or IsInRaid() then
    -- reset state when leaving group / entering raid
    knownGUIDs = {}
    initialized = false
    return
  end

  -- Only leader should react at all (but still keep state in sync)
  if not UnitIsGroupLeader("player") then
    knownGUIDs = BuildCurrentGUIDSet()
    initialized = true
    return
  end

  local now = GetTime()
  -- tiny throttle to avoid multi-event bursts posting twice
  if (now - lastPostAt) < 0.8 then
    knownGUIDs = BuildCurrentGUIDSet()
    initialized = true
    return
  end

  local currentGUIDs = BuildCurrentGUIDSet()

  if not initialized then
    -- First scan after login/reload: just learn the roster, don't post.
    knownGUIDs = currentGUIDs
    initialized = true
    return
  end

  if HasNewMember(knownGUIDs, currentGUIDs) then
    lastPostAt = now
    PostSummary()
  end

  knownGUIDs = currentGUIDs
end

f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
  -- delay helps when GUID/class info isn’t ready yet
  C_Timer.After(0.2, CheckRosterAndMaybePost)
end)

-- Manual test
SLASH_GROUPCHECK1 = "/gc"
SlashCmdList["GROUPCHECK"] = function(msg)
  msg = (msg or ""):lower()

  if msg == "check" then
    if UnitIsGroupLeader("player") then
      PostSummary()
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[GroupCheck]|r You are not the group leader.")
    end
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[GroupCheck]|r commands: /gc test")
end
