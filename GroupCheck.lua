-- GroupCheck.lua (Retail 12.0+)
-- Posts a formatted party/instance summary when a NEW member joins the party.
-- Only posts automatically if the player is the party leader.
-- Includes a settings UI (Settings -> AddOns -> M+ GroupCheck).
-- Slash commands:
--   /gc check   -> manual output (local preview; works solo)
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
  showSuggestions = true,
}

local function ApplyDefaults()
  if type(GroupCheckDB) ~= "table" then GroupCheckDB = {} end
  for k, v in pairs(DEFAULTS) do
    if GroupCheckDB[k] == nil then
      GroupCheckDB[k] = v
    end
  end
end

local BATTLE_RES_CLASSES = {
  DRUID = true,
  DEATHKNIGHT = true,
  WARLOCK = true,
  PALADIN = true, -- TWW (12.0+)
}

local HERO_CLASSES = {
  SHAMAN = true,
  MAGE = true,
  HUNTER = true,
  EVOKER = true,
}

local SUGGESTED_HT_CLASSES = { "Mage", "Evoker", "Shaman", "Hunter" }
local SUGGESTED_BR_CLASSES = { "Death Knight", "Druid", "Paladin", "Warlock" }

local knownGUIDs = {}
local initialized = false
local lastPostAt = 0

GroupCheckSettingsCategoryID = nil

local function PrintLocal(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[GroupCheck]|r " .. tostring(msg))
end

local function GetOutputChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  end
  return "PARTY"
end

local function GetRemainingSlots()
  if not IsInGroup() then return 4 end
  return 5 - GetNumGroupMembers()
end

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

  addUnit("player")
  for i = 1, 4 do
    addUnit("party" .. i)
  end

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

local function GetMissingWarnings(brCount, hasHero)
  local missing = {}
  if brCount == 0 then table.insert(missing, "BattleRes") end
  if not hasHero then table.insert(missing, "Bloodlust") end
  return missing
end

local WARNING_PREFIX = "[!]"

local function BuildSummaryLines(brCount, hasHero, stackingText)
  local lines = {}

  if GroupCheckDB.showHeader then
    table.insert(lines, "M+ GroupCheck")
  end

  if GroupCheckDB.checkBR and brCount > 0 then
    table.insert(lines, string.format("Available BattleRes: %d", brCount))
  end

  if GroupCheckDB.checkHT and hasHero then
    table.insert(lines, "Available Bloodlust: yes")
  end

  if GroupCheckDB.checkStacking then
    table.insert(lines, string.format("Class stacking: %s", stackingText))
  end

  return lines
end

local function BuildSuggestions(brCount, hasHero)
  if not GroupCheckDB.showSuggestions then
    return {}
  end

  local suggestions = {}
  local remainingSlots = GetRemainingSlots()
  local needsHT = not hasHero
  local needsBR = (brCount == 0)

  if remainingSlots == 1 then
    if needsHT then
      table.insert(suggestions, { label = "Suggested class for Bloodlust", classes = SUGGESTED_HT_CLASSES })
      return suggestions
    end
    if needsBR then
      table.insert(suggestions, { label = "Suggested class for BattleRes", classes = SUGGESTED_BR_CLASSES })
      return suggestions
    end
    return suggestions
  end

  if needsHT then
    table.insert(suggestions, { label = "Suggested class for Bloodlust", classes = SUGGESTED_HT_CLASSES })
  end

  if needsBR then
    table.insert(suggestions, { label = "Suggested class for BattleRes", classes = SUGGESTED_BR_CLASSES })
  end

  return suggestions
end

local function PostSummary(mode)
  mode = mode or "AUTO"

  if not GroupCheckDB.enabled then
    if mode == "LOCAL" then
      PrintLocal("Addon is disabled in settings (Enable addon).")
    end
    return
  end

  if not IsInGroup() then
    if mode == "LOCAL" then
      local brCount, hasHero, stackingText = AnalyzeGroup()
      local missing = GetMissingWarnings(brCount, hasHero)

      PrintLocal("Solo check:")
      if #missing > 0 then
        PrintLocal("WARNING: Missing " .. table.concat(missing, ", "))
      end

      local lines = BuildSummaryLines(brCount, hasHero, stackingText)
      if #lines == 0 then
        PrintLocal("Nothing to output (all lines disabled or nothing available).")
        return
      end

      for _, l in ipairs(lines) do
        PrintLocal(l)
      end
    end
    return
  end

  if IsInRaid() then
    if mode == "LOCAL" then
      PrintLocal("In a raid. Party-only.")
    end
    return
  end

  local brCount, hasHero, stackingText = AnalyzeGroup()
  local missing = GetMissingWarnings(brCount, hasHero)

  if mode == "LOCAL" then
    if #missing > 0 then
      PrintLocal("WARNING: Missing " .. table.concat(missing, ", "))
    end

    local suggestions = BuildSuggestions(brCount, hasHero)
    if #suggestions > 0 and GetNumGroupMembers() < 5 then
      for _, entry in ipairs(suggestions) do
        PrintLocal(entry.label .. ": " .. table.concat(entry.classes, ", "))
      end
    end

    local lines = BuildSummaryLines(brCount, hasHero, stackingText)
    if #lines == 0 then
      PrintLocal("Nothing to output (all lines disabled or nothing available).")
      return
    end
    for _, l in ipairs(lines) do PrintLocal(l) end
    return
  end

  local channel = GetOutputChannel()

  if #missing > 0 then
    SendChatMessage(WARNING_PREFIX .. " M+ GroupCheck Warning", channel)
    SendChatMessage("Missing " .. table.concat(missing, ", "), channel)
  end

  local lines = BuildSummaryLines(brCount, hasHero, stackingText)
  if #lines == 0 then return end
  for _, l in ipairs(lines) do
    SendChatMessage(l, channel)
  end
end

local function BuildCurrentGUIDSet()
  local current = {}
  local pg = UnitGUID("player")
  if pg then current[pg] = true end

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

  if not UnitIsGroupLeader("player") then
    knownGUIDs = currentGUIDs
    return
  end

  if HasNewMember(knownGUIDs, currentGUIDs) then
    lastPostAt = now

    local members = GetNumGroupMembers()
    if members >= 5 then
      PostSummary("AUTO")
    else
      PostSummary("LOCAL")
    end
  end

  knownGUIDs = currentGUIDs
end

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
      GameTooltip:SetText(label)
      GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true)
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
  title:SetText("M+ GroupCheck")

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Configure which lines are included when posting to party/instance chat (auto-post is leader only).")

  local y = -60
  CreateCheckbox(panel, "Enable addon", "Master toggle for auto-posting and /gc check output.", "enabled", y); y = y - 28
  CreateCheckbox(panel, "Show header", "Posts the header line 'M+ GroupCheck'.", "showHeader", y); y = y - 28
  CreateCheckbox(panel, "Check BR", "Shows 'Available BattleRes' only when BR is present. Missing BR is reported via warning.", "checkBR", y); y = y - 28
  CreateCheckbox(panel, "Check HT", "Shows 'Available Bloodlust' only when Bloodlust is present. Missing Bloodlust is reported via warning.", "checkHT", y); y = y - 28
  CreateCheckbox(panel, "Check Class stacking", "Includes 'Class stacking: {yes: ... / no}'.", "checkStacking", y); y = y - 28
  CreateCheckbox(panel, "Show suggestions", "Shows local suggestions for missing Bloodlust/BattleRes while building the group.", "showSuggestions", y); y = y - 28

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 16, y - 8)
  hint:SetText("Tip: /gc check shows a local preview. /gc config opens this panel.")

  local category = Settings.RegisterCanvasLayoutCategory(panel, "M+ GroupCheck")
  Settings.RegisterAddOnCategory(category)
  GroupCheckSettingsCategoryID = category:GetID()
end

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

SLASH_GROUPCHECK1 = "/gc"
SlashCmdList["GROUPCHECK"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  if msg == "check" then
    PostSummary("LOCAL")
    return
  end

  if msg == "config" then
    if GroupCheckSettingsCategoryID then
      Settings.OpenToCategory(GroupCheckSettingsCategoryID)
    else
      PrintLocal("Settings panel not registered yet. Try /reload.")
    end
    return
  end

  PrintLocal("commands: /gc check, /gc config")
end
