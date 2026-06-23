-- Arena Talent Reminder
-- Display: the on-screen reminder frame.

local ADDON, ns = ...
local ATR = ns.ATR

local ARENA_PREP_ICON = "Interface\\Icons\\Spell_Nature_TimeStop" -- Arena Preparation
local NOTE_ICON = "Interface\\FriendsFrame\\InformationIcon"      -- info icon for notes
local BIG_ICON = 40   -- main reminder icon size
local PAD = 8         -- inner margin on every side
local GAP = 8         -- gap between the icon and the reminder text
local VGAP = 4        -- gap between the reminder block and the notes block

local function NoteFontSize(d)
    return math.max(9, math.floor(d.fontSize * 0.65))
end

function ATR:CreateDisplay()
    if self.frame then return end

    local f = CreateFrame("Frame", "ArenaTalentReminderFrame", UIParent, "BackdropTemplate")
    f:SetSize(360, 64)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.6)
    f:SetBackdropBorderColor(0.8, 0.1, 0.1, 1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexture(ARENA_PREP_ICON)
    f.icon:SetSize(BIG_ICON, BIG_ICON)

    -- Actionable reminders: large, gold. Word wrap must stay ON: a non-wrapping
    -- FontString renders only its first line, dropping every line after a |n, so
    -- multiple reminders would collapse to one. We never set an explicit width, so
    -- the string sizes to its longest line and only |n introduces line breaks.
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetWordWrap(true)
    f.text:SetTextColor(1, 0.82, 0)

    -- Informational suppression notes: smaller, gray. Word wrap ON for the same
    -- multi-line reason as f.text above.
    f.notes = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.notes:SetJustifyH("LEFT")
    f.notes:SetJustifyV("TOP")
    f.notes:SetWordWrap(true)
    f.notes:SetTextColor(0.62, 0.62, 0.62)

    -- Dragging (only honored while unlocked).
    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        if not ATR.db.profile.display.locked then frame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local d = ATR.db.profile.display
        local point, _, relPoint, x, y = frame:GetPoint()
        d.point, d.relPoint, d.x, d.y = point, relPoint, x, y
    end)

    self.frame = f
    self:UpdateDisplaySettings()
    f:Hide()
end

-- Apply position / scale / fonts / lock from the DB.
function ATR:UpdateDisplaySettings()
    local f = self.frame
    if not f then return end
    local d = self.db.profile.display

    f:ClearAllPoints()
    f:SetPoint(d.point, UIParent, d.relPoint, d.x, d.y)
    f:SetScale(d.scale)

    local fontFile, _, flags = f.text:GetFont()
    f.text:SetFont(fontFile, d.fontSize, flags or "OUTLINE")
    f.notes:SetFont(fontFile, NoteFontSize(d), flags or "OUTLINE")

    f:EnableMouse(not d.locked)

    self:UpdateUnlockedAnchor()
end

-- Prefix each plain note string with a small inline info icon and join them.
function ATR:FormatNotes(notesList)
    if not notesList or #notesList == 0 then return "" end
    local size = NoteFontSize(self.db.profile.display)
    local prefix = ("|T%s:%d:%d|t "):format(NOTE_ICON, size, size)
    local lines = {}
    for i, n in ipairs(notesList) do
        lines[i] = prefix .. n
    end
    return table.concat(lines, "|n")
end

-- Lay out icon + reminder text + notes and size the frame (border) to hug them.
function ATR:LayoutDisplay(reminderText, noteText)
    local f = self.frame
    local d = self.db.profile.display

    f.text:SetText(reminderText or "")
    f.notes:SetText(noteText or "")

    local hasRem = (reminderText or "") ~= ""
    local hasNotes = (noteText or "") ~= ""

    local remW = hasRem and (f.text:GetUnboundedStringWidth() or 0) or 0
    local remH = hasRem and (f.text:GetStringHeight() or 0) or 0
    local noteW = hasNotes and (f.notes:GetUnboundedStringWidth() or 0) or 0
    local noteH = hasNotes and (f.notes:GetStringHeight() or 0) or 0

    local iconShown = d.showIcon and hasRem
    local iconW = iconShown and BIG_ICON or 0
    local iconGap = iconShown and GAP or 0

    local blockH = hasRem and math.max(iconW > 0 and BIG_ICON or 0, remH) or 0
    local blockW = iconW + iconGap + remW

    local contentW = math.max(blockW, noteW)
    local contentH = blockH
    if hasRem and hasNotes then contentH = contentH + VGAP end
    if hasNotes then contentH = contentH + noteH end

    f:SetWidth(PAD + contentW + PAD)
    f:SetHeight(PAD + contentH + PAD)

    -- Position children from the frame's TOPLEFT.
    if iconShown then
        f.icon:Show()
        f.icon:ClearAllPoints()
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(PAD + (blockH - BIG_ICON) / 2))
    else
        f.icon:Hide()
    end

    f.text:ClearAllPoints()
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + iconW + iconGap, -(PAD + (blockH - remH) / 2))

    f.notes:ClearAllPoints()
    local notesY = PAD + blockH + ((hasRem and hasNotes) and VGAP or 0)
    f.notes:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -notesY)
end

-- While unlocked, show a placeholder so the user can position the frame.
function ATR:UpdateUnlockedAnchor()
    local f = self.frame
    if not f then return end
    if not self.db.profile.display.locked then
        self:LayoutDisplay("Arena Talent Reminder|n(drag to move, lock when done)", "")
        f:Show()
    elseif (f.text:GetText() or "") == "" and (f.notes:GetText() or "") == "" then
        f:Hide()
    end
end

-- result: { reminders = {...}, notes = {...} }, or nil to hide.
function ATR:UpdateDisplay(result)
    local f = self.frame
    if not f then return end

    -- Unlocked anchor takes precedence so the user can always reposition.
    if not self.db.profile.display.locked then
        self:UpdateUnlockedAnchor()
        return
    end

    local reminders = result and result.reminders
    local notes = result and result.notes
    local hasRem = reminders and #reminders > 0
    local hasNotes = notes and #notes > 0

    if not hasRem and not hasNotes then
        f.text:SetText("")
        f.notes:SetText("")
        f:Hide()
        return
    end

    local reminderText = hasRem and table.concat(reminders, "|n") or ""
    local noteText = self:FormatNotes(hasNotes and notes or nil)
    self:LayoutDisplay(reminderText, noteText)
    f:Show()
end
