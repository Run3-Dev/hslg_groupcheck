-- GroupCheck.lua (Retail 12.0+)
-- Posts a formatted party summary when a NEW member joins the party.
-- Only posts automatically if YOU are the party leader.
-- Includes a settings UI (Settings -> AddOns -> HSLG GroupCheck).
-- Slash commands:
--   /gc check   -> manual output (allowed for everyone)
--   /gc config  -> opens settings panel

local ADDON = ...
local f = CreateFrame("Frame")

-- SavedVariables (set in .toc: ## SavedVariables: GroupCheckDB)
GroupCheckDB = GroupCheckDB or {}

local DEFAULTS = {
  enabled = true,
  showHeader = true,
  checkBR = true,
  checkHT = true,
  checkStacking = true,
}

local function ApplyDefaults()
  if type(GroupCheckDB) ~= "table" then GroupCheckDB = {} end
  for k, v in pairs(DEFAULTS) do
    if GroupCheckDB[k] == nil then
      GroupCheckDB[k] = v
    end
  end
end

-- Classes that provide a battle resurrection option (class-based pragmatic check)
-- TWW: Paladin has a battle res (Intercession) -> include PALADIN.
local BATTLE_RES_CLASSES = {
  DRUID = true,
  DEATHKNIGHT = true,
  WARLOCK = true, -- Soulstone counts as "we have a BR option" for most groups
  PALADIN = true, -- TWW (12.0+)
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

-- Stored settings category ID (for Settings.OpenToCategory)
GroupCheckSettingsCategoryID = nil

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
  if not GroupCheckDB.enabled then return end
  if not IsInGroup() or IsInRaid() then return end

  local brCount, hasHero, stackingText = AnalyzeGroup()

  -- Build lines based on settings (send as separate chat lines)
  if GroupCheckDB.showHeader then
    SendChatMessage("HSLG GroupCheck", "PARTY")
  end

  if GroupCheckDB.checkBR then
    SendChatMessage(string.format("Available BattleRes: %d", brCount), "PARTY")
  end

  if GroupCheckDB.checkHT then
    SendChatMessage(string.format("Available Bloodlust: %s", hasHero and "yes" or "no"), "PARTY")
  end

  if GroupCheckDB.checkStacking then
    SendChatMessage(string.format("Class stacking: %s", stackingText), "PARTY")
  end
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
    knownGUIDs = {}
    initialized = false
    return
  end

  local now = GetTime()
  if (now - lastPostAt) < 0.8 then
    knownGUIDs = BuildCurrentGUIDSet()
    initialized = true
    return
  end

  local currentGUIDs = BuildCurrentGUIDSet()

  if not initialized then
    knownGUIDs = currentGUIDs
    initialized = true
    return
  end

  -- Only leader posts automatically; still keep state in sync so leader swap doesn't spam.
  if not UnitIsGroupLeader("player") then
    knownGUIDs = currentGUIDs
    return
  end

  if HasNewMember(knownGUIDs, currentGUIDs) then
    lastPostAt = now
    PostSummary()
  end

  knownGUIDs = currentGUIDs
end

-- -------------------------
-- Settings UI (12.0+)
-- -------------------------

local function CreateCheckbox(parent, label, tooltip, key, y)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
  cb.Text:SetText(label)

  cb:SetChecked(not not GroupCheckDB[key])

  cb:SetScript("OnClick", function(self)
    GroupCheckDB[key] = self:GetChecked() and true or false
  end)

  if tooltip and tooltip ~= "" then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(label) -- no wrap arg in some 12.0 builds
      GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true) -- wrapped
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  return cb
end

local function RegisterSettingsPanel()
  if not Settings or not Settings.RegisterCanvasLayoutCategory then
    return
  end

  local panel = CreateFrame("Frame")
  panel:Hide()

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("HSLG GroupCheck")

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Configure which lines are included when posting to party chat (auto-post is leader only).")

  local y = -60
  CreateCheckbox(panel, "Enable addon", "Master toggle for auto-posting and /gc check output.", "enabled", y); y = y - 28
  CreateCheckbox(panel, "Show header", "Posts the header line 'HSLG GroupCheck'.", "showHeader", y); y = y - 28
  CreateCheckbox(panel, "Check BR", "Includes 'Available BattleRes: {n}'.", "checkBR", y); y = y - 28
  CreateCheckbox(panel, "Check HT", "Includes 'Available Bloodlust: {yes/no}'.", "checkHT", y); y = y - 28
  CreateCheckbox(panel, "Check Class stacking", "Includes 'Class stacking: {yes: ... / no}'.", "checkStacking", y); y = y - 28

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 16, y - 8)
  hint:SetText("Tip: Use /gc check in a party to preview your current output. Use /gc config to open this panel.")

  local category = Settings.RegisterCanvasLayoutCategory(panel, "HSLG GroupCheck")
  Settings.RegisterAddOnCategory(category)

  GroupCheckSettingsCategoryID = category:GetID()
end

-- -------------------------
-- Events
-- -------------------------

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    ApplyDefaults()
    RegisterSettingsPanel()
    return
  end

  C_Timer.After(0.2, CheckRosterAndMaybePost)
end)

-- -------------------------
-- Slash command
-- -------------------------

SLASH_GROUPCHECK1 = "/gc"
SlashCmdList["GROUPCHECK"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  if msg == "check" then
    PostSummary()
    return
  end

  if msg == "config" then
    if GroupCheckSettingsCategoryID then
      Settings.OpenToCategory(GroupCheckSettingsCategoryID)
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[GroupCheck]|r Settings panel not registered yet. Try /reload.")
    end
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[GroupCheck]|r commands: /gc check, /gc config")
end
