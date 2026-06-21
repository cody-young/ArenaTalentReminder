-- Arena Talent Reminder
-- Engine: rule categories + evaluation (ported from the WeakAura custom trigger).

local ADDON, ns = ...
local ATR = ns.ATR

--------------------------------------------------------------------------------
-- Display-name helpers
--------------------------------------------------------------------------------

local function ClassName(classID)
    local name = GetClassInfo(classID)
    return name or ("Class " .. tostring(classID))
end

local function SpecName(specID)
    local _, specName, _, _, _, _, className = GetSpecializationInfoByID(specID)
    if className and specName then
        return className .. " - " .. specName
    end
    return specName or ("Spec " .. tostring(specID))
end

-- Build the { [index] = label } table + sorted index list for a dropdown.
local function MakeValues(getLabel, count)
    local values, sorting = {}, {}
    for i = 1, count do
        values[i] = getLabel(i)
        sorting[i] = i
    end
    return values, sorting
end

--------------------------------------------------------------------------------
-- Match helpers against the current arena context
--------------------------------------------------------------------------------

local function EnemyHasClass(classID)
    for i = 1, GetNumArenaOpponentSpecs() do
        local spec = GetArenaOpponentSpec(i)
        if spec and spec > 0 and GetClassIDFromSpecID(spec) == classID then
            return true
        end
    end
    return false
end

local function EnemyHasSpec(specID)
    for i = 1, GetNumArenaOpponentSpecs() do
        if GetArenaOpponentSpec(i) == specID then
            return true
        end
    end
    return false
end

local function IsThrees()
    return GetNumArenaOpponents() == 3 and not C_PvP.IsSoloShuffle()
end

--------------------------------------------------------------------------------
-- Category definitions
--
-- Each category:
--   key          db key under profile.rules
--   name         tab/group title
--   subjectName  label for the subject dropdown
--   help         description shown above the rules
--   values()     returns (valuesTable, sortingTable) for the dropdown
--   label(rule)  human name of the rule subject (used in the reminder text)
--   match(rule)  is this rule's subject present in the current arena context?
--------------------------------------------------------------------------------

ns.categories = {
    {
        key = "class",
        name = "Against Class",
        subjectName = "Opponent Class",
        help = "Trigger when the enemy team contains a given class.",
        values = function() return MakeValues(function(i) return ClassName(ns.classMap[i]) end, #ns.classMap) end,
        label = function(rule) return ClassName(ns.classMap[rule.subject]) end,
        match = function(rule) return EnemyHasClass(ns.classMap[rule.subject]) end,
    },
    {
        key = "spec",
        name = "Against Spec",
        subjectName = "Opponent Spec",
        help = "Trigger when the enemy team contains a given spec.",
        values = function() return MakeValues(function(i) return SpecName(ns.specMap[i]) end, #ns.specMap) end,
        label = function(rule) return SpecName(ns.specMap[rule.subject]) end,
        match = function(rule) return EnemyHasSpec(ns.specMap[rule.subject]) end,
    },
    {
        key = "compType",
        name = "Against Comp Type",
        subjectName = "Comp Type",
        help = "Trigger against a 3v3 comp type (two casters, two melee, or one of each). Only evaluated in 3v3.",
        values = function() return MakeValues(function(i) return ns.compNames[i] end, #ns.compNames) end,
        label = function(rule) return ns.compNames[rule.subject] end,
        match = function(rule)
            if not IsThrees() then return false end
            local numMelee, numCasters = 0, 0
            for i = 1, GetNumArenaOpponentSpecs() do
                local s = GetArenaOpponentSpec(i)
                if ns.melee[s] then
                    numMelee = numMelee + 1
                elseif ns.casters[s] then
                    numCasters = numCasters + 1
                end
            end
            local compID = rule.subject
            if numCasters == 2 then
                return compID == 1
            elseif numMelee == 2 then
                return compID == 2
            elseif numMelee == 1 and numCasters == 1 then
                return compID == 3
            end
            return false
        end,
    },
    {
        key = "map",
        name = "On Map",
        subjectName = "Map",
        help = "Trigger on a specific arena map.",
        values = function() return MakeValues(function(i) return ns.mapNames[i] end, #ns.mapMap) end,
        label = function(rule) return ns.mapNames[rule.subject] end,
        match = function(rule)
            local _, _, _, _, _, _, _, currentInstanceID = GetInstanceInfo()
            return ns.mapMap[rule.subject] == currentInstanceID
        end,
    },
    {
        key = "arenaType",
        name = "Arena Type",
        subjectName = "Bracket",
        help = "Trigger in a specific bracket (Solo Shuffle, 2v2, or 3v3).",
        values = function() return MakeValues(function(i) return ns.arenaTypeNames[i] end, #ns.arenaTypeNames) end,
        label = function(rule) return ns.arenaTypeNames[rule.subject] end,
        match = function(rule)
            local at = rule.subject
            if at == 1 then
                return C_PvP.IsSoloShuffle()
            elseif at == 2 then
                return GetNumArenaOpponents() == 2 and not C_PvP.IsSoloShuffle()
            elseif at == 3 then
                return IsThrees()
            end
            return false
        end,
    },
    {
        key = "partnerClass",
        name = "With Partner Class",
        subjectName = "Partner Class",
        help = "Trigger when one of your partners is a given class.",
        values = function() return MakeValues(function(i) return ClassName(ns.classMap[i]) end, #ns.classMap) end,
        label = function(rule) return ClassName(ns.classMap[rule.subject]) end,
        match = function(rule)
            local classID = ns.classMap[rule.subject]
            local _, _, c1 = UnitClass("party1")
            local _, _, c2 = UnitClass("party2")
            return c1 == classID or c2 == classID
        end,
    },
    {
        key = "partnerSpec",
        name = "With Partner Spec",
        subjectName = "Partner Spec",
        help = "Trigger when one of your partners is a given spec. Requires an inspect, so this may take a moment to populate.",
        values = function() return MakeValues(function(i) return SpecName(ns.specMap[i]) end, #ns.specMap) end,
        label = function(rule) return SpecName(ns.specMap[rule.subject]) end,
        match = function(rule)
            local specID = ns.specMap[rule.subject]
            return GetInspectSpecialization("party1") == specID
                or GetInspectSpecialization("party2") == specID
        end,
    },
}

-- Quick lookup by key.
ns.categoryByKey = {}
for _, cat in ipairs(ns.categories) do
    ns.categoryByKey[cat.key] = cat
end

--------------------------------------------------------------------------------
-- Evaluation
--------------------------------------------------------------------------------

-- Returns an array of reminder strings (deduped). In test mode every rule's
-- subject is treated as present, so you can preview your full rule set.
function ATR:Evaluate(isTest)
    local rules = self.db.profile.rules
    local messages, seen = {}, {}

    for _, cat in ipairs(ns.categories) do
        for _, rule in ipairs(rules[cat.key]) do
            local talentName = rule.talent
            if talentName and talentName ~= "" and ns.CanSpec(talentName) then
                local found = isTest or cat.match(rule)
                if found then
                    local has = ns.IsSpecced(talentName)
                    local should = rule.should or 1
                    local subject = cat.label(rule)
                    local msg

                    if should == 1 and not has then
                        msg = ("Found %s but missing %s"):format(subject, talentName)
                    elseif should == 2 and has then
                        msg = ("Found %s but have %s"):format(subject, talentName)
                    end

                    if msg and not seen[msg] then
                        seen[msg] = true
                        messages[#messages + 1] = msg
                    end
                end
            end
        end
    end

    return messages
end
