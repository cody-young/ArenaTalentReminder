-- Arena Talent Reminder
-- Options: AceConfig table replacing the WeakAura author options.

local ADDON, ns = ...
local ATR = ns.ATR

local SHOULD_VALUES = { [1] = "Should have", [2] = "Shouldn't have" }
local PRESENCE_VALUES = { [1] = "is present", [2] = "is absent" }

-- Build the dynamic args (one inline group per rule) for a category.
local function BuildCategoryArgs(cat)
    local args = {}
    local rules = ATR.db.profile.rules[cat.key]
    local values, sorting = cat.values()

    args.help = {
        type = "description",
        order = 1,
        name = cat.help .. "\n",
        fontSize = "medium",
    }

    args.add = {
        type = "execute",
        order = 2,
        name = "Add Rule",
        func = function()
            table.insert(rules, { subject = 1, presence = 1, should = 1, talent = "" })
            ATR:RefreshOptions()
            ATR:Refresh()
        end,
    }

    if #rules == 0 then
        args.empty = {
            type = "description",
            order = 3,
            name = "|cff808080No rules yet.|r",
        }
    end

    for i, rule in ipairs(rules) do
        args["rule" .. i] = {
            type = "group",
            inline = true,
            order = 10 + i,
            name = "Rule " .. i,
            args = {
                subject = {
                    type = "select",
                    order = 1,
                    width = 1.3,
                    name = cat.subjectName,
                    values = values,
                    sorting = sorting,
                    get = function() return rule.subject end,
                    set = function(_, v) rule.subject = v; ATR:Refresh() end,
                },
                presence = {
                    type = "select",
                    order = 2,
                    width = 0.9,
                    name = "When subject",
                    values = PRESENCE_VALUES,
                    get = function() return rule.presence or 1 end,
                    set = function(_, v) rule.presence = v; ATR:Refresh() end,
                },
                should = {
                    type = "select",
                    order = 3,
                    width = 1.0,
                    name = "Then you",
                    values = SHOULD_VALUES,
                    get = function() return rule.should end,
                    set = function(_, v) rule.should = v; ATR:Refresh() end,
                },
                talent = {
                    type = "input",
                    order = 4,
                    width = 1.4,
                    name = "Talent name",
                    desc = "Exact talent name (including PvP talents) as it appears in-game.",
                    get = function() return rule.talent end,
                    set = function(_, v) rule.talent = strtrim(v or ""); ATR:Refresh() end,
                },
                remove = {
                    type = "execute",
                    order = 5,
                    width = 0.6,
                    name = "Delete",
                    func = function()
                        table.remove(rules, i)
                        ATR:RefreshOptions()
                        ATR:Refresh()
                    end,
                },
            },
        }
    end

    return args
end

local function BuildOptions()
    local options = {
        type = "group",
        name = "Arena Talent Reminder",
        args = {
            general = {
                type = "group",
                order = 1,
                name = "General",
                args = {
                    enabled = {
                        type = "toggle",
                        order = 1,
                        width = "full",
                        name = "Enable reminders",
                        get = function() return ATR.db.profile.enabled end,
                        set = function(_, v) ATR.db.profile.enabled = v; ATR:Refresh() end,
                    },
                    testMode = {
                        type = "toggle",
                        order = 2,
                        width = "full",
                        name = "Test mode (preview all rules now)",
                        desc = "Show every configured rule on screen regardless of the current arena, so you can preview your setup outside of a match.",
                        get = function() return ATR.testMode end,
                        set = function(_, v) ATR.testMode = v; ATR:Refresh() end,
                    },
                    debug = {
                        type = "toggle",
                        order = 3,
                        width = "full",
                        name = "Debug messages",
                        desc = "Print why each rule does or doesn't fire to the chat frame. Also: /atr debug, /atr status.",
                        get = function() return ATR.db.profile.debug end,
                        set = function(_, v) ATR.db.profile.debug = v end,
                    },
                    displayHeader = {
                        type = "header",
                        order = 10,
                        name = "Display",
                    },
                    locked = {
                        type = "toggle",
                        order = 11,
                        name = "Lock frame",
                        desc = "Unlock to drag the reminder frame to a new position.",
                        get = function() return ATR.db.profile.display.locked end,
                        set = function(_, v)
                            ATR.db.profile.display.locked = v
                            ATR:UpdateDisplaySettings()
                            ATR:Refresh()
                        end,
                    },
                    showIcon = {
                        type = "toggle",
                        order = 12,
                        name = "Show icon",
                        get = function() return ATR.db.profile.display.showIcon end,
                        set = function(_, v)
                            ATR.db.profile.display.showIcon = v
                            ATR:UpdateDisplaySettings()
                        end,
                    },
                    scale = {
                        type = "range",
                        order = 13,
                        name = "Scale",
                        min = 0.5, max = 3, step = 0.05,
                        get = function() return ATR.db.profile.display.scale end,
                        set = function(_, v)
                            ATR.db.profile.display.scale = v
                            ATR:UpdateDisplaySettings()
                        end,
                    },
                    fontSize = {
                        type = "range",
                        order = 14,
                        name = "Font size",
                        min = 10, max = 48, step = 1,
                        get = function() return ATR.db.profile.display.fontSize end,
                        set = function(_, v)
                            ATR.db.profile.display.fontSize = v
                            ATR:UpdateDisplaySettings()
                            ATR:Refresh()
                        end,
                    },
                    resetPos = {
                        type = "execute",
                        order = 15,
                        name = "Reset position",
                        func = function()
                            local d = ATR.db.profile.display
                            d.point, d.relPoint, d.x, d.y = "CENTER", "CENTER", 0, 220
                            ATR:UpdateDisplaySettings()
                        end,
                    },
                },
            },
        },
    }

    -- One tab per rule category; args populated by RefreshOptions().
    for i, cat in ipairs(ns.categories) do
        options.args[cat.key] = {
            type = "group",
            order = 10 + i,
            name = cat.name,
            args = {},
        }
    end

    return options
end

function ATR:SetupOptions()
    self.options = BuildOptions()

    local AceConfig = LibStub("AceConfig-3.0")
    AceConfig:RegisterOptionsTable(ADDON, self.options)

    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:SetDefaultSize(ADDON, 720, 560)
    self.blizCategory = dialog:AddToBlizOptions(ADDON, "Arena Talent Reminder")

    self:RefreshOptions()
end

-- Rebuild the dynamic per-category rule lists and refresh any open dialog.
function ATR:RefreshOptions()
    if not self.options then return end
    for _, cat in ipairs(ns.categories) do
        local group = self.options.args[cat.key]
        wipe(group.args)
        for k, v in pairs(BuildCategoryArgs(cat)) do
            group.args[k] = v
        end
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON)
end
