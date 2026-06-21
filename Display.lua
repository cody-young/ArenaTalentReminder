-- Arena Talent Reminder
-- Display: the on-screen reminder frame.

local ADDON, ns = ...
local ATR = ns.ATR

local ARENA_PREP_ICON = "Interface\\Icons\\Spell_Nature_TimeStop" -- Arena Preparation

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
    f.icon:SetPoint("LEFT", 8, 0)
    f.icon:SetSize(40, 40)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.text:SetPoint("RIGHT", -8, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("MIDDLE")
    f.text:SetTextColor(1, 0.82, 0)

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

-- Apply position / scale / font / lock settings from the DB.
function ATR:UpdateDisplaySettings()
    local f = self.frame
    if not f then return end
    local d = self.db.profile.display

    f:ClearAllPoints()
    f:SetPoint(d.point, UIParent, d.relPoint, d.x, d.y)
    f:SetScale(d.scale)

    f.icon:SetShown(d.showIcon)
    if d.showIcon then
        f.text:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    else
        f.text:SetPoint("LEFT", f, "LEFT", 8, 0)
    end

    local fontFile, _, fontFlags = f.text:GetFont()
    f.text:SetFont(fontFile, d.fontSize, fontFlags or "OUTLINE")

    -- When unlocked, make the frame grabbable and always visible as an anchor.
    if d.locked then
        f:EnableMouse(false)
    else
        f:EnableMouse(true)
    end

    self:UpdateUnlockedAnchor()
end

-- While unlocked, show a placeholder so the user can position the frame.
function ATR:UpdateUnlockedAnchor()
    local f = self.frame
    if not f then return end
    if not self.db.profile.display.locked then
        f.text:SetText("Arena Talent Reminder|n(drag to move, lock when done)")
        f:SetHeight(64)
        f:Show()
    elseif not f.text:GetText() or f.text:GetText() == "" then
        f:Hide()
    end
end

-- messages: array of strings, or nil/empty to hide.
function ATR:UpdateDisplay(messages)
    local f = self.frame
    if not f then return end

    -- Unlocked anchor takes precedence so the user can always reposition.
    if not self.db.profile.display.locked then
        self:UpdateUnlockedAnchor()
        return
    end

    if not messages or #messages == 0 then
        f.text:SetText("")
        f:Hide()
        return
    end

    f.text:SetText(table.concat(messages, "|n"))
    -- Grow height to fit multiple lines.
    local lineH = self.db.profile.display.fontSize + 6
    f:SetHeight(math.max(64, #messages * lineH + 20))
    f:Show()
end
