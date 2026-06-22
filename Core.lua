-- Arena Talent Reminder
-- Core: addon object, shared lookup tables, talent helpers, DB, events.

local ADDON, ns = ...

local ATR = LibStub("AceAddon-3.0"):NewAddon(ADDON, "AceConsole-3.0", "AceEvent-3.0")
ns.ATR = ATR

-- The round-start marker is auto-cast by the player at the start of every round
-- (including each Solo Shuffle round), so it's a reliable, class-agnostic signal
-- to (re-)show the reminder. Hiding is driven by gates opening and combat.
local ROUND_START_SPELL = 228212 -- Arena Starting Area Marker

--------------------------------------------------------------------------------
-- Lookup tables (ported from the WeakAura init action)
--------------------------------------------------------------------------------

-- Class IDs in the display order the original config used.
ns.classMap = {
    6,  -- Death Knight
    12, -- Demon Hunter
    11, -- Druid
    13, -- Evoker
    3,  -- Hunter
    8,  -- Mage
    10, -- Monk
    2,  -- Paladin
    5,  -- Priest
    4,  -- Rogue
    7,  -- Shaman
    9,  -- Warlock
    1,  -- Warrior
}

-- Spec IDs in the display order the original config used.
ns.specMap = {
    250,  -- Death Knight - Blood
    251,  -- Death Knight - Frost
    252,  -- Death Knight - Unholy
    102,  -- Druid - Balance
    103,  -- Druid - Feral
    104,  -- Druid - Guardian
    105,  -- Druid - Restoration
    1467, -- Evoker - Devastation
    1468, -- Evoker - Preservation
    1473, -- Evoker - Augmentation
    253,  -- Hunter - Beast Mastery
    254,  -- Hunter - Marksmanship
    255,  -- Hunter - Survival
    62,   -- Mage - Arcane
    63,   -- Mage - Fire
    64,   -- Mage - Frost
    268,  -- Monk - Brewmaster
    270,  -- Monk - Windwalker
    269,  -- Monk - Mistweaver
    65,   -- Paladin - Holy
    66,   -- Paladin - Protection
    70,   -- Paladin - Retribution
    256,  -- Priest - Discipline
    257,  -- Priest - Holy
    258,  -- Priest - Shadow
    259,  -- Rogue - Assassination
    260,  -- Rogue - Outlaw
    261,  -- Rogue - Subtlety
    262,  -- Shaman - Elemental
    263,  -- Shaman - Enhancement
    264,  -- Shaman - Restoration
    265,  -- Warlock - Affliction
    266,  -- Warlock - Demonology
    267,  -- Warlock - Destruction
    71,   -- Warrior - Arms
    72,   -- Warrior - Fury
    73,   -- Warrior - Protection
}

-- Arena instance IDs and their display names, in the original config order.
ns.mapMap = {
    1552, 1504, 1672, 617, 2373, 2547, 1852, 2509,
    1911, 1505, 2563, 572, 2167, 1134, 980,
}
ns.mapNames = {
    "Ashamane's Fall", "Black Rook Hold", "Blade's Edge", "Dalaran Sewers",
    "Empyrean Domain", "Enigma Crucible", "Hook Point", "Maldraxxus Coliseum",
    "Mugambala", "Nagrand Arena", "Nokhudon Proving Grounds", "Ruins of Lordaeron",
    "The Robodrome", "Tiger's Peak", "Tol'Viron",
}

ns.compNames = { "Caster Cleave", "Melee Cleave", "Caster/Melee" }
ns.arenaTypeNames = { "Solo Shuffle", "2v2", "3v3" }

-- Spec classification used for comp-type detection (faithful to the WeakAura).
ns.casters = {
    [102] = true, [1467] = true, [253] = true, [254] = true, [62] = true,
    [63] = true, [64] = true, [258] = true, [262] = true, [265] = true,
    [266] = true, [267] = true,
}
ns.melee = {
    [250] = true, [251] = true, [252] = true, [577] = true, [581] = true,
    [103] = true, [104] = true, [255] = true, [268] = true, [269] = true,
    [70] = true, [259] = true, [260] = true,
}

--------------------------------------------------------------------------------
-- Talent helpers (ported from CanSpec / IsSpecced)
--------------------------------------------------------------------------------

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    return (GetSpellInfo(spellID))
end

-- Walks the active talent tree (and PvP talents) looking for an entry whose spell
-- name matches `talentName`. `committedOnly` restricts to currently selected ranks.
local function FindTalent(talentName, committedOnly)
    if not talentName or talentName == "" then return false end

    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID()
    if configID then
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo and configInfo.treeIDs then
            for _, treeID in ipairs(configInfo.treeIDs) do
                for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
                    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    local entries = committedOnly and nodeInfo.entryIDsWithCommittedRanks
                        or nodeInfo.entryIDs
                    if entries then
                        for _, entryID in ipairs(entries) do
                            local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                            if entryInfo and entryInfo.definitionID then
                                local def = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                                if def and def.spellID and GetSpellName(def.spellID) == talentName then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- PvP talents
    if committedOnly then
        for _, id in pairs(C_SpecializationInfo.GetAllSelectedPvpTalentIDs() or {}) do
            local info = C_SpecializationInfo.GetPvpTalentInfo(id)
            if info and info.name == talentName then return true end
        end
    else
        local slot = C_SpecializationInfo.GetPvpTalentSlotInfo(1)
        if slot and slot.availableTalentIDs then
            for _, id in pairs(slot.availableTalentIDs) do
                local info = C_SpecializationInfo.GetPvpTalentInfo(id)
                if info and info.name == talentName then return true end
            end
        end
    end

    return false
end

-- Is this talent available to choose for the current spec?
function ns.CanSpec(talentName)
    return FindTalent(talentName, false)
end

-- Is this talent currently selected?
function ns.IsSpecced(talentName)
    return FindTalent(talentName, true)
end

--------------------------------------------------------------------------------
-- Arena prep gate
--------------------------------------------------------------------------------

-- Show only in an arena, before the player has "left" prep, and never in combat.
function ATR:ShouldShow()
    if select(2, IsInInstance()) ~= "arena" then return false end
    if self.hidden then return false end
    if UnitAffectingCombat("player") then return false end
    return true
end

--------------------------------------------------------------------------------
-- DB defaults
--------------------------------------------------------------------------------

local defaults = {
    profile = {
        enabled = true,
        debug = false,
        rules = {
            class = {},
            spec = {},
            compType = {},
            map = {},
            arenaType = {},
            partnerClass = {},
            partnerSpec = {},
        },
        display = {
            point = "CENTER",
            relPoint = "CENTER",
            x = 0,
            y = 220,
            scale = 1,
            fontSize = 24,
            showIcon = true,
            locked = true,
        },
    },
}

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function ATR:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ArenaTalentReminderDB", defaults, true)
    self.testMode = false
    self.hidden = false

    self:SetupOptions()       -- Options.lua
    self:CreateDisplay()      -- Display.lua

    self:RegisterChatCommand("atr", "HandleCommand")
    self:RegisterChatCommand("arenatalentreminder", "HandleCommand")
end

-- Prints only when debug is on. Prefix makes it easy to spot/filter.
function ATR:Debug(fmt, ...)
    if not self.db or not self.db.profile.debug then return end
    print("|cff33ff99[ATR]|r " .. (select("#", ...) > 0 and fmt:format(...) or fmt))
end

function ATR:OnEnable()
    self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS", "OnArenaPrep")
    self:RegisterEvent("ARENA_OPPONENT_UPDATE", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Refresh")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("INSPECT_READY", "Refresh")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "Refresh")
    self:RegisterEvent("PLAYER_PVP_TALENT_UPDATE", "Refresh")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "Refresh")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellcast")
    self:RegisterEvent("PVP_MATCH_ACTIVE", "HideReminder")   -- gates open
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "Refresh")   -- entering combat
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")    -- leaving combat

    self:UpdateDisplaySettings()
    self:Refresh()
end

-- Gates have opened (or any other "match is live" signal): stop reminding.
function ATR:HideReminder()
    self.hidden = true
    self:Refresh()
end

function ATR:OnEnterWorld()
    -- Zoning in / first round: reset to shown.
    self.hidden = false
    self:Refresh()
end

function ATR:OnArenaPrep()
    -- New prep: reset to shown. Enemy specs are now available; partners need an inspect.
    self.hidden = false
    self:RequestPartnerInspects()
    self:Refresh()
end

function ATR:OnRosterUpdate()
    self:RequestPartnerInspects()
    self:Refresh()
end

-- The round-start marker re-shows the reminder at the start of each round.
function ATR:OnSpellcast(_, unit, _, spellID)
    if unit == "player" and spellID == ROUND_START_SPELL then
        self.hidden = false
        self:Refresh()
    end
end

function ATR:RequestPartnerInspects()
    if UnitExists("party1") then NotifyInspect("party1") end
    if UnitExists("party2") then NotifyInspect("party2") end
end

-- Evaluate the rules and push the result to the display.
function ATR:Refresh()
    if not self.db.profile.enabled then
        self:Debug("Refresh: addon disabled, hiding")
        self:UpdateDisplay(nil)
        return
    end

    if self.testMode then
        local messages = self:Evaluate(true)
        self:Debug("Refresh: TEST mode -> %d message(s)", #messages)
        self:UpdateDisplay(messages)
        return
    end

    if not self:ShouldShow() then
        self:Debug("Refresh: hiding (instance=%s hidden=%s combat=%s)",
            tostring(select(2, IsInInstance())), tostring(self.hidden),
            tostring(UnitAffectingCombat("player")))
        self:UpdateDisplay(nil)
        return
    end

    local messages = self:Evaluate(false)
    self:Debug("Refresh: in arena prep -> %d message(s)", #messages)
    self:UpdateDisplay(messages)
end

function ATR:OpenConfig()
    LibStub("AceConfigDialog-3.0"):Open(ADDON)
end

-- Slash handler: `/atr` opens config; subcommands toggle debug/test or print status.
function ATR:HandleCommand(input)
    local arg = (input or ""):lower():gsub("^%s+", ""):match("^(%S*)")

    if arg == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print("Debug " .. (self.db.profile.debug and "|cff33ff99ON|r" or "|cffff3333OFF|r")
            .. ". Re-run an arena prep or toggle test mode to see output.")
    elseif arg == "test" then
        self.testMode = not self.testMode
        self:Print("Test mode " .. (self.testMode and "|cff33ff99ON|r" or "|cffff3333OFF|r"))
        self:Refresh()
    elseif arg == "status" then
        self:PrintStatus()
    else
        self:OpenConfig()
    end
end

function ATR:PrintStatus()
    local p = self.db.profile
    self:Print(("enabled=%s | testMode=%s | debug=%s | instance=%s | hidden=%s | combat=%s | shouldShow=%s"):format(
        tostring(p.enabled), tostring(self.testMode), tostring(p.debug),
        tostring(select(2, IsInInstance())), tostring(self.hidden),
        tostring(UnitAffectingCombat("player")), tostring(self:ShouldShow())))
    self:Print(("arena opponents=%d, specs known=%d, soloShuffle=%s"):format(
        GetNumArenaOpponents(), GetNumArenaOpponentSpecs(), tostring(C_PvP.IsSoloShuffle())))

    local total = 0
    for _, cat in ipairs(ns.categories) do
        local n = #p.rules[cat.key]
        total = total + n
        if n > 0 then
            self:Print(("  %s: %d rule(s)"):format(cat.name, n))
        end
    end
    if total == 0 then
        self:Print("|cffff3333No rules configured.|r Open config with /atr and add some.")
    end
end
