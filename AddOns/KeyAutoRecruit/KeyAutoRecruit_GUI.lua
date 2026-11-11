-- KeyAutoRecruit_GUI.lua
-- Графический интерфейс настроек авто-набора в ключи The War Within

local KAR = KeyAutoRecruit
local guiFrame = nil

local CLASS_LOCALIZED = {
    ["WARRIOR"]     = "Воин (Warrior)",
    ["PALADIN"]     = "Паладин (Paladin)",
    ["HUNTER"]      = "Охотник (Hunter)",
    ["ROGUE"]       = "Разбойник (Rogue)",
    ["PRIEST"]      = "Жрец (Priest)",
    ["DEATHKNIGHT"] = "Рыцарь смерти (DK)",
    ["SHAMAN"]      = "Шаман (Shaman)",
    ["MAGE"]        = "Маг (Mage)",
    ["WARLOCK"]     = "Чернокнижник (Warlock)",
    ["MONK"]        = "Монах (Monk)",
    ["DRUID"]       = "Друид (Druid)",
    ["DEMONHUNTER"] = "Охотник на демонов (DH)",
    ["EVOKER"]      = "Пробудитель (Evoker)",
}


-- -------------------------------------------------------------
-- HELLSING / ALUCARD ULTIMATE GOTHIC UI KIT (GRAPHICAL EDITION)
-- -------------------------------------------------------------
local TEXTURE_DIR = "Interface\\AddOns\\KeyAutoRecruit\\Textures\\"

local CLASS_ICONS_GOTHIC = {
    ["WARRIOR"]     = TEXTURE_DIR .. "crest_warrior.tga",
    ["PALADIN"]     = TEXTURE_DIR .. "crest_paladin.tga",
    ["HUNTER"]      = TEXTURE_DIR .. "crest_hunter.tga",
    ["ROGUE"]       = TEXTURE_DIR .. "crest_rogue.tga",
    ["PRIEST"]      = TEXTURE_DIR .. "crest_priest.tga",
    ["DEATHKNIGHT"] = TEXTURE_DIR .. "crest_deathknight.tga",
    ["SHAMAN"]      = TEXTURE_DIR .. "crest_shaman.tga",
    ["MAGE"]        = TEXTURE_DIR .. "crest_mage.tga",
    ["WARLOCK"]     = TEXTURE_DIR .. "crest_warlock.tga",
    ["MONK"]        = TEXTURE_DIR .. "crest_monk.tga",
    ["DRUID"]       = TEXTURE_DIR .. "crest_druid.tga",
    ["DEMONHUNTER"] = TEXTURE_DIR .. "crest_demonhunter.tga",
    ["EVOKER"]      = TEXTURE_DIR .. "crest_evoker.tga",
}

local CLASS_BARS_GOTHIC = {
    ["WARRIOR"]     = TEXTURE_DIR .. "class_bar_warrior.tga",
    ["PALADIN"]     = TEXTURE_DIR .. "class_bar_paladin.tga",
    ["HUNTER"]      = TEXTURE_DIR .. "class_bar_hunter.tga",
    ["ROGUE"]       = TEXTURE_DIR .. "class_bar_rogue.tga",
    ["PRIEST"]      = TEXTURE_DIR .. "class_bar_priest.tga",
    ["DEATHKNIGHT"] = TEXTURE_DIR .. "class_bar_deathknight.tga",
    ["SHAMAN"]      = TEXTURE_DIR .. "class_bar_shaman.tga",
    ["MAGE"]        = TEXTURE_DIR .. "class_bar_mage.tga",
    ["WARLOCK"]     = TEXTURE_DIR .. "class_bar_warlock.tga",
    ["MONK"]        = TEXTURE_DIR .. "class_bar_monk.tga",
    ["DRUID"]       = TEXTURE_DIR .. "class_bar_druid.tga",
    ["DEMONHUNTER"] = TEXTURE_DIR .. "class_bar_demonhunter.tga",
    ["EVOKER"]      = TEXTURE_DIR .. "class_bar_evoker.tga",
}

local ROLE_ICONS_GOTHIC = {
    ["TANK"]   = TEXTURE_DIR .. "crest_tank.tga",
    ["HEALER"] = TEXTURE_DIR .. "crest_healer.tga",
    ["DPS"]    = TEXTURE_DIR .. "crest_dps.tga",
}

local guiFrame = nil
local recentGroupsFrame = nil
local blacklistFrame = nil
local pasteFrame = nil
local heuristicsFrame = nil

local recentGroupWidgets = {}
local blacklistWidgets = {}
local blacklistSearchQuery = ""
local hRowWidgets = {}


-- Forward declaration of Navigation Controller
function KAR.CloseAllWindows(exceptFrame)
    if guiFrame and guiFrame ~= exceptFrame and guiFrame:IsShown() then guiFrame:Hide() end
    if recentGroupsFrame and recentGroupsFrame ~= exceptFrame and recentGroupsFrame:IsShown() then recentGroupsFrame:Hide() end
    if blacklistFrame and blacklistFrame ~= exceptFrame and blacklistFrame:IsShown() then blacklistFrame:Hide() end
    if pasteFrame and pasteFrame ~= exceptFrame and pasteFrame:IsShown() then pasteFrame:Hide() end
    if heuristicsFrame and heuristicsFrame ~= exceptFrame and heuristicsFrame:IsShown() then heuristicsFrame:Hide() end
end

function KAR.NavigateTo(windowName)
    if windowName == "main" then
        KAR.CloseAllWindows(guiFrame)
        if KAR.OpenGUI then KAR.OpenGUI() end
    elseif windowName == "heuristics" then
        KAR.CloseAllWindows(heuristicsFrame)
        if KAR.OpenHeuristicsGUI then KAR.OpenHeuristicsGUI() end
    elseif windowName == "blacklist" then
        KAR.CloseAllWindows(blacklistFrame)
        if KAR.OpenBlacklistGUI then KAR.OpenBlacklistGUI() end
    elseif windowName == "groups" then
        KAR.CloseAllWindows(recentGroupsFrame)
        if KAR.OpenRecentGroupsGUI then KAR.OpenRecentGroupsGUI() end
    elseif windowName == "paste" then
        KAR.CloseAllWindows(pasteFrame)
        if KAR.OpenPasteGUI then KAR.OpenPasteGUI() end
    end
end

-- Reusable Styled Button
function CreateStyledButton(parent, width, height, text, onClick, themeColor)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)

    local normalTex = btn:CreateTexture(nil, "BACKGROUND")
    normalTex:SetAllPoints()
    normalTex:SetTexture(TEXTURE_DIR .. "btn_gothic_normal.tga")
    btn.normalTex = normalTex

    local hoverTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hoverTex:SetAllPoints()
    hoverTex:SetTexture(TEXTURE_DIR .. "btn_gothic_hover.tga")
    btn.hoverTex = hoverTex

    local pushedTex = btn:CreateTexture(nil, "BACKGROUND")
    pushedTex:SetAllPoints()
    pushedTex:SetTexture(TEXTURE_DIR .. "btn_gothic_pushed.tga")
    pushedTex:Hide()
    btn.pushedTex = pushedTex

    btn:SetScript("OnMouseDown", function(self)
        if self.pushedTex then self.pushedTex:Show() end
        if self.normalTex then self.normalTex:Hide() end
    end)
    btn:SetScript("OnMouseUp", function(self)
        if self.pushedTex then self.pushedTex:Hide() end
        if self.normalTex then self.normalTex:Show() end
    end)

    if text and text ~= "" then
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
        fs:SetText(text)
        btn.fs = fs
    end

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

-- Reusable Bottom Dock Bar
local DOCK_DEFS = {
    { key = "main",       tex = "dock_btn_kar.tga",   target = "main" },
    { key = "heuristics", tex = "dock_btn_kh.tga",    target = "heuristics" },
    { key = "blacklist",  tex = "dock_btn_pb.tga",    target = "blacklist" },
    { key = "groups",     tex = "dock_btn_pg.tga",    target = "groups" },
    { key = "paste",      tex = "dock_btn_paste.tga", target = "paste" },
    { key = "close",      tex = "dock_btn_close.tga", target = "close" },
}

function KAR.AttachDockBar(parentFrame, activeWindowKey)
    local dock = CreateFrame("Frame", nil, parentFrame)
    dock:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", 10, 8)
    dock:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -10, 8)
    dock:SetHeight(38)

    local dockBg = dock:CreateTexture(nil, "BACKGROUND")
    dockBg:SetAllPoints()
    dockBg:SetTexture(TEXTURE_DIR .. "alucard_dock_bar.tga")

    local totalBtns = #DOCK_DEFS
    local spacing = 6
    local startX = 10
    local availableW = (parentFrame:GetWidth() or 740) - 40
    local btnWidth = math.floor((availableW - (totalBtns - 1) * spacing) / totalBtns)
    btnWidth = math.max(90, math.min(120, btnWidth))
    local btnHeight = 28

    for i, item in ipairs(DOCK_DEFS) do
        local btn = CreateFrame("Button", nil, dock)
        btn:SetSize(btnWidth, btnHeight)
        btn:SetPoint("LEFT", dock, "LEFT", startX + (i - 1) * (btnWidth + spacing), 0)

        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetTexture(TEXTURE_DIR .. item.tex)
        btn.tex = tex

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(TEXTURE_DIR .. "btn_gothic_hover.tga")
        hl:SetAlpha(0.6)

        btn:SetScript("OnClick", function()
            if item.target == "close" then
                parentFrame:Hide()
            else
                KAR.NavigateTo(item.target)
            end
        end)

        if item.key == activeWindowKey then
            local activeBorder = CreateFrame("Frame", nil, btn, "BackdropTemplate")
            activeBorder:SetAllPoints()
            activeBorder:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 2,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            activeBorder:SetBackdropBorderColor(1.0, 0.2, 0.3, 0.95)
        end
    end
end

-- Reusable Gothic Card Creator
local function CreateCard(parent, x, y, width, height, titleTexName, accentColor)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    card:SetSize(width, height)

    local cardBg = card:CreateTexture(nil, "BACKGROUND", nil, -5)
    cardBg:SetAllPoints()
    cardBg:SetTexture(TEXTURE_DIR .. "card_gothic_bg.tga")

    card:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local ac = accentColor or { 0.85, 0.15, 0.25, 0.85 }
    card:SetBackdropBorderColor(ac[1], ac[2], ac[3], ac[4] or 0.85)

    if titleTexName then
        local titleStrip = card:CreateTexture(nil, "ARTWORK")
        titleStrip:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -5)
        titleStrip:SetSize(width - 12, 22)
        titleStrip:SetTexture(TEXTURE_DIR .. titleTexName)
        card.titleStrip = titleStrip
    end

    return card
end

-- Reusable Gothic Checkbox
local function CreateStyledCheckbox(parent, x, y, labelText, onClick, initialChecked, isHighlight)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(18, 18)

    local isInitChecked = (initialChecked == true)

    local icon = cb:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(TEXTURE_DIR .. (isInitChecked and "chk_gothic_checked.tga" or "chk_gothic_unchecked.tga"))
    cb.icon = icon

    local hl = cb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(TEXTURE_DIR .. "btn_gothic_hover.tga")
    hl:SetAlpha(0.5)

    cb:SetChecked(isInitChecked)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 7, 0)
    text:SetText(labelText)
    if isHighlight then
        text:SetTextColor(0.2, 1.0, 0.4)
    else
        text:SetTextColor(0.9, 0.85, 0.85)
    end
    cb.text = text

    cb:SetScript("OnClick", function(self)
        local isChecked = (self:GetChecked() == true or self:GetChecked() == 1)
        self.icon:SetTexture(TEXTURE_DIR .. (isChecked and "chk_gothic_checked.tga" or "chk_gothic_unchecked.tga"))
        if onClick then
            -- Pass guaranteed boolean isChecked as FIRST argument!
            onClick(isChecked, self)
        end
    end)

    function cb:SetCheckedState(state)
        local bState = (state == true)
        self:SetChecked(bState)
        self.icon:SetTexture(TEXTURE_DIR .. (bState and "chk_gothic_checked.tga" or "chk_gothic_unchecked.tga"))
    end

    return cb
end

-- Reusable Gothic Slider
local function CreateStyledSlider(parent, x, y, width, label, minVal, maxVal, step, initialVal, onValChange, suffix)
    local valBadge = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    valBadge:SetPoint("TOPLEFT", parent, "TOPLEFT", x + width - 68, y)
    valBadge:SetSize(68, 18)
    valBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    valBadge:SetBackdropColor(0.06, 0.05, 0.08, 0.95)
    valBadge:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.7)

    local valText = valBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("CENTER", valBadge, "CENTER", 0, 0)
    valText:SetTextColor(1.0, 0.25, 0.35)

    local titleFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleFS:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    titleFS:SetText(label)
    titleFS:SetTextColor(0.85, 0.85, 0.9)

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 22)
    slider:SetSize(width, 16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local trackBg = slider:CreateTexture(nil, "BACKGROUND")
    trackBg:SetPoint("LEFT", slider, "LEFT", 0, 0)
    trackBg:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    trackBg:SetHeight(8)
    trackBg:SetTexture(TEXTURE_DIR .. "slider_track_gothic.tga")

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(16, 16)
    thumb:SetTexture(TEXTURE_DIR .. "slider_thumb_ruby.tga")
    slider:SetThumbTexture(thumb)

    local function FormatVal(v)
        if suffix == " RIO" then
            return string.format("%d RIO", v)
        elseif suffix == " ilvl" then
            return string.format("%d ilvl", v)
        elseif suffix == " ур." then
            return string.format("%d ур.", v)
        else
            return string.format("%d%s", v, suffix or "")
        end
    end

    valText:SetText(FormatVal(initialVal))
    slider:SetValue(initialVal)

    local minLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    minLabel:SetText(tostring(minVal))

    local maxLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maxLabel:SetText(tostring(maxVal))

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        valText:SetText(FormatVal(val))
        if onValChange then onValChange(val) end
    end)

    return slider
end

-- Reusable Gothic Number Stepper (- [N] +)
local function CreateStyledStepper(parent, x, y, labelText, minVal, maxVal, initialVal, onValChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetSize(210, 20)

    local curVal = initialVal or minVal or 0

    local titleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleFS:SetPoint("LEFT", frame, "LEFT", 0, 0)
    titleFS:SetText(labelText)
    titleFS:SetTextColor(0.9, 0.85, 0.85)
    frame.titleFS = titleFS

    local minusBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    minusBtn:SetPoint("LEFT", titleFS, "RIGHT", 6, 0)
    minusBtn:SetSize(18, 18)
    minusBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    minusBtn:SetBackdropColor(0.08, 0.05, 0.08, 0.95)
    minusBtn:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.8)
    local minusFS = minusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minusFS:SetPoint("CENTER", minusBtn, "CENTER", 0, 0)
    minusFS:SetText("-")
    minusFS:SetTextColor(1.0, 0.3, 0.4)

    local valBadge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    valBadge:SetPoint("LEFT", minusBtn, "RIGHT", 3, 0)
    valBadge:SetSize(24, 18)
    valBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    valBadge:SetBackdropColor(0.05, 0.04, 0.06, 0.95)
    valBadge:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.8)
    local valFS = valBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valFS:SetPoint("CENTER", valBadge, "CENTER", 0, 0)
    valFS:SetTextColor(1.0, 0.85, 0.3)

    local plusBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    plusBtn:SetPoint("LEFT", valBadge, "RIGHT", 3, 0)
    plusBtn:SetSize(18, 18)
    plusBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    plusBtn:SetBackdropColor(0.08, 0.05, 0.08, 0.95)
    plusBtn:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.8)
    local plusFS = plusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plusFS:SetPoint("CENTER", plusBtn, "CENTER", 0, 0)
    plusFS:SetText("+")
    plusFS:SetTextColor(0.2, 1.0, 0.4)

    local function UpdateDisplay()
        if curVal <= 0 then
            valFS:SetText("|cff8888880|r")
            valBadge:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.5)
            minusBtn:SetAlpha(0.4)
        else
            valFS:SetText(string.format("|cffffcc00%d|r", curVal))
            valBadge:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.9)
            minusBtn:SetAlpha(1.0)
        end
        if curVal >= maxVal then
            plusBtn:SetAlpha(0.4)
        else
            plusBtn:SetAlpha(1.0)
        end
    end

    minusBtn:SetScript("OnClick", function()
        if curVal > minVal then
            curVal = curVal - 1
            UpdateDisplay()
            if onValChange then onValChange(curVal) end
        end
    end)

    plusBtn:SetScript("OnClick", function()
        if curVal < maxVal then
            curVal = curVal + 1
            UpdateDisplay()
            if onValChange then onValChange(curVal) end
        end
    end)

    function frame:SetValue(newVal)
        curVal = math.max(minVal, math.min(maxVal, tonumber(newVal) or minVal))
        UpdateDisplay()
    end

    function frame:GetValue()
        return curVal
    end

    UpdateDisplay()
    return frame
end

local function CreateCheckbox(parent, x, y, label, onClick, initialChecked)
    return CreateStyledCheckbox(parent, x, y, label, onClick, initialChecked, false)
end

local function CreateSlider(parent, x, y, label, minVal, maxVal, step, initialVal, onValChange, suffix)
    return CreateStyledSlider(parent, x, y, 220, label, minVal, maxVal, step, initialVal, onValChange, suffix)
end

function KAR.OpenGUI()
    if guiFrame and guiFrame:IsShown() then
        guiFrame:Hide()
        return
    end
    if guiFrame then
        guiFrame:Show()
        return
    end

    local db = KeyAutoRecruitDB

    guiFrame = CreateFrame("Frame", "KeyAutoRecruitMainFrame", UIParent, "BackdropTemplate")
    guiFrame:SetSize(780, 690)
    guiFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 15)
    guiFrame:SetMovable(true)
    guiFrame:EnableMouse(true)
    guiFrame:RegisterForDrag("LeftButton")
    guiFrame:SetScript("OnDragStart", guiFrame.StartMoving)
    guiFrame:SetScript("OnDragStop", guiFrame.StopMovingOrSizing)
    guiFrame:SetClampedToScreen(true)
    guiFrame:SetFrameStrata("HIGH")

    local mainBgTex = guiFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
    mainBgTex:SetAllPoints()
    mainBgTex:SetTexture(TEXTURE_DIR .. "alucard_frame_bg.tga")

    local tintBg = guiFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
    tintBg:SetPoint("TOPLEFT", guiFrame, "TOPLEFT", 8, -8)
    tintBg:SetPoint("BOTTOMRIGHT", guiFrame, "BOTTOMRIGHT", -8, 8)
    tintBg:SetColorTexture(0.05, 0.04, 0.07, 0.82)

    guiFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    guiFrame:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.90)
    tinsert(UISpecialFrames, "KeyAutoRecruitMainFrame")

    -- Top Header Banner (PURE GRAPHICAL)
    local headerBar = CreateFrame("Frame", nil, guiFrame)
    headerBar:SetPoint("TOPLEFT", guiFrame, "TOPLEFT", 8, -8)
    headerBar:SetPoint("TOPRIGHT", guiFrame, "TOPRIGHT", -8, -8)
    headerBar:SetHeight(86)

    local bannerTex = headerBar:CreateTexture(nil, "ARTWORK")
    bannerTex:SetAllPoints()
    bannerTex:SetTexture(TEXTURE_DIR .. "header_main_kar.tga")

    local topCloseBtn = CreateStyledButton(headerBar, 26, 22, "|cffff5555✕|r", function()
        guiFrame:Hide()
    end, "red")
    topCloseBtn:SetPoint("TOPRIGHT", headerBar, "TOPRIGHT", -6, -6)

    -- Status HUD Card (Height 54, y = -98)
    local hudCard = CreateCard(guiFrame, 10, -98, 760, 54, nil, { 0.85, 0.15, 0.25, 0.85 })

    local statusBadge = CreateFrame("Frame", nil, hudCard, "BackdropTemplate")
    statusBadge:SetPoint("TOPLEFT", hudCard, "TOPLEFT", 10, -6)
    statusBadge:SetSize(125, 20)
    statusBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    statusBadge:SetBackdropColor(0.06, 0.14, 0.08, 0.95)
    statusBadge:SetBackdropBorderColor(0.1, 0.90, 0.35, 0.85)

    local statusBadgeText = statusBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusBadgeText:SetPoint("CENTER", statusBadge, "CENTER", 0, 0)
    statusBadgeText:SetText("|cff00ff00✔ АКТИВЕН|r")

    local scanBadge = CreateFrame("Frame", nil, hudCard, "BackdropTemplate")
    scanBadge:SetPoint("LEFT", statusBadge, "RIGHT", 6, 0)
    scanBadge:SetSize(135, 20)
    scanBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    scanBadge:SetBackdropColor(0.06, 0.10, 0.16, 0.95)
    scanBadge:SetBackdropBorderColor(0.0, 0.70, 0.90, 0.7)

    local scanBadgeText = scanBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scanBadgeText:SetPoint("CENTER", scanBadge, "CENTER", 0, 0)
    scanBadgeText:SetText("|cff00ffcc🔍 Поиск в LFG|r")

    local partyBadge = CreateFrame("Frame", nil, hudCard, "BackdropTemplate")
    partyBadge:SetPoint("LEFT", scanBadge, "RIGHT", 6, 0)
    partyBadge:SetSize(130, 20)
    partyBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    partyBadge:SetBackdropColor(0.12, 0.08, 0.14, 0.95)
    partyBadge:SetBackdropBorderColor(0.75, 0.35, 0.85, 0.7)

    local partyBadgeText = partyBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    partyBadgeText:SetPoint("CENTER", partyBadge, "CENTER", 0, 0)
    partyBadgeText:SetText("|cffffffff👥 Группа: 1/5|r")

    local queueBadge = CreateFrame("Frame", nil, hudCard, "BackdropTemplate")
    queueBadge:SetPoint("LEFT", partyBadge, "RIGHT", 6, 0)
    queueBadge:SetSize(135, 20)
    queueBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    queueBadge:SetBackdropColor(0.14, 0.08, 0.08, 0.95)
    queueBadge:SetBackdropBorderColor(0.95, 0.30, 0.30, 0.75)

    local queueBadgeText = queueBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    queueBadgeText:SetPoint("CENTER", queueBadge, "CENTER", 0, 0)
    queueBadgeText:SetText("|cffffcc00⏳ Очередь: 0|r")

    local inviteBadge = CreateFrame("Frame", nil, hudCard, "BackdropTemplate")
    inviteBadge:SetPoint("LEFT", queueBadge, "RIGHT", 6, 0)
    inviteBadge:SetSize(155, 20)
    inviteBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    inviteBadge:SetBackdropColor(0.07, 0.13, 0.10, 0.95)
    inviteBadge:SetBackdropBorderColor(0.10, 0.85, 0.45, 0.7)

    local inviteBadgeText = inviteBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inviteBadgeText:SetPoint("CENTER", inviteBadge, "CENTER", 0, 0)
    inviteBadgeText:SetText("|cff00ff7f✉ Инвайтов: 0|r")

    local rolesSummaryText = hudCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rolesSummaryText:SetPoint("BOTTOMLEFT", hudCard, "BOTTOMLEFT", 12, 6)
    rolesSummaryText:SetText("|cff3399ff🛡 Танк: 0/1|r    |cff00ff7f🍷 Хил: 0/1|r    |cffff9900⚔ ДД: 1/3|r    |cff00ccff⚡ Bloodlust: 0/1|r    |cffff3333🩸 BattleRes: 0/1|r")

    -- -------------------------------------------------------------
    -- MASTER TAB SWITCHER (Graphical Buttons)
    -- -------------------------------------------------------------
    local tab1Btn = CreateFrame("Button", nil, guiFrame)
    tab1Btn:SetSize(250, 34)
    tab1Btn:SetPoint("TOPLEFT", guiFrame, "TOPLEFT", 12, -156)
    local tab1Tex = tab1Btn:CreateTexture(nil, "BACKGROUND")
    tab1Tex:SetAllPoints()
    tab1Tex:SetTexture(TEXTURE_DIR .. "tab_btn_dashboard_active.tga")

    local tab2Btn = CreateFrame("Button", nil, guiFrame)
    tab2Btn:SetSize(250, 34)
    tab2Btn:SetPoint("LEFT", tab1Btn, "RIGHT", 8, 0)
    local tab2Tex = tab2Btn:CreateTexture(nil, "BACKGROUND")
    tab2Tex:SetAllPoints()
    tab2Tex:SetTexture(TEXTURE_DIR .. "tab_btn_specs_inactive.tga")

    local allBtn = CreateFrame("Button", nil, guiFrame)
    allBtn:SetSize(110, 30)
    allBtn:SetPoint("TOPRIGHT", guiFrame, "TOPRIGHT", -122, -158)
    local allTex = allBtn:CreateTexture(nil, "BACKGROUND")
    allTex:SetAllPoints()
    allTex:SetTexture(TEXTURE_DIR .. "btn_spec_all.tga")
    allBtn:SetScript("OnClick", function()
        for sId, _ in pairs(KAR.SPECIALIZATIONS) do
            db.specs[sId] = true
        end
        guiFrame:Hide()
        KAR.OpenGUI()
    end)

    local noneBtn = CreateFrame("Button", nil, guiFrame)
    noneBtn:SetSize(100, 30)
    noneBtn:SetPoint("LEFT", allBtn, "RIGHT", 6, 0)
    local noneTex = noneBtn:CreateTexture(nil, "BACKGROUND")
    noneTex:SetAllPoints()
    noneTex:SetTexture(TEXTURE_DIR .. "btn_spec_none.tga")
    noneBtn:SetScript("OnClick", function()
        for sId, _ in pairs(KAR.SPECIALIZATIONS) do
            db.specs[sId] = false
        end
        guiFrame:Hide()
        KAR.OpenGUI()
    end)

    local tab1Container = CreateFrame("Frame", nil, guiFrame)
    tab1Container:SetPoint("TOPLEFT", guiFrame, "TOPLEFT", 10, -194)
    tab1Container:SetPoint("BOTTOMRIGHT", guiFrame, "BOTTOMRIGHT", -10, 48)

    local tab2Container = CreateFrame("Frame", nil, guiFrame)
    tab2Container:SetPoint("TOPLEFT", guiFrame, "TOPLEFT", 10, -194)
    tab2Container:SetPoint("BOTTOMRIGHT", guiFrame, "BOTTOMRIGHT", -10, 48)
    tab2Container:Hide()

    local function SwitchToTab(tabNum)
        if tabNum == 1 then
            tab1Container:Show()
            tab2Container:Hide()
            allBtn:Hide()
            noneBtn:Hide()
            tab1Tex:SetTexture(TEXTURE_DIR .. "tab_btn_dashboard_active.tga")
            tab2Tex:SetTexture(TEXTURE_DIR .. "tab_btn_specs_inactive.tga")
        else
            tab1Container:Hide()
            tab2Container:Show()
            allBtn:Show()
            noneBtn:Show()
            tab1Tex:SetTexture(TEXTURE_DIR .. "tab_btn_dashboard_inactive.tga")
            tab2Tex:SetTexture(TEXTURE_DIR .. "tab_btn_specs_active.tga")
            if tab2Container.scrollFrame then
                tab2Container.scrollFrame:SetVerticalScroll(0)
            end
        end
    end

    tab1Btn:SetScript("OnClick", function() SwitchToTab(1) end)
    tab2Btn:SetScript("OnClick", function() SwitchToTab(2) end)
    SwitchToTab(1)

    -- TAB 1 CONTENT
    local rulesCard = CreateCard(tab1Container, 0, 0, 760, 84, "card_title_rules.tga", { 0.85, 0.15, 0.25, 0.85 })

    local masterCb = CreateStyledCheckbox(rulesCard, 14, -30, "|cff00ff00Включить авто-набор (Master Switch)|r", function(checked)
        if checked then
            KAR.StartRecruiting()
        else
            KAR.StopRecruiting()
        end
    end, (db.active or db.enabled), true)

    local announceCb = CreateStyledCheckbox(rulesCard, 330, -30, "Авто-объявления в чат группы (/p)", function(checked)
        local val = (checked == true)
        db.options.announceToChat = val
    end, (db.options.announceToChat == true))

    local declineCb = CreateStyledCheckbox(rulesCard, 595, -30, "Авто-отказ в ЛФГ", function(checked)
        local val = (checked == true)
        db.options.whisperDeclined = val
        db.autoDecline = val
    end, (db.options.whisperDeclined == true))

    local lustCb = CreateStyledCheckbox(rulesCard, 14, -56, "Требовать БЛ (Heroism)", function(checked)
        local val = (checked == true)
        db.options.requireLust = val
        db.minLust = val and 1 or 0
    end, (db.options.requireLust == true))

    local brezStepper = CreateStyledStepper(rulesCard, 245, -56, "|cffff3333🩸 Мин. БР:|r", 0, 3, db.minBrez or 1, function(val)
        db.minBrez = val
        db.options.requireBrez = (val > 0)
    end)

    local dpsBrezStepper = CreateStyledStepper(rulesCard, 455, -56, "|cffff9900⚔ БР среди ДД:|r", 0, 3, db.minDpsBrez or 1, function(val)
        db.minDpsBrez = val
        db.options.requireDpsBrez = (val > 0)
    end)

    local brezHintFS = rulesCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    brezHintFS:SetPoint("LEFT", dpsBrezStepper, "RIGHT", -10, 0)
    brezHintFS:SetText("|cff888888(ДК/Дру/Лок/Пал)|r")

    local threshCard = CreateCard(tab1Container, 0, -88, 760, 80, "card_title_thresholds.tga", { 0.85, 0.15, 0.25, 0.85 })

    local rioSlider = CreateStyledSlider(threshCard, 14, -30, 235, "Мин. общий RIO", 0, 4000, 50, db.thresholds.minOverallScore or 0, function(val)
        db.thresholds.minOverallScore = val
        db.minRio = val
    end, " RIO")

    local dScoreSlider = CreateStyledSlider(threshCard, 260, -30, 235, "Мин. счет в этом ключе", 0, 400, 10, db.thresholds.minDungeonScore or 0, function(val)
        db.thresholds.minDungeonScore = val
    end, " оч.")

    local ilvlSlider = CreateStyledSlider(threshCard, 506, -30, 235, "Мин. средний ilvl", 200, 730, 5, db.thresholds.minItemLevel or 200, function(val)
        db.thresholds.minItemLevel = val
        db.minIlvl = val
    end, " ilvl")

    local heurCard = CreateCard(tab1Container, 0, -172, 760, 142, "card_title_heuristics.tga", { 0.85, 0.15, 0.25, 0.85 })

    local targetDungeonIcon = heurCard:CreateTexture(nil, "ARTWORK")
    targetDungeonIcon:SetSize(22, 22)
    targetDungeonIcon:SetPoint("TOPLEFT", heurCard, "TOPLEFT", 14, -30)
    targetDungeonIcon:SetTexture(TEXTURE_DIR .. "icon_cromwell_seal.tga")

    local targetDungeonLabel = heurCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    targetDungeonLabel:SetPoint("LEFT", targetDungeonIcon, "RIGHT", 8, 0)
    targetDungeonLabel:SetText("|cffffcc00Целевой ключ:|r |cffffffffОпределение...|r")

    local khBtn = CreateStyledButton(heurCard, 210, 22, "⚔ Подробная эвристика (/kh)", function()
        KAR.NavigateTo("heuristics")
    end)
    khBtn:SetPoint("TOPRIGHT", heurCard, "TOPRIGHT", -12, -30)

    local function UpdateDeficitDisplay(val)
        local tInfo = (KAR.GetTargetDungeonInfo and KAR.GetTargetDungeonInfo()) or { name = "Не выставлен", targetLevel = 0 }
        local tLvl = tInfo and tInfo.targetLevel or 0
        local tName = tInfo and tInfo.name or "Неизвестно"

        if (db.dungeonKeyCheckEnabled ~= true) then
            if targetDungeonLabel then
                targetDungeonLabel:SetText(string.format("|cffffcc00Ключ:|r |cffffffff%s%s|r |cff888888(фильтр закрытого ключа ОТКЛЮЧЕН)|r", tName, (tLvl > 0 and (" +" .. tLvl) or "")))
            end
            if deficitVerdictText then
                deficitVerdictText:SetText("|cffaaaaaaФильтр закрытого ключа отключен в настройках|r\n|cff00ff66(кандидаты принимаются независимо от закрытого ключа)|r")
            end
            if deficitVerdictBox then
                deficitVerdictBox:SetBackdropBorderColor(0.40, 0.40, 0.45, 0.6)
            end
        elseif tLvl > 0 then
            if targetDungeonLabel then
                targetDungeonLabel:SetText(string.format("|cffffcc00Ключ:|r |cffffffff%s +%d|r |cff8899aa(Лидер группы)|r", tName, tLvl))
            end
            local minLvl = math.max(0, tLvl - val)
            if deficitVerdictText then
                deficitVerdictText:SetText(string.format("|cff00ff00Мин. требуемый ключ: +%d|r  |cffaaaaaa(отставание не более %d уровней)|r\n|cffff6666Авто-отказ кандидатам с лучшим ключом < +%d|r", minLvl, val, minLvl))
            end
            if deficitVerdictBox then
                deficitVerdictBox:SetBackdropBorderColor(0.85, 0.20, 0.25, 0.85)
            end
        else
            if targetDungeonLabel then
                targetDungeonLabel:SetText(string.format("|cffffcc00Ключ:|r |cffffffff%s|r |cff888888(группа не выставлена в поиск)|r", tName))
            end
            if deficitVerdictText then
                deficitVerdictText:SetText(string.format("|cffffcc00Целевой ключ не определен в LFG|r\n|cffaaaaaa(выставите ключ в поиск, чтобы активировать расчет порога)|r"))
            end
            if deficitVerdictBox then
                deficitVerdictBox:SetBackdropBorderColor(0.85, 0.20, 0.25, 0.85)
            end
        end
    end

    local dungeonCheckCb = CreateStyledCheckbox(heurCard, 14, -58, "Включить фильтр опыта по закрытому ключу", function(checked)
        local val = (checked == true)
        db.dungeonKeyCheckEnabled = val
        if db.options then db.options.dungeonKeyCheck = val end
        UpdateDeficitDisplay(tonumber(db.maxDungeonKeyDeficit) or 2)
    end, (db.dungeonKeyCheckEnabled == true))

    local timedCheckCb = CreateStyledCheckbox(heurCard, 400, -58, "Требовать закрытие в тайм (In-Time)", function(checked)
        local val = (checked == true)
        db.requireDungeonTimed = val
        if db.options then db.options.requireDungeonTimed = val end
    end, (db.requireDungeonTimed == true))

    local deficitVerdictBox = CreateFrame("Frame", nil, heurCard, "BackdropTemplate")
    deficitVerdictBox:SetPoint("TOPLEFT", heurCard, "TOPLEFT", 300, -84)
    deficitVerdictBox:SetSize(445, 46)
    deficitVerdictBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    deficitVerdictBox:SetBackdropColor(0.08, 0.05, 0.08, 0.95)
    deficitVerdictBox:SetBackdropBorderColor(0.85, 0.20, 0.25, 0.85)

    local deficitVerdictText = deficitVerdictBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    deficitVerdictText:SetPoint("CENTER", deficitVerdictBox, "CENTER", 0, 0)
    deficitVerdictText:SetJustifyH("CENTER")
    deficitVerdictText:SetText("|cff00ff00Мин. требуемый ключ: +11|r\n|cffaaaaaa(игроки с закрытым ключом ниже будут отклонены)|r")

    -- UpdateDeficitDisplay declared above

    local curDeficit = tonumber(db.maxDungeonKeyDeficit) or 2
    local deficitSlider = CreateStyledSlider(heurCard, 14, -86, 275, "Макс. отставание по ключу", 0, 10, 1, curDeficit, function(val)
        db.maxDungeonKeyDeficit = val
        if db.thresholds then db.thresholds.maxKeyDeficit = val end
        UpdateDeficitDisplay(val)
    end, " ур.")
    UpdateDeficitDisplay(curDeficit)

    local wagonCard = CreateCard(tab1Container, 0, -322, 760, 78, "card_title_wagon.tga", { 0.85, 0.15, 0.25, 0.85 })

    local wagonCb = CreateStyledCheckbox(wagonCard, 14, -30, "Разрешить одного вагона (Allow One Wagon)", function(checked)
        local val = (checked == true)
        db.allowOneVagon = val
    end, (db.allowOneVagon == true))

    local wagonDiffSlider = CreateStyledSlider(wagonCard, 360, -30, 185, "Макс. отставание вагона", 5, 50, 5, db.vagonMaxIlvlDiff or 35, function(val)
        db.vagonMaxIlvlDiff = val
    end, " ilvl")

    local protectedRioSlider = CreateStyledSlider(wagonCard, 560, -30, 185, "Защищенный RIO", 1500, 3500, 50, db.protectedRio or 2500, function(val)
        db.protectedRio = val
    end, " RIO")

    -- TAB 2 CONTENT: HARDCORE 39 SPECS MATRIX
    local specsScrollFrame = CreateFrame("ScrollFrame", "KAR_SpecsScrollFrame", tab2Container, "UIPanelScrollFrameTemplate")
    specsScrollFrame:SetPoint("TOPLEFT", tab2Container, "TOPLEFT", 0, 0)
    specsScrollFrame:SetPoint("BOTTOMRIGHT", tab2Container, "BOTTOMRIGHT", -24, 0)
    specsScrollFrame:EnableMouseWheel(true)
    specsScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = 660
        local newScroll = math.max(0, math.min(maxScroll, cur - delta * 36))
        self:SetVerticalScroll(newScroll)
    end)
    tab2Container.scrollFrame = specsScrollFrame

    local specsContent = CreateFrame("Frame", nil, specsScrollFrame)
    specsContent:SetSize(720, 1150)
    specsScrollFrame:SetScrollChild(specsContent)

    local currentY = -4
    local classList = KAR.ORDERED_CLASSES or {
        "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
        "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
        "DRUID", "DEMONHUNTER", "EVOKER"
    }
    local classSpecsTable = KAR.CLASS_SPECS or KAR.CLASSES or {}

    for rowIndex, classToken in ipairs(classList) do
        local specIDs = classSpecsTable[classToken]
        if specIDs then
            local rowHeight = 46
            local classRow = CreateFrame("Frame", nil, specsContent, "BackdropTemplate")
            classRow:SetPoint("TOPLEFT", specsContent, "TOPLEFT", 4, currentY)
            classRow:SetSize(710, rowHeight)

            local barTex = classRow:CreateTexture(nil, "BACKGROUND")
            barTex:SetAllPoints()
            local barPath = CLASS_BARS_GOTHIC[classToken]
            if barPath then
                barTex:SetTexture(barPath)
            else
                barTex:SetColorTexture(0.08, 0.08, 0.12, 0.85)
            end

            local cIcon = classRow:CreateTexture(nil, "ARTWORK")
            cIcon:SetSize(34, 34)
            cIcon:SetPoint("LEFT", classRow, "LEFT", 10, 0)
            local crestPath = CLASS_ICONS_GOTHIC[classToken]
            if crestPath then
                cIcon:SetTexture(crestPath)
            else
                cIcon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
            end

            local classLabel = CLASS_LOCALIZED[classToken] or classToken
            local hex = (KAR.CLASS_COLORS and KAR.CLASS_COLORS[classToken]) or "FFFFFF"
            local classHeader = classRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            classHeader:SetPoint("LEFT", cIcon, "RIGHT", 10, 0)
            classHeader:SetText(string.format("|cff%s%s|r", hex, classLabel))

            local sepLine = classRow:CreateTexture(nil, "OVERLAY")
            sepLine:SetPoint("LEFT", classRow, "LEFT", 215, 0)
            sepLine:SetSize(1, 36)
            sepLine:SetColorTexture(0.85, 0.15, 0.25, 0.75)

            local numSpecs = #specIDs
            local colWidth = 160
            if numSpecs == 4 then colWidth = 122
            elseif numSpecs == 2 then colWidth = 235 end

            for col, sId in ipairs(specIDs) do
                local sInfo = KAR.SPECIALIZATIONS and KAR.SPECIALIZATIONS[sId]
                if sInfo then
                    local x = 224 + (col - 1) * colWidth
                    local rCrest = ROLE_ICONS_GOTHIC[sInfo.role] or ROLE_ICONS_GOTHIC["DPS"]

                    local utilTag = ""
                    if sInfo.lust then utilTag = utilTag .. " |cff00ccff(БЛ)|r" end
                    if sInfo.brez then utilTag = utilTag .. " |cffff3333(БР)|r" end

                    local specBox = CreateFrame("Frame", nil, classRow)
                    specBox:SetPoint("LEFT", classRow, "LEFT", x, 0)
                    specBox:SetSize(colWidth - 6, 36)

                    local roleIconTex = specBox:CreateTexture(nil, "ARTWORK")
                    roleIconTex:SetSize(18, 18)
                    roleIconTex:SetPoint("LEFT", specBox, "LEFT", 0, 0)
                    roleIconTex:SetTexture(rCrest)

                    local specCb = CreateStyledCheckbox(specBox, 22, -8, string.format("%s%s", sInfo.name, utilTag), function(checked)
                        db.specs[sId] = checked
                    end, db.specs[sId])
                end
            end
            currentY = currentY - (rowHeight + 4)
        end
    end

    KAR.AttachDockBar(guiFrame, "main")

    local function UpdateLiveStatus()
        if not guiFrame or not guiFrame:IsShown() then return end
        local st = (KAR.GetGroupStatus and KAR.GetGroupStatus()) or { total = 0, tanks = 0, healers = 0, dps = 0 }
        local isAct = (db.active or db.enabled)

        if isAct then
            statusBadgeText:SetText("|cff00ff00✔ АКТИВЕН|r")
            statusBadge:SetBackdropColor(0.06, 0.16, 0.08, 0.95)
            statusBadge:SetBackdropBorderColor(0.1, 0.90, 0.35, 0.9)
        else
            statusBadgeText:SetText("|cffff3333✖ ОСТАНОВЛЕН|r")
            statusBadge:SetBackdropColor(0.18, 0.07, 0.08, 0.95)
            statusBadge:SetBackdropBorderColor(0.90, 0.20, 0.25, 0.8)
        end

        if KAR.IsScanning then
            scanBadgeText:SetText("|cff00ffcc🔍 Поиск в LFG|r")
            scanBadge:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.9)
        else
            scanBadgeText:SetText("|cff8899aa💤 Ожидание|r")
            scanBadge:SetBackdropBorderColor(0.30, 0.35, 0.45, 0.6)
        end

        partyBadgeText:SetText(string.format("|cffffffff👥 Группа: %d/5|r", st.total or 0))

        local queueLen = (KAR.SecureQueue and #KAR.SecureQueue) or (KAR.GetQueueLength and KAR.GetQueueLength()) or 0
        queueBadgeText:SetText(string.format("|cffffcc00⏳ Очередь: %d|r", queueLen))

        local totalInvited = (db.stats and db.stats.totalInvited) or 0
        inviteBadgeText:SetText(string.format("|cff00ff7f✉ Инвайтов: %d|r", totalInvited))

        rolesSummaryText:SetText(string.format(
            "|cff3399ff🛡 Танк: %d/1|r   |cff00ff7f🍾 Хил: %d/1|r   |cffff9900⚔ ДД: %d/3|r   |cff00ccff⚡ BL: %d/%d|r   |cffff3333🩸 BR: %d/%d (ДД: %d/%d)|r",
            st.tanks or 0, st.healers or 0, st.dps or 0,
            st.lust or 0, (db.minLust or 1),
            st.brez or 0, (db.minBrez or 1),
            st.dpsBrez or 0, (db.minDpsBrez or 0)
        ))

        if UpdateDeficitDisplay and db and db.maxDungeonKeyDeficit then
            UpdateDeficitDisplay(db.maxDungeonKeyDeficit)
        end
    end

    C_Timer.NewTicker(1.0, UpdateLiveStatus)

    guiFrame:Show()
    UpdateLiveStatus()
end

function KAR.RefreshRecentGroupsList()
    if not recentGroupWidgets then recentGroupWidgets = {} end
    if not recentGroupsFrame or not recentGroupsFrame:IsShown() then return end

    -- Очистить предыдущие элементы
    for _, w in ipairs(recentGroupWidgets) do
        w:Hide()
    end
    wipe(recentGroupWidgets)

    local db = KeyAutoRecruitDB
    local groups = db and db.recentGroups or {}
    local scrollChild = recentGroupsFrame.scrollChild
    local startY = -10

    if #groups == 0 then
        if not recentGroupsFrame.emptyLabel then
            recentGroupsFrame.emptyLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            recentGroupsFrame.emptyLabel:SetPoint("TOP", scrollChild, "TOP", 0, -80)
            recentGroupsFrame.emptyLabel:SetText("|cffaaaaaaИстория групп пуста.\n\nКогда вы вступите в группу или начнете сбор,\nздесь появится список последних 5 групп!|r")
            recentGroupsFrame.emptyLabel:SetJustifyH("CENTER")
        end
        recentGroupsFrame.emptyLabel:Show()
        scrollChild:SetHeight(200)
        return
    else
        if recentGroupsFrame.emptyLabel then
            recentGroupsFrame.emptyLabel:Hide()
        end
    end

    local currentY = startY

    for gIdx, group in ipairs(groups) do
        if gIdx > 5 then break end

        -- Заголовок группы
        local headerFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        headerFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, currentY)
        headerFrame:SetSize(685, 26)
        headerFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if group.active then
            headerFrame:SetBackdropColor(0.08, 0.22, 0.14, 0.95)
            headerFrame:SetBackdropBorderColor(0.0, 0.9, 0.4, 0.9)
        else
            headerFrame:SetBackdropColor(0.12, 0.14, 0.20, 0.95)
            headerFrame:SetBackdropBorderColor(0.2, 0.35, 0.55, 0.8)
        end

        local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        headerText:SetPoint("LEFT", headerFrame, "LEFT", 10, 0)
        local activeTag = group.active and " |cff00ff00[АКТИВНАЯ]|r" or ""
        local dungName = group.dungeon or "Неизвестное подземелье"
        local gDate = group.date or ""
        local numM = group.members and #group.members or 0
        headerText:SetText(string.format("Группа #%d: |cffffff00%s|r (%s) — %d чел.%s", gIdx, dungName, gDate, numM, activeTag))

        table.insert(recentGroupWidgets, headerFrame)
        currentY = currentY - 28

        -- Строки участников группы
        local members = group.members or {}
        for mIdx, member in ipairs(members) do
            local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, currentY)
            row:SetSize(685, 26)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            if mIdx % 2 == 0 then
                row:SetBackdropColor(0.08, 0.09, 0.12, 0.7)
            else
                row:SetBackdropColor(0.05, 0.06, 0.08, 0.7)
            end
            row:SetBackdropBorderColor(0.18, 0.20, 0.25, 0.5)

            -- Роль
            local roleTag = "|cffff9900[ДД]|r"
            if member.role == "TANK" then roleTag = "|cff3399ff[ТАНК]|r"
            elseif member.role == "HEALER" then roleTag = "|cff00ff7f[ХИЛ]|r" end

            local roleFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            roleFS:SetPoint("LEFT", row, "LEFT", 8, 0)
            roleFS:SetText(roleTag)

            -- Имя в цвете класса
            local classCol = KAR.CLASS_COLORS[member.class] or "FFFFFF"
            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameFS:SetPoint("LEFT", row, "LEFT", 68, 0)
            nameFS:SetText(string.format("|cff%s%s|r", classCol, member.name or "Неизвестный"))

            -- Спек, ilvl, RIO
            local specStr = (member.spec and member.spec ~= "") and member.spec or "Без спека"
            local gearFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            gearFS:SetPoint("LEFT", row, "LEFT", 220, 0)
            gearFS:SetText(string.format("|cffcccccc%s|r | %d ilvl | |cffffcc00%d RIO|r", specStr, member.ilvl or 0, member.rio or 0))

            -- Статус и кнопка ЧС
            if member.isPlayer then
                local selfFS = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                selfFS:SetPoint("RIGHT", row, "RIGHT", -15, 0)
                selfFS:SetText("|cff00ff00(Вы)|r")
            else
                local cleanName = member.cleanName or string.match(member.name or "", "([^-]+)") or member.name
                local isBL, blData = KAR.IsBlacklisted(cleanName)

                if isBL then
                    local reasonText = (blData and blData.reason) or "ЧС"
                    if #reasonText > 22 then reasonText = reasonText:sub(1, 20) .. ".." end

                    local blLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    blLabel:SetPoint("RIGHT", row, "RIGHT", -105, 0)
                    blLabel:SetText(string.format("|cffff3333[В ЧС: %s]|r", reasonText))

                    local unblockBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    unblockBtn:SetSize(95, 20)
                    unblockBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    unblockBtn:SetText("|cff00ff00Убрать|r")
                    unblockBtn:SetScript("OnClick", function()
                        KAR.RemoveFromBlacklist(member.name)
                        KAR.RefreshRecentGroupsList()
                    end)
                else
                    local blockBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    blockBtn:SetSize(95, 20)
                    blockBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    blockBtn:SetText("|cffff2020[В ЧС]|r")
                    blockBtn:SetScript("OnClick", function()
                        StaticPopup_Show("KAR_BLACKLIST_REASON_PROMPT", member.name, nil, { name = member.name })
                    end)
                end
            end

            table.insert(recentGroupWidgets, row)
            currentY = currentY - 28
        end

        currentY = currentY - 12
    end

    local totalHeight = math.abs(currentY) + 30
    scrollChild:SetHeight(math.max(totalHeight, 460))
end



function KAR.OpenRecentGroupsGUI()
    if recentGroupsFrame and recentGroupsFrame:IsShown() then
        recentGroupsFrame:Hide()
        return
    end

    if not recentGroupsFrame then
        recentGroupsFrame = CreateFrame("Frame", "KAR_RecentGroupsFrame", UIParent, "BackdropTemplate")
        recentGroupsFrame:SetSize(780, 620)
        recentGroupsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        recentGroupsFrame:SetMovable(true)
        recentGroupsFrame:EnableMouse(true)
        recentGroupsFrame:RegisterForDrag("LeftButton")
        recentGroupsFrame:SetScript("OnDragStart", recentGroupsFrame.StartMoving)
        recentGroupsFrame:SetScript("OnDragStop", recentGroupsFrame.StopMovingOrSizing)
        recentGroupsFrame:SetClampedToScreen(true)
        recentGroupsFrame:SetFrameStrata("HIGH")

        recentGroupsFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        recentGroupsFrame:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.90)
        tinsert(UISpecialFrames, "KAR_RecentGroupsFrame")

        local rBg = recentGroupsFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
        rBg:SetAllPoints()
        rBg:SetTexture(TEXTURE_DIR .. "alucard_frame_bg.tga")

        local rTint = recentGroupsFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
        rTint:SetPoint("TOPLEFT", recentGroupsFrame, "TOPLEFT", 8, -8)
        rTint:SetPoint("BOTTOMRIGHT", recentGroupsFrame, "BOTTOMRIGHT", -8, 8)
        rTint:SetColorTexture(0.05, 0.04, 0.07, 0.82)

        local rHdr = CreateFrame("Frame", nil, recentGroupsFrame)
        rHdr:SetPoint("TOPLEFT", recentGroupsFrame, "TOPLEFT", 8, -8)
        rHdr:SetPoint("TOPRIGHT", recentGroupsFrame, "TOPRIGHT", -8, -8)
        rHdr:SetHeight(86)
        local rHdrTex = rHdr:CreateTexture(nil, "ARTWORK")
        rHdrTex:SetAllPoints()
        rHdrTex:SetTexture(TEXTURE_DIR .. "header_recent_groups.tga")

        local closeXBtn = CreateStyledButton(rHdr, 26, 22, "|cffff5555✕|r", function() recentGroupsFrame:Hide() end, "red")
        closeXBtn:SetPoint("TOPRIGHT", rHdr, "TOPRIGHT", -6, -6)

        -- Top action bar
        local subFS = recentGroupsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subFS:SetPoint("TOPLEFT", recentGroupsFrame, "TOPLEFT", 18, -98)
        subFS:SetText("Список последних 5 собранных групп. Нажмите |cffff2020[В ЧС]|r напротив игрока для быстрого занесения.")

        local refreshBtn = CreateStyledButton(recentGroupsFrame, 120, 24, "Обновить", function()
            if KAR.CaptureCurrentGroupSnapshot then KAR.CaptureCurrentGroupSnapshot() end
            KAR.RefreshRecentGroupsList()
        end)
        refreshBtn:SetPoint("TOPRIGHT", recentGroupsFrame, "TOPRIGHT", -160, -96)

        local clearBtn = CreateStyledButton(recentGroupsFrame, 140, 24, "Очистить историю", function()
            if KeyAutoRecruitDB then KeyAutoRecruitDB.recentGroups = {} end
            KAR.RefreshRecentGroupsList()
            KAR.Log("История последних групп очищена.")
        end)
        clearBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)

        local scrollFrame = CreateFrame("ScrollFrame", "KAR_RecentGroupsScrollFrame", recentGroupsFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", recentGroupsFrame, "TOPLEFT", 14, -132)
        scrollFrame:SetPoint("BOTTOMRIGHT", recentGroupsFrame, "BOTTOMRIGHT", -32, 52)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(720, 460)
        scrollFrame:SetScrollChild(scrollChild)
        recentGroupsFrame.scrollChild = scrollChild

        KAR.AttachDockBar(recentGroupsFrame, "groups")
    end

    if KAR.CaptureCurrentGroupSnapshot then KAR.CaptureCurrentGroupSnapshot() end
    recentGroupsFrame:Show()
    KAR.RefreshRecentGroupsList()
end

function KAR.RefreshBlacklistList()
    if not blacklistWidgets then blacklistWidgets = {} end
    if not blacklistFrame or not blacklistFrame:IsShown() then return end

    for _, w in ipairs(blacklistWidgets) do
        w:Hide()
    end
    wipe(blacklistWidgets)

    local db = KeyAutoRecruitDB
    local bl = db and db.blacklist or {}
    local scrollChild = blacklistFrame.scrollChild
    local startY = -10

    -- Фильтрация по поисковому запросу
    local filteredKeys = {}
    local query = (blacklistSearchQuery or ""):lower():gsub("^%s*(.-)%s*$", "%1")

    for k, data in pairs(bl) do
        local match = true
        if query ~= "" then
            local nameMatch = string.find(k:lower(), query, 1, true)
            local reasonMatch = data.reason and string.find(data.reason:lower(), query, 1, true)
            if not nameMatch and not reasonMatch then
                match = false
            end
        end
        if match then
            table.insert(filteredKeys, k)
        end
    end
    table.sort(filteredKeys)

    blacklistFrame.countLabel:SetText(string.format("Всего в ЧС: |cffffff00%d|r игроков", #filteredKeys))

    if #filteredKeys == 0 then
        if not blacklistFrame.emptyLabel then
            blacklistFrame.emptyLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            blacklistFrame.emptyLabel:SetPoint("TOP", scrollChild, "TOP", 0, -80)
            blacklistFrame.emptyLabel:SetJustifyH("CENTER")
        end
        if query ~= "" then
            blacklistFrame.emptyLabel:SetText(string.format("|cffaaaaaaНичего не найдено по запросу \"%s\".|r", query))
        else
            blacklistFrame.emptyLabel:SetText("|cff00ff00Черный список пуст!|r\n\nИгроки добавляются через историю групп (/pg)\nили по кнопке \"+ Добавить в ЧС\" вверху.")
        end
        blacklistFrame.emptyLabel:Show()
        scrollChild:SetHeight(200)
        return
    else
        if blacklistFrame.emptyLabel then
            blacklistFrame.emptyLabel:Hide()
        end
    end

    local currentY = startY

    -- Заголовок таблицы
    local headerRow = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    headerRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, currentY)
    headerRow:SetSize(685, 24)
    headerRow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerRow:SetBackdropColor(0.18, 0.08, 0.08, 0.9)
    headerRow:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.8)

    local h1 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h1:SetPoint("LEFT", headerRow, "LEFT", 10, 0)
    h1:SetText("|cffffcc00Игрок (Имя)|r")

    local h2 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h2:SetPoint("LEFT", headerRow, "LEFT", 160, 0)
    h2:SetText("|cffffcc00Дата добавления|r")

    local h3 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h3:SetPoint("LEFT", headerRow, "LEFT", 285, 0)
    h3:SetText("|cffffcc00Причина занесения|r")

    local h4 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h4:SetPoint("RIGHT", headerRow, "RIGHT", -25, 0)
    h4:SetText("|cffffcc00Действия|r")

    table.insert(blacklistWidgets, headerRow)
    currentY = currentY - 26

    for idx, k in ipairs(filteredKeys) do
        local data = bl[k]
        local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, currentY)
        row:SetSize(685, 26)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if idx % 2 == 0 then
            row:SetBackdropColor(0.12, 0.06, 0.06, 0.7)
        else
            row:SetBackdropColor(0.08, 0.04, 0.04, 0.7)
        end
        row:SetBackdropBorderColor(0.3, 0.15, 0.15, 0.6)

        -- Имя
        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameFS:SetPoint("LEFT", row, "LEFT", 10, 0)
        nameFS:SetText(string.format("|cffffff00%s|r", data.fullName or k))

        -- Дата
        local dateFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dateFS:SetPoint("LEFT", row, "LEFT", 160, 0)
        dateFS:SetText(string.format("|cffaaaaaa%s|r", data.date or "Ранее"))

        -- Причина
        local reasonFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reasonFS:SetPoint("LEFT", row, "LEFT", 285, 0)
        reasonFS:SetPoint("RIGHT", row, "RIGHT", -170, 0)
        reasonFS:SetJustifyH("LEFT")
        reasonFS:SetText(string.format("|cffffcc00%s|r", data.reason or "Без причины"))

        -- Кнопка "Причина"
        local editBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        editBtn:SetSize(75, 20)
        editBtn:SetPoint("RIGHT", row, "RIGHT", -86, 0)
        editBtn:SetText("Причина")
        editBtn:SetScript("OnClick", function()
            StaticPopup_Show("KAR_BLACKLIST_EDIT_REASON", data.fullName or k, nil, { name = data.fullName or k, reason = data.reason })
        end)

        -- Кнопка "Удалить"
        local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        delBtn:SetSize(75, 20)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        delBtn:SetText("|cffff3333Удалить|r")
        delBtn:SetScript("OnClick", function()
            KAR.RemoveFromBlacklist(k)
            KAR.RefreshBlacklistList()
        end)

        table.insert(blacklistWidgets, row)
        currentY = currentY - 28
    end

    local totalHeight = math.abs(currentY) + 30
    scrollChild:SetHeight(math.max(totalHeight, 460))
end



function KAR.OpenBlacklistGUI(initialTab)
    if blacklistFrame and blacklistFrame:IsShown() and not initialTab then
        blacklistFrame:Hide()
        return
    end

    if not blacklistFrame then
        blacklistFrame = CreateFrame("Frame", "KAR_BlacklistMainFrame", UIParent, "BackdropTemplate")
        blacklistFrame:SetSize(780, 640)
        blacklistFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        blacklistFrame:SetMovable(true)
        blacklistFrame:EnableMouse(true)
        blacklistFrame:RegisterForDrag("LeftButton")
        blacklistFrame:SetScript("OnDragStart", blacklistFrame.StartMoving)
        blacklistFrame:SetScript("OnDragStop", blacklistFrame.StopMovingOrSizing)
        blacklistFrame:SetClampedToScreen(true)
        blacklistFrame:SetFrameStrata("HIGH")

        blacklistFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        blacklistFrame:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.90)
        tinsert(UISpecialFrames, "KAR_BlacklistMainFrame")

        local bBg = blacklistFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
        bBg:SetAllPoints()
        bBg:SetTexture(TEXTURE_DIR .. "alucard_frame_bg.tga")

        local bTint = blacklistFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
        bTint:SetPoint("TOPLEFT", blacklistFrame, "TOPLEFT", 8, -8)
        bTint:SetPoint("BOTTOMRIGHT", blacklistFrame, "BOTTOMRIGHT", -8, 8)
        bTint:SetColorTexture(0.05, 0.04, 0.07, 0.82)

        local bHdr = CreateFrame("Frame", nil, blacklistFrame)
        bHdr:SetPoint("TOPLEFT", blacklistFrame, "TOPLEFT", 8, -8)
        bHdr:SetPoint("TOPRIGHT", blacklistFrame, "TOPRIGHT", -8, -8)
        bHdr:SetHeight(86)
        local bHdrTex = bHdr:CreateTexture(nil, "ARTWORK")
        bHdrTex:SetAllPoints()
        bHdrTex:SetTexture(TEXTURE_DIR .. "header_blacklist.tga")

        local closeXBtn = CreateStyledButton(bHdr, 26, 22, "|cffff5555✕|r", function() blacklistFrame:Hide() end, "red")
        closeXBtn:SetPoint("TOPRIGHT", bHdr, "TOPRIGHT", -6, -6)

        -- =========================================================
        -- ГЛАВНЫЕ ПОД-ВКЛАДКИ ОКНА ЧС: [СПИСОК ИГРОКОВ] vs [P2P СОПРЯЖЕНИЕ]
        -- =========================================================
        local tab1Btn = CreateStyledButton(blacklistFrame, 370, 26, "💀 Черный список игроков", nil)
        tab1Btn:SetPoint("TOPLEFT", blacklistFrame, "TOPLEFT", 14, -98)

        local tab2Btn = CreateStyledButton(blacklistFrame, 370, 26, "🔗 P2P Сопряжение и Синхронизация", nil)
        tab2Btn:SetPoint("LEFT", tab1Btn, "RIGHT", 12, 0)

        -- =========================================================
        -- КОНТЕЙНЕР 1: СПИСОК ИГРОКОВ В ЧС
        -- =========================================================
        local blListContainer = CreateFrame("Frame", nil, blacklistFrame)
        blListContainer:SetPoint("TOPLEFT", tab1Btn, "BOTTOMLEFT", 0, -6)
        blListContainer:SetPoint("BOTTOMRIGHT", blacklistFrame, "BOTTOMRIGHT", -14, 52)
        blacklistFrame.blListContainer = blListContainer

        local searchLabel = blListContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        searchLabel:SetPoint("TOPLEFT", blListContainer, "TOPLEFT", 4, -4)
        searchLabel:SetText("Поиск:")

        local searchBox = CreateFrame("Frame", nil, blListContainer, "BackdropTemplate")
        searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
        searchBox:SetSize(180, 24)
        searchBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        searchBox:SetBackdropColor(0.06, 0.05, 0.08, 0.95)
        searchBox:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.75)

        local searchEB = CreateFrame("EditBox", nil, searchBox)
        searchEB:SetPoint("TOPLEFT", searchBox, "TOPLEFT", 6, -2)
        searchEB:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", -6, 2)
        searchEB:SetFontObject("GameFontHighlightSmall")
        searchEB:SetAutoFocus(false)
        searchEB:SetScript("OnTextChanged", function(self)
            blacklistSearchQuery = self:GetText() or ""
            KAR.RefreshBlacklistList()
        end)
        searchEB:SetScript("OnEscapePressed", function(self)
            self:SetText("")
            self:ClearFocus()
        end)

        local addBtn = CreateStyledButton(blListContainer, 130, 24, "+ Добавить в ЧС", function()
            StaticPopup_Show("KAR_BLACKLIST_ADD_MANUAL")
        end)
        addBtn:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)

        local p2pSwitchBtn = CreateStyledButton(blListContainer, 190, 24, "|cff00ff00🔗 P2P Сопряжение|r", function()
            blacklistFrame.ShowP2PTab()
        end)
        p2pSwitchBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        blacklistFrame.p2pSwitchBtn = p2pSwitchBtn

        local countFS = blListContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countFS:SetPoint("RIGHT", blListContainer, "RIGHT", -18, 0)
        countFS:SetPoint("TOP", blListContainer, "TOP", 0, -8)
        countFS:SetText("Всего в ЧС: 0")
        blacklistFrame.countLabel = countFS

        local scrollFrame = CreateFrame("ScrollFrame", "KAR_BlacklistScrollFrame", blListContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", blListContainer, "TOPLEFT", 0, -34)
        scrollFrame:SetPoint("BOTTOMRIGHT", blListContainer, "BOTTOMRIGHT", -18, 0)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(720, 460)
        scrollFrame:SetScrollChild(scrollChild)
        blacklistFrame.scrollChild = scrollChild

        -- =========================================================
        -- КОНТЕЙНЕР 2: P2P СОПРЯЖЕНИЕ, ТЕЛЕМЕТРИЯ И СИНХРОНИЗАЦИЯ
        -- =========================================================
        local blP2PContainer = CreateFrame("Frame", nil, blacklistFrame)
        blP2PContainer:SetPoint("TOPLEFT", tab1Btn, "BOTTOMLEFT", 0, -6)
        blP2PContainer:SetPoint("BOTTOMRIGHT", blacklistFrame, "BOTTOMRIGHT", -14, 52)
        blacklistFrame.blP2PContainer = blP2PContainer

        -- Карточка управления сопряжением
        local commBox = CreateFrame("Frame", nil, blP2PContainer, "BackdropTemplate")
        commBox:SetPoint("TOPLEFT", blP2PContainer, "TOPLEFT", 0, 0)
        commBox:SetPoint("TOPRIGHT", blP2PContainer, "TOPRIGHT", 0, 0)
        commBox:SetHeight(76)
        commBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        commBox:SetBackdropColor(0.06, 0.05, 0.08, 0.95)
        commBox:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.85)

        local commTitle = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        commTitle:SetPoint("TOPLEFT", commBox, "TOPLEFT", 10, -8)
        commTitle:SetText("|cffff3344[P2P Сопряжение баз ЧС]|r Напарник:")

        local partnerBox = CreateFrame("Frame", nil, commBox, "BackdropTemplate")
        partnerBox:SetPoint("LEFT", commTitle, "RIGHT", 6, 0)
        partnerBox:SetSize(130, 20)
        partnerBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        partnerBox:SetBackdropColor(0.04, 0.03, 0.05, 0.95)
        partnerBox:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.7)

        local partnerEB = CreateFrame("EditBox", "KAR_BL_PartnerEditBox", partnerBox)
        partnerEB:SetPoint("TOPLEFT", partnerBox, "TOPLEFT", 4, 0)
        partnerEB:SetPoint("BOTTOMRIGHT", partnerBox, "BOTTOMRIGHT", -4, 0)
        partnerEB:SetFontObject("GameFontHighlightSmall")
        partnerEB:SetAutoFocus(false)
        blacklistFrame.partnerEB = partnerEB

        local targetBtn = CreateStyledButton(commBox, 55, 20, "Цель", function()
            local tName = UnitName("target")
            if tName and tName ~= "" then
                local cleanT = string.match(tName, "([^-]+)") or tName
                partnerEB:SetText(cleanT)
                partnerEB:ClearFocus()
            end
        end)
        targetBtn:SetPoint("LEFT", partnerBox, "RIGHT", 6, 0)

        local autoAcceptCb = CreateFrame("CheckButton", nil, commBox, "UICheckButtonTemplate")
        autoAcceptCb:SetPoint("LEFT", targetBtn, "RIGHT", 8, 0)
        autoAcceptCb:SetSize(20, 20)
        local initialAutoAccept = (KeyAutoRecruitDB and KeyAutoRecruitDB.p2pAutoAccept == true)
        autoAcceptCb:SetChecked(initialAutoAccept)
        autoAcceptCb:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            if KeyAutoRecruitDB then KeyAutoRecruitDB.p2pAutoAccept = isChecked end
            if KAR.Comm then KAR.Comm.autoAccept = isChecked end
            if KAR.Comm and KAR.Comm.AddLog then
                KAR.Comm.AddLog("INFO", string.format("Авто-прием сопряжения: %s", isChecked and "|cff00ff00ВКЛ|r" or "|cffff3333ВЫКЛ|r"), 0)
            end
        end)

        local autoAcceptFS = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        autoAcceptFS:SetPoint("LEFT", autoAcceptCb, "RIGHT", 2, 0)
        autoAcceptFS:SetText("|cffaaaaaaАвто-прием|r")

        local autoFriendSyncCb = CreateFrame("CheckButton", nil, commBox, "UICheckButtonTemplate")
        autoFriendSyncCb:SetPoint("LEFT", autoAcceptFS, "RIGHT", 8, 0)
        autoFriendSyncCb:SetSize(20, 20)
        local initialFriendSync = (KeyAutoRecruitDB and KeyAutoRecruitDB.autoFriendSync ~= false)
        autoFriendSyncCb:SetChecked(initialFriendSync)
        autoFriendSyncCb:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            if KeyAutoRecruitDB then KeyAutoRecruitDB.autoFriendSync = isChecked end
            if KAR.Comm and KAR.Comm.AddLog then
                KAR.Comm.AddLog("INFO", string.format("Авто-синхро с друзьями при встрече: %s", isChecked and "|cff00ff00ВКЛ|r" or "|cffff3333ВЫКЛ|r"), 0)
            end
        end)

        local autoFriendSyncFS = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        autoFriendSyncFS:SetPoint("LEFT", autoFriendSyncCb, "RIGHT", 2, 0)
        autoFriendSyncFS:SetText("|cff00ffccСинхро друзей|r")

        local commStatusFS = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        commStatusFS:SetPoint("LEFT", autoFriendSyncFS, "RIGHT", 10, 0)
        commStatusFS:SetPoint("RIGHT", commBox, "RIGHT", -10, 0)
        commStatusFS:SetJustifyH("LEFT")
        blacklistFrame.commStatusFS = commStatusFS

        local function UpdateBLCommStatusText()
            local st = (KAR.Comm and KAR.Comm.state) or "IDLE"
            local partner = (KAR.Comm and KAR.Comm.partner) or ""
            local tx = (KAR.Comm and KAR.Comm.txCount) or 0
            local rx = (KAR.Comm and KAR.Comm.rxCount) or 0
            local counters = string.format(" | TX: |cff00ccff%d|r | RX: |cff00ff7f%d|r", tx, rx)

            if st == "PAIRED" then
                commStatusFS:SetText(string.format("|cff00ff00● Сопряжено с: |cffffff00%s|r%s", partner, counters))
                if blacklistFrame.p2pSwitchBtn then
                    blacklistFrame.p2pSwitchBtn:SetText(string.format("|cff00ff00● P2P: %s|r", partner))
                end
            elseif st == "WAIT_ACK" then
                commStatusFS:SetText(string.format("|cffffff00● Ожидание рукопожатия от %s...%s|r", partner, counters))
            elseif st == "TRANSFERRING" then
                commStatusFS:SetText(string.format("|cff00ccff● Передача базы по сети...%s|r", counters))
            else
                commStatusFS:SetText(string.format("|cffaaaaaa● Не сопряжено%s|r", counters))
                if blacklistFrame.p2pSwitchBtn then
                    blacklistFrame.p2pSwitchBtn:SetText("|cffaaaaaa🔗 P2P Сопряжение|r")
                end
            end
        end
        blacklistFrame.UpdateCommStatus = UpdateBLCommStatusText

        -- Кнопки действий (Ряд 2)
        local handshakeBtn = CreateStyledButton(commBox, 160, 24, "|cff00ff00🔗 1. Сопряжение|r", function()
            local targetName = partnerEB:GetText() or ""
            if KAR.Comm and KAR.Comm.RequestHandshake then
                KAR.Comm.RequestHandshake(targetName, "MANUAL")
            end
        end)
        handshakeBtn:SetPoint("BOTTOMLEFT", commBox, "BOTTOMLEFT", 10, 8)

        local pingBtn = CreateStyledButton(commBox, 85, 24, "⚡ Пинг", function()
            if KAR.Comm and KAR.Comm.SendPing then
                KAR.Comm.SendPing()
            end
        end)
        pingBtn:SetPoint("LEFT", handshakeBtn, "RIGHT", 6, 0)

        local sendDbBtn = CreateStyledButton(commBox, 160, 24, "|cff00ccff📦 2. Отправить базу|r", function()
            if KAR.Comm and KAR.Comm.SendDatabaseToPartner then
                KAR.Comm.SendDatabaseToPartner()
            end
        end)
        sendDbBtn:SetPoint("LEFT", pingBtn, "RIGHT", 6, 0)

        local reqDbBtn = CreateStyledButton(commBox, 165, 24, "📥 3. Запросить базу", function()
            if KAR.Comm and KAR.Comm.RequestDatabaseFromPartner then
                KAR.Comm.RequestDatabaseFromPartner()
            end
        end)
        reqDbBtn:SetPoint("LEFT", sendDbBtn, "RIGHT", 6, 0)

        local disconnectBtn = CreateStyledButton(commBox, 85, 24, "|cffff5555Разрыв|r", function()
            if KAR.Comm and KAR.Comm.Disconnect then
                KAR.Comm.Disconnect()
            end
        end)
        disconnectBtn:SetPoint("LEFT", reqDbBtn, "RIGHT", 6, 0)

        -- Под-вкладки внутри P2P панели: [ТЕЛЕМЕТРИЯ] vs [JSON / ТЕКСТ]
        local subP2PTab1 = CreateStyledButton(blP2PContainer, 230, 24, "📡 P2P Эвристика и Логи", nil)
        subP2PTab1:SetPoint("TOPLEFT", commBox, "BOTTOMLEFT", 0, -8)

        local subP2PTab2 = CreateStyledButton(blP2PContainer, 230, 24, "📋 База JSON / Ручной Импорт", nil)
        subP2PTab2:SetPoint("LEFT", subP2PTab1, "RIGHT", 8, 0)

        -- ---------------------------------------------------------
        -- ПОД-ВКЛАДКА 1: ТЕЛЕМЕТРИЯ И ЛОГИ СЕТИ P2P
        -- ---------------------------------------------------------
        local telemetryCard = CreateFrame("Frame", nil, blP2PContainer, "BackdropTemplate")
        telemetryCard:SetPoint("TOPLEFT", subP2PTab1, "BOTTOMLEFT", 0, -6)
        telemetryCard:SetPoint("BOTTOMRIGHT", blP2PContainer, "BOTTOMRIGHT", 0, 0)
        telemetryCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        telemetryCard:SetBackdropColor(0.04, 0.03, 0.05, 0.98)
        telemetryCard:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.85)
        blacklistFrame.telemetryCard = telemetryCard

        local tScroll = CreateFrame("ScrollFrame", "KAR_BL_TelemetryScroll", telemetryCard, "UIPanelScrollFrameTemplate")
        tScroll:SetPoint("TOPLEFT", telemetryCard, "TOPLEFT", 6, -6)
        tScroll:SetPoint("BOTTOMRIGHT", telemetryCard, "BOTTOMRIGHT", -26, 34)

        local tLogBox = CreateFrame("EditBox", nil, tScroll)
        tLogBox:SetMultiLine(true)
        tLogBox:SetMaxLetters(99999)
        tLogBox:EnableMouse(true)
        tLogBox:SetAutoFocus(false)
        tLogBox:SetFontObject("GameFontHighlightSmall")
        tLogBox:SetWidth(710)
        tLogBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        tScroll:SetScrollChild(tLogBox)
        blacklistFrame.tLogBox = tLogBox

        local clearTLogBtn = CreateStyledButton(telemetryCard, 110, 22, "Очистить лог", function()
            if KAR.Comm then KAR.Comm.logHistory = {} end
            tLogBox:SetText("")
        end)
        clearTLogBtn:SetPoint("BOTTOMLEFT", telemetryCard, "BOTTOMLEFT", 8, 6)

        local selectTLogBtn = CreateStyledButton(telemetryCard, 120, 22, "Выделить всё", function()
            tLogBox:SetFocus()
            tLogBox:HighlightText()
        end)
        selectTLogBtn:SetPoint("LEFT", clearTLogBtn, "RIGHT", 8, 0)

        local tInfoFS = telemetryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tInfoFS:SetPoint("BOTTOMRIGHT", telemetryCard, "BOTTOMRIGHT", -12, 10)
        tInfoFS:SetText("|cff888888Префикс: KAR_SYNC | MTU: 255b | Канал: WHISPER (P2P Mesh)|r")

        function KAR.UpdateTelemetryLog()
            local targetBox = (blacklistFrame and blacklistFrame.tLogBox) or (pasteFrame and pasteFrame.tLogBox)
            if targetBox and targetBox:IsVisible() then
                local hist = (KAR.Comm and KAR.Comm.logHistory) or {}
                local fullText = table.concat(hist, "\n")
                targetBox:SetText(fullText)
                targetBox:SetCursorPosition(#fullText)
            end
        end

        -- ---------------------------------------------------------
        -- ПОД-ВКЛАДКА 2: РУЧНОЙ JSON / ТЕКСТ
        -- ---------------------------------------------------------
        local jsonCard = CreateFrame("Frame", nil, blP2PContainer)
        jsonCard:SetPoint("TOPLEFT", subP2PTab1, "BOTTOMLEFT", 0, -6)
        jsonCard:SetPoint("BOTTOMRIGHT", blP2PContainer, "BOTTOMRIGHT", 0, 0)
        blacklistFrame.jsonCard = jsonCard

        local descFS = jsonCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descFS:SetPoint("TOPLEFT", jsonCard, "TOPLEFT", 4, 0)
        descFS:SetPoint("TOPRIGHT", jsonCard, "TOPRIGHT", -4, 0)
        descFS:SetJustifyH("LEFT")
        descFS:SetText("|cffccccccБаза данных ЧС (JSON / Текст). Вставьте JSON для импорта или нажмите 'Выгрузить (JSON)':|r")

        local ebBg = CreateFrame("Frame", nil, jsonCard, "BackdropTemplate")
        ebBg:SetPoint("TOPLEFT", descFS, "BOTTOMLEFT", 0, -6)
        ebBg:SetPoint("BOTTOMRIGHT", jsonCard, "BOTTOMRIGHT", 0, 34)
        ebBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        ebBg:SetBackdropColor(0.04, 0.03, 0.05, 0.96)
        ebBg:SetBackdropBorderColor(0.70, 0.15, 0.22, 0.85)

        local scrollFrame2 = CreateFrame("ScrollFrame", "KAR_BL_JsonScrollFrame", ebBg, "UIPanelScrollFrameTemplate")
        scrollFrame2:SetPoint("TOPLEFT", ebBg, "TOPLEFT", 6, -6)
        scrollFrame2:SetPoint("BOTTOMRIGHT", ebBg, "BOTTOMRIGHT", -26, 6)

        local editBox = CreateFrame("EditBox", "KAR_BL_JsonEditBox", scrollFrame2)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(710)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(0)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame2:SetScrollChild(editBox)
        blacklistFrame.editBox = editBox

        local statusLabel = jsonCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusLabel:SetPoint("TOPLEFT", ebBg, "BOTTOMLEFT", 4, -4)
        statusLabel:SetPoint("TOPRIGHT", ebBg, "BOTTOMRIGHT", -150, -4)
        statusLabel:SetJustifyH("LEFT")
        blacklistFrame.statusLabel = statusLabel

        local importBtn = CreateStyledButton(jsonCard, 220, 24, "|cff00ff00Загрузить в ЧС (JSON / Текст)|r", function()
            local rawText = editBox:GetText() or ""
            if rawText:gsub("%s+", "") == "" then
                statusLabel:SetText("|cffff3333Ошибка: поле пустое! Вставьте JSON или текст.|r")
                return
            end

            local db = KeyAutoRecruitDB
            if not db then return end
            if not db.blacklist then db.blacklist = {} end

            local nowTime = (time and time()) or 0
            local nowDate = (date and date("%d.%m.%Y %H:%M")) or "сегодня"
            local added = 0
            local updated = 0

            local isJSON = false
            local trimmedFirst = rawText:match("^%s*(%S)")
            if trimmedFirst == "{" or trimmedFirst == "[" then
                local ok, parsed = pcall(KAR.JSON.Decode, rawText)
                if ok and parsed and type(parsed) == "table" then
                    isJSON = true
                    local list = parsed.blacklist or parsed.items or parsed.data or parsed
                    for _, item in pairs(list) do
                        local pName, pReason, pDate, pTimestamp = nil, nil, nil, nil
                        if type(item) == "table" then
                            pName = item.name or item.player or item[1]
                            pReason = item.reason or item.desc or item[2]
                            pDate = item.date or item[3]
                            pTimestamp = item.timestamp or item[4]
                        elseif type(item) == "string" then
                            pName = item
                        end

                        if pName and pName ~= "" then
                            local cleanName = string.match(pName, "([^-]+)") or pName
                            cleanName = cleanName:gsub("%s+", "")
                            if cleanName ~= "" then
                                pReason = pReason or "Синхронизация ЧС"
                                local cleanLower = cleanName:lower()

                                local existingKey = nil
                                for k in pairs(db.blacklist) do
                                    if (string.match(k, "([^-]+)") or k):lower() == cleanLower then
                                        existingKey = k
                                        break
                                    end
                                end

                                if existingKey then
                                    db.blacklist[existingKey].reason = pReason
                                    db.blacklist[existingKey].date = pDate or nowDate
                                    db.blacklist[existingKey].timestamp = pTimestamp or nowTime
                                    updated = updated + 1
                                else
                                    db.blacklist[cleanName] = {
                                        name = cleanName,
                                        fullName = cleanName,
                                        reason = pReason,
                                        date = pDate or nowDate,
                                        timestamp = pTimestamp or nowTime
                                    }
                                    added = added + 1
                                end
                            end
                        end
                    end
                end
            end

            if not isJSON then
                for line in string.gmatch(rawText .. "\n", "([^\r\n]*)\r?\n") do
                    local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
                    if trimmed ~= "" and not trimmed:find("^#") and not trimmed:find("^%-%-") then
                        local pName, pReason = nil, nil
                        if trimmed:find(":") then
                            pName, pReason = trimmed:match("^([^:]+):%s*(.*)$")
                        elseif trimmed:find("|") then
                            pName, pReason = trimmed:match("^([^|]+)|%s*(.*)$")
                        elseif trimmed:find(";") then
                            pName, pReason = trimmed:match("^([^;]+);%s*(.*)$")
                        elseif trimmed:find(" %- ") then
                            pName, pReason = trimmed:match("^(.-)%s+%-%s+(.*)$")
                        else
                            pName, pReason = trimmed:match("^(%S+)%s*(.*)$")
                        end

                        if pName and pName ~= "" then
                            pName = string.match(pName, "([^-]+)") or pName
                            pName = pName:gsub("%s+", "")
                            if pName ~= "" then
                                pReason = (pReason and pReason:gsub("^%s*(.-)%s*$", "%1")) or ""
                                if pReason == "" then pReason = "Синхронизация ЧС" end

                                local cleanLower = string.lower(pName)
                                local existingKey = nil
                                for k in pairs(db.blacklist) do
                                    if string.lower(string.match(k, "([^-]+)") or k) == cleanLower then
                                        existingKey = k
                                        break
                                    end
                                end

                                if existingKey then
                                    db.blacklist[existingKey].reason = pReason
                                    db.blacklist[existingKey].timestamp = nowTime
                                    db.blacklist[existingKey].date = nowDate
                                    updated = updated + 1
                                else
                                    db.blacklist[pName] = {
                                        name = pName,
                                        fullName = pName,
                                        reason = pReason,
                                        date = nowDate,
                                        timestamp = nowTime
                                    }
                                    added = added + 1
                                end
                            end
                        end
                    end
                end
            end

            local totalTotal = 0
            for _ in pairs(db.blacklist) do totalTotal = totalTotal + 1 end

            statusLabel:SetText(string.format("|cff00ff00Импорт (%s) успешен! +%d новых, %d обновлено.|r", isJSON and "JSON" or "Текст", added, updated))
            KAR.Log(string.format("|cff00ff00[ЧС Импорт]|r Успешно загружено (%s): +%d новых, %d обновлено. Всего записей: %d чел.", isJSON and "JSON" or "Текст", added, updated, totalTotal))

            if KAR.RefreshOpenGUIs then KAR.RefreshOpenGUIs() end
        end)
        importBtn:SetPoint("BOTTOMLEFT", jsonCard, "BOTTOMLEFT", 0, 6)

        local exportJsonBtn = CreateStyledButton(jsonCard, 150, 24, "|cff00ccffВыгрузить (JSON)|r", function()
            local db = KeyAutoRecruitDB
            local bl = db and db.blacklist
            if not bl or next(bl) == nil then
                editBox:SetText("")
                statusLabel:SetText("|cffffcc00База ЧС пуста. Нечего экспортировать.|r")
                return
            end

            local names = {}
            for name in pairs(bl) do table.insert(names, name) end
            table.sort(names, function(a, b) return a:lower() < b:lower() end)

            local blArray = {}
            for _, name in ipairs(names) do
                local d = bl[name]
                table.insert(blArray, {
                    name = d.name or name,
                    reason = d.reason or "Без описания",
                    date = d.date or "сегодня",
                    timestamp = d.timestamp or 0
                })
            end

            local rootTable = {
                generator = "KeyAutoRecruit",
                version = 1,
                date = (date and date("%d.%m.%Y %H:%M")) or "сегодня",
                count = #blArray,
                blacklist = blArray
            }

            local jsonStr = KAR.JSON.Encode(rootTable, true)
            editBox:SetText(jsonStr)
            editBox:SetFocus()
            editBox:HighlightText()

            statusLabel:SetText(string.format("|cff00ff00Выгружен JSON (%d записей)! Нажмите Ctrl+C.|r", #names))
            KAR.Log(string.format("|cff00ccff[ЧС Экспорт]|r База ЧС выгружена в JSON (%d записей). Скопируйте текст.", #names))
        end)
        exportJsonBtn:SetPoint("LEFT", importBtn, "RIGHT", 6, 0)

        local exportTextBtn = CreateStyledButton(jsonCard, 140, 24, "Выгрузить (Текст)", function()
            local db = KeyAutoRecruitDB
            local bl = db and db.blacklist
            if not bl or next(bl) == nil then
                editBox:SetText("")
                statusLabel:SetText("|cffffcc00База ЧС пуста. Нечего экспортировать.|r")
                return
            end

            local names = {}
            for name in pairs(bl) do table.insert(names, name) end
            table.sort(names, function(a, b) return a:lower() < b:lower() end)

            local lines = {}
            for _, name in ipairs(names) do
                local data = bl[name]
                local reason = (data and data.reason) or "Без описания"
                table.insert(lines, string.format("%s: %s", name, reason))
            end

            local fullText = table.concat(lines, "\n")
            editBox:SetText(fullText)
            editBox:SetFocus()
            editBox:HighlightText()

            statusLabel:SetText(string.format("|cff00ff00Выгружен текст (%d записей)! Нажмите Ctrl+C.|r", #names))
            KAR.Log(string.format("|cff00ccff[ЧС Экспорт]|r База ЧС выгружена в текст (%d записей).", #names))
        end)
        exportTextBtn:SetPoint("LEFT", exportJsonBtn, "RIGHT", 6, 0)

        local selectBtn = CreateStyledButton(jsonCard, 90, 24, "Выделить", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        selectBtn:SetPoint("LEFT", exportTextBtn, "RIGHT", 6, 0)

        local clearBtn = CreateStyledButton(jsonCard, 90, 24, "Очистить", function()
            editBox:SetText("")
            statusLabel:SetText("|cffaaaaaaПоле ввода очищено.|r")
        end)
        clearBtn:SetPoint("LEFT", selectBtn, "RIGHT", 6, 0)

        -- Логика переключения под-вкладок внутри P2P
        local function ShowP2PTelemetry()
            telemetryCard:Show()
            jsonCard:Hide()
            subP2PTab1:SetBackdropBorderColor(0.95, 0.25, 0.35, 1.0)
            subP2PTab2:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
            KAR.UpdateTelemetryLog()
        end

        local function ShowP2PJson()
            telemetryCard:Hide()
            jsonCard:Show()
            subP2PTab1:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
            subP2PTab2:SetBackdropBorderColor(0.95, 0.25, 0.35, 1.0)
        end

        subP2PTab1:SetScript("OnClick", ShowP2PTelemetry)
        subP2PTab2:SetScript("OnClick", ShowP2PJson)
        ShowP2PTelemetry()

        -- Логика переключения главных вкладок
        function blacklistFrame.ShowBlacklistTab()
            blListContainer:Show()
            blP2PContainer:Hide()
            tab1Btn:SetBackdropBorderColor(0.95, 0.25, 0.35, 1.0)
            tab2Btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
            KAR.RefreshBlacklistList()
        end

        function blacklistFrame.ShowP2PTab()
            blListContainer:Hide()
            blP2PContainer:Show()
            tab1Btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
            tab2Btn:SetBackdropBorderColor(0.95, 0.25, 0.35, 1.0)
            UpdateBLCommStatusText()
            KAR.UpdateTelemetryLog()
        end

        tab1Btn:SetScript("OnClick", blacklistFrame.ShowBlacklistTab)
        tab2Btn:SetScript("OnClick", blacklistFrame.ShowP2PTab)

        KAR.AttachDockBar(blacklistFrame, "blacklist")
    end

    blacklistFrame:Show()
    if initialTab == "p2p" then
        blacklistFrame.ShowP2PTab()
    else
        blacklistFrame.ShowBlacklistTab()
    end
    if blacklistFrame.UpdateCommStatus then blacklistFrame.UpdateCommStatus() end
end

function KAR.RefreshOpenGUIs()
    if recentGroupsFrame and recentGroupsFrame:IsShown() then
        KAR.RefreshRecentGroupsList()
    end
    if blacklistFrame and blacklistFrame:IsShown() then
        KAR.RefreshBlacklistList()
    end
    if KAR.UpdatePasteDbCount then
        KAR.UpdatePasteDbCount()
    end
end


-- =============================================================
-- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС 3: СИНХРОНИЗАЦИЯ ЧС (ИМПОРТ / ЭКСПОРТ /paste)
-- =============================================================
local pasteFrame = nil

function KAR.UpdatePasteDbCount()
    if pasteFrame and pasteFrame:IsShown() then
        local count = 0
        if KeyAutoRecruitDB and KeyAutoRecruitDB.blacklist then
            for _ in pairs(KeyAutoRecruitDB.blacklist) do count = count + 1 end
        end
        if pasteFrame.dbCountLabel then
            pasteFrame.dbCountLabel:SetText(string.format("В базе ЧС: |cffffff00%d|r игроков", count))
        end
        if pasteFrame.UpdateCommStatus then
            pasteFrame.UpdateCommStatus()
        end
    end
end

function KAR.UpdatePasteStatus(msg)
    if pasteFrame and pasteFrame.statusLabel and pasteFrame:IsShown() then
        pasteFrame.statusLabel:SetText(msg or "")
    end
    if pasteFrame and pasteFrame.UpdateCommStatus and pasteFrame:IsShown() then
        pasteFrame.UpdateCommStatus()
    end
end



function KAR.OpenPasteGUI()
    if pasteFrame and pasteFrame:IsShown() then
        pasteFrame:Hide()
        return
    end

    if not pasteFrame then
        pasteFrame = CreateFrame("Frame", "KAR_PasteSyncFrame", UIParent, "BackdropTemplate")
        pasteFrame:SetSize(780, 640)
        pasteFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        pasteFrame:SetMovable(true)
        pasteFrame:EnableMouse(true)
        pasteFrame:RegisterForDrag("LeftButton")
        pasteFrame:SetScript("OnDragStart", pasteFrame.StartMoving)
        pasteFrame:SetScript("OnDragStop", pasteFrame.StopMovingOrSizing)
        pasteFrame:SetClampedToScreen(true)
        pasteFrame:SetFrameStrata("HIGH")

        pasteFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        pasteFrame:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.90)
        tinsert(UISpecialFrames, "KAR_PasteSyncFrame")

        local pBg = pasteFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
        pBg:SetAllPoints()
        pBg:SetTexture(TEXTURE_DIR .. "alucard_frame_bg.tga")

        local pTint = pasteFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
        pTint:SetPoint("TOPLEFT", pasteFrame, "TOPLEFT", 8, -8)
        pTint:SetPoint("BOTTOMRIGHT", pasteFrame, "BOTTOMRIGHT", -8, 8)
        pTint:SetColorTexture(0.05, 0.04, 0.07, 0.82)

        local pHdr = CreateFrame("Frame", nil, pasteFrame)
        pHdr:SetPoint("TOPLEFT", pasteFrame, "TOPLEFT", 8, -8)
        pHdr:SetPoint("TOPRIGHT", pasteFrame, "TOPRIGHT", -8, -8)
        pHdr:SetHeight(86)
        local pHdrTex = pHdr:CreateTexture(nil, "ARTWORK")
        pHdrTex:SetAllPoints()
        pHdrTex:SetTexture(TEXTURE_DIR .. "header_paste_sync.tga")

        local closeXBtn = CreateStyledButton(pHdr, 26, 22, "|cffff5555✕|r", function() pasteFrame:Hide() end, "red")
        closeXBtn:SetPoint("TOPRIGHT", pHdr, "TOPRIGHT", -6, -6)

        -- =========================================================
        -- =========================================================
        -- ПАНЕЛЬ 1: P2P СОПРЯЖЕНИЕ И РУКОПОЖАТИЕ КЛИЕНТОВ (COMM)
        -- =========================================================
        local commBox = CreateFrame("Frame", nil, pasteFrame, "BackdropTemplate")
        commBox:SetPoint("TOPLEFT", pasteFrame, "TOPLEFT", 14, -98)
        commBox:SetPoint("TOPRIGHT", pasteFrame, "TOPRIGHT", -14, -98)
        commBox:SetHeight(76)
        commBox:SetBackdrop({
            bgFile = "Interface\Buttons\WHITE8X8",
            edgeFile = "Interface\Buttons\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        commBox:SetBackdropColor(0.06, 0.05, 0.08, 0.95)
        commBox:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.85)

        local commTitle = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        commTitle:SetPoint("TOPLEFT", commBox, "TOPLEFT", 10, -8)
        commTitle:SetText("|cffff3344[Сопряжение клиентов]|r Напарник:")

        local partnerBox = CreateFrame("Frame", nil, commBox, "BackdropTemplate")
        partnerBox:SetPoint("LEFT", commTitle, "RIGHT", 6, 0)
        partnerBox:SetSize(130, 20)
        partnerBox:SetBackdrop({
            bgFile = "Interface\Buttons\WHITE8X8",
            edgeFile = "Interface\Buttons\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        partnerBox:SetBackdropColor(0.04, 0.03, 0.05, 0.95)
        partnerBox:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.7)

        local partnerEB = CreateFrame("EditBox", "KAR_PastePartnerEditBox", partnerBox)
        partnerEB:SetPoint("TOPLEFT", partnerBox, "TOPLEFT", 4, 0)
        partnerEB:SetPoint("BOTTOMRIGHT", partnerBox, "BOTTOMRIGHT", -4, 0)
        partnerEB:SetFontObject("GameFontHighlightSmall")
        partnerEB:SetAutoFocus(false)
        pasteFrame.partnerEB = partnerEB

        local targetBtn = CreateStyledButton(commBox, 55, 20, "Цель", function()
            local tName = UnitName("target")
            if tName and tName ~= "" then
                local cleanT = string.match(tName, "([^-]+)") or tName
                partnerEB:SetText(cleanT)
                partnerEB:ClearFocus()
            end
        end)
        targetBtn:SetPoint("LEFT", partnerBox, "RIGHT", 6, 0)

        local autoAcceptCb = CreateFrame("CheckButton", nil, commBox, "UICheckButtonTemplate")
        autoAcceptCb:SetPoint("LEFT", targetBtn, "RIGHT", 8, 0)
        autoAcceptCb:SetSize(20, 20)
        local initialAutoAccept = (KeyAutoRecruitDB and KeyAutoRecruitDB.p2pAutoAccept == true)
        autoAcceptCb:SetChecked(initialAutoAccept)
        autoAcceptCb:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            if KeyAutoRecruitDB then KeyAutoRecruitDB.p2pAutoAccept = isChecked end
            if KAR.Comm then KAR.Comm.autoAccept = isChecked end
            if KAR.Comm and KAR.Comm.AddLog then
                KAR.Comm.AddLog("INFO", string.format("Авто-прием сопряжения: %s", isChecked and "|cff00ff00ВКЛ|r" or "|cffff3333ВЫКЛ|r"), 0)
            end
        end)

        local autoAcceptFS = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        autoAcceptFS:SetPoint("LEFT", autoAcceptCb, "RIGHT", 2, 0)
        autoAcceptFS:SetText("|cffaaaaaaАвто-прием|r")

        local autoFriendSyncCb = CreateFrame("CheckButton", nil, commBox, "UICheckButtonTemplate")
        autoFriendSyncCb:SetPoint("LEFT", autoAcceptFS, "RIGHT", 8, 0)
        autoFriendSyncCb:SetSize(20, 20)
        local initialFriendSync = (KeyAutoRecruitDB and KeyAutoRecruitDB.autoFriendSync ~= false)
        autoFriendSyncCb:SetChecked(initialFriendSync)
        autoFriendSyncCb:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            if KeyAutoRecruitDB then KeyAutoRecruitDB.autoFriendSync = isChecked end
            if KAR.Comm and KAR.Comm.AddLog then
                KAR.Comm.AddLog("INFO", string.format("Авто-синхро с друзьями при встрече: %s", isChecked and "|cff00ff00ВКЛ|r" or "|cffff3333ВЫКЛ|r"), 0)
            end
        end)

        local autoFriendSyncFS = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        autoFriendSyncFS:SetPoint("LEFT", autoFriendSyncCb, "RIGHT", 2, 0)
        autoFriendSyncFS:SetText("|cff00ffccСинхро друзей|r")

        local commStatusFS = commBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        commStatusFS:SetPoint("LEFT", autoFriendSyncFS, "RIGHT", 10, 0)
        commStatusFS:SetPoint("RIGHT", commBox, "RIGHT", -10, 0)
        commStatusFS:SetJustifyH("LEFT")
        pasteFrame.commStatusFS = commStatusFS

        local function UpdateCommStatusText()
            local st = (KAR.Comm and KAR.Comm.state) or "IDLE"
            local partner = (KAR.Comm and KAR.Comm.partner) or ""
            local tx = (KAR.Comm and KAR.Comm.txCount) or 0
            local rx = (KAR.Comm and KAR.Comm.rxCount) or 0
            local counters = string.format(" | TX: |cff00ccff%d|r | RX: |cff00ff7f%d|r", tx, rx)

            if st == "PAIRED" then
                commStatusFS:SetText(string.format("|cff00ff00● Сопряжено с: |cffffff00%s|r%s", partner, counters))
            elseif st == "WAIT_ACK" then
                commStatusFS:SetText(string.format("|cffffff00● Ожидание рукопожатия от %s...%s|r", partner, counters))
            elseif st == "TRANSFERRING" then
                commStatusFS:SetText(string.format("|cff00ccff● Передача по сети...%s|r", counters))
            else
                commStatusFS:SetText(string.format("|cffaaaaaa● Не сопряжено%s|r", counters))
            end
        end
        pasteFrame.UpdateCommStatus = UpdateCommStatusText

        -- Кнопки действий сопряжения (Ряд 2)
        local handshakeBtn = CreateStyledButton(commBox, 160, 24, "|cff00ff00🔗 1. Сопряжение|r", function()
            local targetName = partnerEB:GetText() or ""
            if KAR.Comm and KAR.Comm.RequestHandshake then
                KAR.Comm.RequestHandshake(targetName, "MANUAL")
            end
        end)
        handshakeBtn:SetPoint("BOTTOMLEFT", commBox, "BOTTOMLEFT", 10, 8)

        local pingBtn = CreateStyledButton(commBox, 85, 24, "⚡ Пинг", function()
            if KAR.Comm and KAR.Comm.SendPing then
                KAR.Comm.SendPing()
            end
        end)
        pingBtn:SetPoint("LEFT", handshakeBtn, "RIGHT", 6, 0)

        local sendDbBtn = CreateStyledButton(commBox, 160, 24, "|cff00ccff📦 2. Отправить базу|r", function()
            if KAR.Comm and KAR.Comm.SendDatabaseToPartner then
                KAR.Comm.SendDatabaseToPartner()
            end
        end)
        sendDbBtn:SetPoint("LEFT", pingBtn, "RIGHT", 6, 0)

        local reqDbBtn = CreateStyledButton(commBox, 165, 24, "📥 3. Запросить базу", function()
            if KAR.Comm and KAR.Comm.RequestDatabaseFromPartner then
                KAR.Comm.RequestDatabaseFromPartner()
            end
        end)
        reqDbBtn:SetPoint("LEFT", sendDbBtn, "RIGHT", 6, 0)

        local disconnectBtn = CreateStyledButton(commBox, 85, 24, "|cffff5555Разрыв|r", function()
            if KAR.Comm and KAR.Comm.Disconnect then
                KAR.Comm.Disconnect()
            end
        end)
        disconnectBtn:SetPoint("LEFT", reqDbBtn, "RIGHT", 6, 0)

        -- =========================================================
        -- ПЕРЕКЛЮЧАТЕЛЬ ПОД-ВКЛАДОК: ТЕЛЕМЕТРИЯ VS ТЕКСТ / JSON
        -- =========================================================
        local subTab1 = CreateStyledButton(pasteFrame, 230, 24, "📡 P2P Эвристика и Логи", nil)
        subTab1:SetPoint("TOPLEFT", commBox, "BOTTOMLEFT", 0, -8)

        local subTab2 = CreateStyledButton(pasteFrame, 230, 24, "📋 База JSON / Ручной Импорт", nil)
        subTab2:SetPoint("LEFT", subTab1, "RIGHT", 8, 0)

        -- ---------------------------------------------------------
        -- ПОД-ВКЛАДКА 1: P2P ТЕЛЕМЕТРИЯ И ЛОГИ СЕТИ
        -- ---------------------------------------------------------
        local telemetryCard = CreateFrame("Frame", nil, pasteFrame, "BackdropTemplate")
        telemetryCard:SetPoint("TOPLEFT", subTab1, "BOTTOMLEFT", 0, -6)
        telemetryCard:SetPoint("BOTTOMRIGHT", pasteFrame, "BOTTOMRIGHT", -14, 52)
        telemetryCard:SetBackdrop({
            bgFile = "Interface\Buttons\WHITE8X8",
            edgeFile = "Interface\Buttons\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        telemetryCard:SetBackdropColor(0.04, 0.03, 0.05, 0.98)
        telemetryCard:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.85)
        pasteFrame.telemetryCard = telemetryCard

        local tScroll = CreateFrame("ScrollFrame", "KAR_P2P_TelemetryScroll", telemetryCard, "UIPanelScrollFrameTemplate")
        tScroll:SetPoint("TOPLEFT", telemetryCard, "TOPLEFT", 6, -6)
        tScroll:SetPoint("BOTTOMRIGHT", telemetryCard, "BOTTOMRIGHT", -26, 34)

        local tLogBox = CreateFrame("EditBox", nil, tScroll)
        tLogBox:SetMultiLine(true)
        tLogBox:SetMaxLetters(99999)
        tLogBox:EnableMouse(true)
        tLogBox:SetAutoFocus(false)
        tLogBox:SetFontObject("GameFontHighlightSmall")
        tLogBox:SetWidth(710)
        tLogBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        tScroll:SetScrollChild(tLogBox)
        pasteFrame.tLogBox = tLogBox

        local clearTLogBtn = CreateStyledButton(telemetryCard, 110, 22, "Очистить лог", function()
            if KAR.Comm then KAR.Comm.logHistory = {} end
            tLogBox:SetText("")
        end)
        clearTLogBtn:SetPoint("BOTTOMLEFT", telemetryCard, "BOTTOMLEFT", 8, 6)

        local selectTLogBtn = CreateStyledButton(telemetryCard, 120, 22, "Выделить всё", function()
            tLogBox:SetFocus()
            tLogBox:HighlightText()
        end)
        selectTLogBtn:SetPoint("LEFT", clearTLogBtn, "RIGHT", 8, 0)

        local tInfoFS = telemetryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tInfoFS:SetPoint("BOTTOMRIGHT", telemetryCard, "BOTTOMRIGHT", -12, 10)
        tInfoFS:SetText("|cff888888Префикс: KAR_SYNC | MTU: 255b | Канал: WHISPER (P2P Mesh)|r")

        function KAR.UpdateTelemetryLog()
            if pasteFrame and pasteFrame.tLogBox and pasteFrame:IsShown() and pasteFrame.telemetryCard:IsShown() then
                local hist = (KAR.Comm and KAR.Comm.logHistory) or {}
                local fullText = table.concat(hist, "\n")
                pasteFrame.tLogBox:SetText(fullText)
                pasteFrame.tLogBox:SetCursorPosition(#fullText)
            end
        end

        -- ---------------------------------------------------------
        -- ПОД-ВКЛАДКА 2: РУЧНОЙ JSON / ТЕКСТ
        -- ---------------------------------------------------------
        local jsonCard = CreateFrame("Frame", nil, pasteFrame)
        jsonCard:SetPoint("TOPLEFT", subTab1, "BOTTOMLEFT", 0, -6)
        jsonCard:SetPoint("BOTTOMRIGHT", pasteFrame, "BOTTOMRIGHT", -14, 52)
        pasteFrame.jsonCard = jsonCard

        local descFS = jsonCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descFS:SetPoint("TOPLEFT", jsonCard, "TOPLEFT", 4, 0)
        descFS:SetPoint("TOPRIGHT", jsonCard, "TOPRIGHT", -4, 0)
        descFS:SetJustifyH("LEFT")
        descFS:SetText("|cffccccccБаза данных ЧС (JSON / Текст). Вставьте JSON для импорта или нажмите 'Выгрузить (JSON)':|r")

        local ebBg = CreateFrame("Frame", nil, jsonCard, "BackdropTemplate")
        ebBg:SetPoint("TOPLEFT", descFS, "BOTTOMLEFT", 0, -6)
        ebBg:SetPoint("BOTTOMRIGHT", jsonCard, "BOTTOMRIGHT", 0, 34)
        ebBg:SetBackdrop({
            bgFile = "Interface\Buttons\WHITE8X8",
            edgeFile = "Interface\Buttons\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        ebBg:SetBackdropColor(0.04, 0.03, 0.05, 0.96)
        ebBg:SetBackdropBorderColor(0.70, 0.15, 0.22, 0.85)

        local scrollFrame = CreateFrame("ScrollFrame", "KAR_PasteScrollFrame", ebBg, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", ebBg, "TOPLEFT", 6, -6)
        scrollFrame:SetPoint("BOTTOMRIGHT", ebBg, "BOTTOMRIGHT", -26, 6)

        local editBox = CreateFrame("EditBox", "KAR_PasteEditBox", scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(710)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(0)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
        pasteFrame.editBox = editBox

        local statusLabel = jsonCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusLabel:SetPoint("TOPLEFT", ebBg, "BOTTOMLEFT", 4, -4)
        statusLabel:SetPoint("TOPRIGHT", ebBg, "BOTTOMRIGHT", -150, -4)
        statusLabel:SetJustifyH("LEFT")
        pasteFrame.statusLabel = statusLabel

        local dbCountLabel = jsonCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dbCountLabel:SetPoint("TOPRIGHT", ebBg, "BOTTOMRIGHT", -4, -4)
        dbCountLabel:SetJustifyH("RIGHT")
        pasteFrame.dbCountLabel = dbCountLabel

        local importBtn = CreateStyledButton(jsonCard, 220, 24, "|cff00ff00Загрузить в ЧС (JSON / Текст)|r", function()
            local rawText = editBox:GetText() or ""
            if rawText:gsub("%s+", "") == "" then
                statusLabel:SetText("|cffff3333Ошибка: поле пустое! Вставьте JSON или текст.|r")
                return
            end

            local db = KeyAutoRecruitDB
            if not db then return end
            if not db.blacklist then db.blacklist = {} end

            local nowTime = (time and time()) or 0
            local nowDate = (date and date("%d.%m.%Y %H:%M")) or "сегодня"
            local added = 0
            local updated = 0

            local isJSON = false
            local trimmedFirst = rawText:match("^%s*(%S)")
            if trimmedFirst == "{" or trimmedFirst == "[" then
                local ok, parsed = pcall(KAR.JSON.Decode, rawText)
                if ok and parsed and type(parsed) == "table" then
                    isJSON = true
                    local list = parsed.blacklist or parsed.items or parsed.data or parsed
                    for _, item in pairs(list) do
                        local pName, pReason, pDate, pTimestamp = nil, nil, nil, nil
                        if type(item) == "table" then
                            pName = item.name or item.player or item[1]
                            pReason = item.reason or item.desc or item[2]
                            pDate = item.date or item[3]
                            pTimestamp = item.timestamp or item[4]
                        elseif type(item) == "string" then
                            pName = item
                        end

                        if pName and pName ~= "" then
                            local cleanName = string.match(pName, "([^-]+)") or pName
                            cleanName = cleanName:gsub("%s+", "")
                            if cleanName ~= "" then
                                pReason = pReason or "Синхронизация ЧС"
                                local cleanLower = cleanName:lower()

                                local existingKey = nil
                                for k in pairs(db.blacklist) do
                                    if (string.match(k, "([^-]+)") or k):lower() == cleanLower then
                                        existingKey = k
                                        break
                                    end
                                end

                                if existingKey then
                                    db.blacklist[existingKey].reason = pReason
                                    db.blacklist[existingKey].date = pDate or nowDate
                                    db.blacklist[existingKey].timestamp = pTimestamp or nowTime
                                    updated = updated + 1
                                else
                                    db.blacklist[cleanName] = {
                                        name = cleanName,
                                        fullName = cleanName,
                                        reason = pReason,
                                        date = pDate or nowDate,
                                        timestamp = pTimestamp or nowTime
                                    }
                                    added = added + 1
                                end
                            end
                        end
                    end
                end
            end

            if not isJSON then
                for line in string.gmatch(rawText .. "\n", "([^\r\n]*)\r?\n") do
                    local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
                    if trimmed ~= "" and not trimmed:find("^#") and not trimmed:find("^%-%-") then
                        local pName, pReason = nil, nil
                        if trimmed:find(":") then
                            pName, pReason = trimmed:match("^([^:]+):%s*(.*)$")
                        elseif trimmed:find("|") then
                            pName, pReason = trimmed:match("^([^|]+)|%s*(.*)$")
                        elseif trimmed:find(";") then
                            pName, pReason = trimmed:match("^([^;]+);%s*(.*)$")
                        elseif trimmed:find(" %- ") then
                            pName, pReason = trimmed:match("^(.-)%s+%-%s+(.*)$")
                        else
                            pName, pReason = trimmed:match("^(%S+)%s*(.*)$")
                        end

                        if pName and pName ~= "" then
                            pName = string.match(pName, "([^-]+)") or pName
                            pName = pName:gsub("%s+", "")
                            if pName ~= "" then
                                pReason = (pReason and pReason:gsub("^%s*(.-)%s*$", "%1")) or ""
                                if pReason == "" then pReason = "Синхронизация ЧС" end

                                local cleanLower = string.lower(pName)
                                local existingKey = nil
                                for k in pairs(db.blacklist) do
                                    if string.lower(string.match(k, "([^-]+)") or k) == cleanLower then
                                        existingKey = k
                                        break
                                    end
                                end

                                if existingKey then
                                    db.blacklist[existingKey].reason = pReason
                                    db.blacklist[existingKey].timestamp = nowTime
                                    db.blacklist[existingKey].date = nowDate
                                    updated = updated + 1
                                else
                                    db.blacklist[pName] = {
                                        name = pName,
                                        fullName = pName,
                                        reason = pReason,
                                        date = nowDate,
                                        timestamp = nowTime
                                    }
                                    added = added + 1
                                end
                            end
                        end
                    end
                end
            end

            local totalTotal = 0
            for _ in pairs(db.blacklist) do totalTotal = totalTotal + 1 end

            statusLabel:SetText(string.format("|cff00ff00Импорт (%s) успешен! +%d новых, %d обновлено.|r", isJSON and "JSON" or "Текст", added, updated))
            KAR.Log(string.format("|cff00ff00[ЧС Импорт]|r Успешно загружено (%s): +%d новых, %d обновлено. Всего записей: %d чел.", isJSON and "JSON" or "Текст", added, updated, totalTotal))

            if KAR.RefreshOpenGUIs then KAR.RefreshOpenGUIs() end
        end)
        importBtn:SetPoint("BOTTOMLEFT", jsonCard, "BOTTOMLEFT", 0, 6)

        local exportJsonBtn = CreateStyledButton(jsonCard, 150, 24, "|cff00ccffВыгрузить (JSON)|r", function()
            local db = KeyAutoRecruitDB
            local bl = db and db.blacklist
            if not bl or next(bl) == nil then
                editBox:SetText("")
                statusLabel:SetText("|cffffcc00База ЧС пуста. Нечего экспортировать.|r")
                return
            end

            local names = {}
            for name in pairs(bl) do table.insert(names, name) end
            table.sort(names, function(a, b) return a:lower() < b:lower() end)

            local blArray = {}
            for _, name in ipairs(names) do
                local d = bl[name]
                table.insert(blArray, {
                    name = d.name or name,
                    reason = d.reason or "Без описания",
                    date = d.date or "сегодня",
                    timestamp = d.timestamp or 0
                })
            end

            local rootTable = {
                generator = "KeyAutoRecruit",
                version = 1,
                date = (date and date("%d.%m.%Y %H:%M")) or "сегодня",
                count = #blArray,
                blacklist = blArray
            }

            local jsonStr = KAR.JSON.Encode(rootTable, true)
            editBox:SetText(jsonStr)
            editBox:SetFocus()
            editBox:HighlightText()

            statusLabel:SetText(string.format("|cff00ff00Выгружен JSON (%d записей)! Нажмите Ctrl+C.|r", #names))
            KAR.Log(string.format("|cff00ccff[ЧС Экспорт]|r База ЧС выгружена в JSON (%d записей). Скопируйте текст.", #names))
        end)
        exportJsonBtn:SetPoint("LEFT", importBtn, "RIGHT", 6, 0)

        local exportTextBtn = CreateStyledButton(jsonCard, 140, 24, "Выгрузить (Текст)", function()
            local db = KeyAutoRecruitDB
            local bl = db and db.blacklist
            if not bl or next(bl) == nil then
                editBox:SetText("")
                statusLabel:SetText("|cffffcc00База ЧС пуста. Нечего экспортировать.|r")
                return
            end

            local names = {}
            for name in pairs(bl) do table.insert(names, name) end
            table.sort(names, function(a, b) return a:lower() < b:lower() end)

            local lines = {}
            for _, name in ipairs(names) do
                local data = bl[name]
                local reason = (data and data.reason) or "Без описания"
                table.insert(lines, string.format("%s: %s", name, reason))
            end

            local fullText = table.concat(lines, "\n")
            editBox:SetText(fullText)
            editBox:SetFocus()
            editBox:HighlightText()

            statusLabel:SetText(string.format("|cff00ff00Выгружен текст (%d записей)! Нажмите Ctrl+C.|r", #names))
            KAR.Log(string.format("|cff00ccff[ЧС Экспорт]|r База ЧС выгружена в текст (%d записей).", #names))
        end)
        exportTextBtn:SetPoint("LEFT", exportJsonBtn, "RIGHT", 6, 0)

        local selectBtn = CreateStyledButton(jsonCard, 90, 24, "Выделить", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        selectBtn:SetPoint("LEFT", exportTextBtn, "RIGHT", 6, 0)

        local clearBtn = CreateStyledButton(jsonCard, 90, 24, "Очистить", function()
            editBox:SetText("")
            statusLabel:SetText("|cffaaaaaaПоле ввода очищено.|r")
        end)
        clearBtn:SetPoint("LEFT", selectBtn, "RIGHT", 6, 0)

        -- Логика переключения вкладок
        local function ShowTelemetryTab()
            telemetryCard:Show()
            jsonCard:Hide()
            subTab1:SetBackdropBorderColor(0.95, 0.25, 0.35, 1.0)
            subTab2:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
            KAR.UpdateTelemetryLog()
        end

        local function ShowJsonTab()
            telemetryCard:Hide()
            jsonCard:Show()
            subTab1:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
            subTab2:SetBackdropBorderColor(0.95, 0.25, 0.35, 1.0)
        end

        subTab1:SetScript("OnClick", ShowTelemetryTab)
        subTab2:SetScript("OnClick", ShowJsonTab)

        -- По умолчанию открываем P2P Эвристику и Телеметрию
        ShowTelemetryTab()

        KAR.AttachDockBar(pasteFrame, "paste")
    end

    pasteFrame:Show()
    if KAR.UpdatePasteDbCount then KAR.UpdatePasteDbCount() end
end

SLASH_KAR_PASTE1 = "/paste"
SLASH_KAR_PASTE2 = "/karpaste"
SLASH_KAR_PASTE3 = "/karsync"
SLASH_KAR_PASTE4 = "/karimport"
SLASH_KAR_PASTE5 = "/karexport"
SLASH_KAR_PASTE6 = "/karpair"
SLASH_KAR_PASTE7 = "/karcomm"
SLASH_KAR_PASTE8 = "/p2p"

SlashCmdList["KAR_PASTE"] = function(msg)
    KAR.OpenPasteGUI()
end

-- 1. Слэш-команда истории 5 групп (/pg, /kargroups, /karpg, /pastgroups)
SLASH_KAR_PG1 = "/pg"
SLASH_KAR_PG2 = "/kargroups"
SLASH_KAR_PG3 = "/karpg"
SLASH_KAR_PG4 = "/pastgroups"

SlashCmdList["KAR_PG"] = function(msg)
    local raw = msg or ""
    local trimmed = raw:gsub("^%s*(.-)%s*$", "%1")
    local lower = trimmed:lower()

    if lower:sub(1, 3) == "bl " or lower:sub(1, 4) == "add " or lower:sub(1, 4) == "чс " then
        local rest = trimmed:gsub("^%S+%s+", "")
        local pName, pReason = rest:match("^(%S+)%s*(.*)$")
        if pName and pName ~= "" then
            KAR.AddToBlacklist(pName, (pReason and pReason ~= "") and pReason or "Без причины")
        else
            KAR.Log("Использование: /pg bl <Имя> <Причина>")
        end
    elseif lower:sub(1, 7) == "remove " or lower:sub(1, 4) == "del " or lower:sub(1, 7) == "удалить " then
        local pName = trimmed:match("%S+$")
        if pName and pName ~= "" then
            KAR.RemoveFromBlacklist(pName)
        else
            KAR.Log("Использование: /pg del <Имя>")
        end
    else
        KAR.OpenRecentGroupsGUI()
    end
end

-- 2. Слэш-команда Черного списка (/pb, /pbl, /karbl)
SLASH_KAR_PB1 = "/pb"
SLASH_KAR_PB2 = "/pbl"
SLASH_KAR_PB3 = "/karbl"
SLASH_KAR_PB4 = "/karblist"

SlashCmdList["KAR_PB"] = function(msg)
    local raw = msg or ""
    local trimmed = raw:gsub("^%s*(.-)%s*$", "%1")
    local lower = trimmed:lower()

    if lower:sub(1, 4) == "add " or lower:sub(1, 3) == "bl " then
        local rest = trimmed:gsub("^%S+%s+", "")
        local pName, pReason = rest:match("^(%S+)%s*(.*)$")
        if pName and pName ~= "" then
            KAR.AddToBlacklist(pName, (pReason and pReason ~= "") and pReason or "Без причины")
        else
            KAR.Log("Использование: /pb add <Имя> <Причина>")
        end
    elseif lower:sub(1, 7) == "remove " or lower:sub(1, 4) == "del " then
        local pName = trimmed:match("%S+$")
        if pName and pName ~= "" then
            KAR.RemoveFromBlacklist(pName)
        else
            KAR.Log("Использование: /pb del <Имя>")
        end
    elseif lower:sub(1, 5) == "paste" or lower:sub(1, 4) == "sync" or lower:sub(1, 6) == "import" then
        KAR.OpenPasteGUI()
    else
        KAR.OpenBlacklistGUI()
    end
end

-- 3. Основная команда /kar
SLASH_KEYAUTORECRUIT1 = "/kar"
SLASH_KEYAUTORECRUIT2 = "/keyrecruit"
SLASH_KEYAUTORECRUIT3 = "/autorecruit"

SlashCmdList["KEYAUTORECRUIT"] = function(msg)
    local rawMsg = msg or ""
    msg = rawMsg:lower():gsub("^%s*(.-)%s*$", "%1")

    if msg == "pixel" or msg == "testpixel" then
        if KAR.ToggleTestPixel then KAR.ToggleTestPixel() end
    elseif msg == "test tank" or msg == "testtank" then
        if KAR.TestRoleAnnouncement then KAR.TestRoleAnnouncement("TANK") end
    elseif msg == "test heal" or msg == "testheal" or msg == "test healer" then
        if KAR.TestRoleAnnouncement then KAR.TestRoleAnnouncement("HEALER") end
    elseif msg == "test dps" or msg == "testdps" or msg == "test dd" then
        if KAR.TestRoleAnnouncement then KAR.TestRoleAnnouncement("DPS") end
    elseif msg == "test full" or msg == "testfull" then
        if KAR.AnnounceGroupFull then KAR.AnnounceGroupFull() end
    elseif msg == "pg" or msg == "p" or msg == "groups" or msg == "recent" then
        KAR.OpenRecentGroupsGUI()
    elseif msg == "pb" or msg == "bl" or msg == "blacklist" or msg == "чс" then
        KAR.OpenBlacklistGUI()
    elseif msg == "paste" or msg == "sync" or msg == "import" or msg == "export" or msg == "синх" then
        KAR.OpenPasteGUI()
    elseif msg:sub(1, 6) == "bl add" or msg:sub(1, 7) == "чс доб" then
        local rest = rawMsg:gsub("^%S+%s+%S+%s*", "")
        local pName, pReason = rest:match("^(%S+)%s*(.*)$")
        if pName and pName ~= "" then
            KAR.AddToBlacklist(pName, (pReason and pReason ~= "") and pReason or "Без причины")
        else
            KAR.Log("Использование: /kar bl add <Имя> <Причина>")
        end
    elseif msg:sub(1, 9) == "bl remove" or msg:sub(1, 6) == "bl del" or msg:sub(1, 6) == "чс уд" then
        local pName = rawMsg:match("%S+$")
        if pName and pName ~= "" then
            KAR.RemoveFromBlacklist(pName)
        else
            KAR.Log("Использование: /kar bl remove <Имя>")
        end
    elseif msg:sub(1, 7) == "unmute " or msg:sub(1, 9) == "unblock " then
        local pName = rawMsg:match("%S+$")
        if pName and pName ~= "" then
            local clean = (pName:match("([^-]+)") or pName):lower()
            if KeyAutoRecruitDB and KeyAutoRecruitDB.p2pMutedPlayers then
                KeyAutoRecruitDB.p2pMutedPlayers[clean] = nil
            end
            if KAR.Comm and KAR.Comm.blockedPartners then
                KAR.Comm.blockedPartners[clean] = nil
            end
            KAR.Log(string.format("Игрок |cffffff00%s|r разблокирован для P2P сопряжения.", pName))
        end
    elseif msg == "p2pclear" or msg == "unblockall" then
        if KeyAutoRecruitDB then KeyAutoRecruitDB.p2pMutedPlayers = {} end
        if KAR.Comm then KAR.Comm.blockedPartners = {} end
        KAR.Log("Все блокировки P2P и список 'Не уведомлять' успешно очищены.")
    else
        KAR.OpenGUI()
    end
end


-- =============================================================
-- ТОГГЛ-ФУНКЦИИ И НАЗНАЧЕНИЕ КЛАВИШ В BLIZZARD (KEYBINDINGS)
-- =============================================================
function KAR_ToggleRecentGroups()
    if KAR and KAR.OpenRecentGroupsGUI then
        KAR.OpenRecentGroupsGUI()
    end
end

function KAR_ToggleBlacklist()
    if KAR and KAR.OpenBlacklistGUI then
        KAR.OpenBlacklistGUI()
    end
end

function KAR_ToggleSettings()
    if KAR and KAR.OpenGUI then
        KAR.OpenGUI()
    end
end

function KAR_TogglePaste()
    if KAR and KAR.OpenPasteGUI then
        KAR.OpenPasteGUI()
    end
end

_G["KAR_ToggleRecentGroups"] = KAR_ToggleRecentGroups
_G["KAR_ToggleBlacklist"] = KAR_ToggleBlacklist
_G["KAR_ToggleSettings"] = KAR_ToggleSettings
_G["KAR_TogglePaste"] = KAR_TogglePaste

_G["BINDING_HEADER_KEYAUTORECRUIT"] = "KeyAutoRecruit"
_G["BINDING_HEADER_KeyAutoRecruit"] = "KeyAutoRecruit"
_G["BINDING_NAME_KAR_RECENT_GROUPS"] = "Открыть историю последних 5 групп (/pg)"
_G["BINDING_NAME_KAR_BLACKLIST"] = "Открыть Черный список (/pb)"
_G["BINDING_NAME_KAR_SETTINGS"] = "Открыть настройки авто-набора (/kar)"
_G["BINDING_NAME_KAR_PASTE_SYNC"] = "Синхронизация Черного списка (/paste)"


-- =============================================================
-- МОДУЛЬ ЭВРИСТИКИ ПОДЗЕМЕЛЬЯ (Dungeon Experience Probe /kh)
-- =============================================================
KAR.DUNGEON_NAMES = {
    [501] = "Каменный Свод",
    [502] = "Город Нитей",
    [503] = "Ара-Кара, Город Отголосков",
    [504] = "Рассветный Крушитель",
    [505] = "Система Синатра",
    [506] = "Осада Боралуса",
    [507] = "Грим Батол",
    [508] = "Туманы Тирна Скитта",
    [509] = "Смертельная Тризна",
}

function KAR.GetTargetDungeonInfo()
    local target = {
        name = "Не определено",
        mapID = 0,
        challengeModeID = 0,
        targetLevel = 0,
        source = "NONE"
    }

    if C_LFGList and C_LFGList.GetActiveEntryInfo then
        local entryInfo = C_LFGList.GetActiveEntryInfo()
        if entryInfo and entryInfo.activityID then
            local actInfo = C_LFGList.GetActivityInfoTable(entryInfo.activityID)
            if actInfo then
                target.name = actInfo.fullName or actInfo.shortName or "Подземелье LFG"
                target.mapID = actInfo.groupFinderActivityGroupID or 0
                target.source = "LFG"
                local lvlInName = string.match(actInfo.fullName or "", "%+(%d+)")
                               or string.match(entryInfo.name or "", "%+(%d+)")
                               or string.match(entryInfo.name or "", "%f[%d](%d+)%f[%D]")
                if lvlInName then
                    local parsed = tonumber(lvlInName) or 0
                    if parsed > 0 and parsed <= 40 then target.targetLevel = parsed end
                end
                if target.targetLevel == 0 and C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel then
                    local bagLvl = C_MythicPlus.GetOwnedKeystoneLevel()
                    if bagLvl and bagLvl > 0 then target.targetLevel = bagLvl end
                end
                return target
            end
        end
    end

    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        local activeMapID = C_ChallengeMode.GetActiveChallengeMapID()
        if activeMapID and activeMapID > 0 then
            local name = C_ChallengeMode.GetMapUIInfo(activeMapID)
            target.name = name or KAR.DUNGEON_NAMES[activeMapID] or ("Карта #" .. tostring(activeMapID))
            target.mapID = activeMapID
            target.challengeModeID = activeMapID
            target.source = "ACTIVE_KEY"

            if C_ChallengeMode.GetActiveKeystoneInfo then
                local ok, kLevel = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
                if ok and type(kLevel) == "number" then
                    target.targetLevel = kLevel
                elseif ok and type(kLevel) == "table" then
                    target.targetLevel = tonumber(kLevel.activeKeystoneLevel or kLevel.level or 0) or 0
                end
            end
            return target
        end
    end

    if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID then
        local bagMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local bagLevel = C_MythicPlus.GetOwnedKeystoneLevel()
        if bagMapID and bagMapID > 0 then
            local name = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(bagMapID)) or KAR.DUNGEON_NAMES[bagMapID]
            target.name = name or ("Ключ в сумке #" .. tostring(bagMapID))
            target.mapID = bagMapID
            target.challengeModeID = bagMapID
            target.targetLevel = bagLevel or 0
            target.source = "BAG_KEY"
            return target
        end
    end

    local zoneText = GetRealZoneText() or GetZoneText()
    if zoneText and zoneText ~= "" then
        target.name = zoneText
        target.source = "ZONE"
    end

    return target
end

function KAR.GetApplicantHeuristic(applicantID, memberIndex)
    memberIndex = memberIndex or 1
    if not C_LFGList or not C_LFGList.GetApplicantMemberInfo then return nil end

    local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, memberIndex)
    if not name then return nil end

    local role = tank and "TANK" or (healer and "HEALER" or "DAMAGER")
    local bestRunLevel = 0
    local finishedSuccess = false
    local dungeonScoreForMap = 0

    if C_LFGList.GetApplicantDungeonScoreInfo then
        local ok, scoreInfo = pcall(C_LFGList.GetApplicantDungeonScoreInfo, applicantID, memberIndex)
        if ok and scoreInfo then
            bestRunLevel = tonumber(scoreInfo.bestRunLevel) or 0
            finishedSuccess = (scoreInfo.finishedSuccess == true)
            dungeonScoreForMap = tonumber(scoreInfo.mapScore) or 0
        end
    end

    local targetInfo = KAR.GetTargetDungeonInfo()
    local expColor = "ffaaaaaa"
    local expText = "Нет данных"

    local maxDeficit = (KeyAutoRecruitDB and KeyAutoRecruitDB.maxDungeonKeyDeficit) or 2
    if bestRunLevel > 0 then
        if targetInfo.targetLevel > 0 then
            local deficit = targetInfo.targetLevel - bestRunLevel
            if deficit <= 0 then
                expColor = finishedSuccess and "ff00ff00" or "ff00ccff"
                expText = string.format("+%d (%s, ОК)", bestRunLevel, finishedSuccess and "Вовремя" or "Не в тайм")
            elseif deficit <= maxDeficit then
                expColor = "ffffff00"
                expText = string.format("+%d (%s, отст: %d ур)", bestRunLevel, finishedSuccess and "Вовремя" or "Не в тайм", deficit)
            else
                expColor = "ffff6600"
                expText = string.format("+%d (%s, отст: %d > %d)", bestRunLevel, finishedSuccess and "В тайм" or "Слив", deficit, maxDeficit)
            end
        else
            expColor = finishedSuccess and "ff00ff00" or "ffffff00"
            expText = string.format("+%d (%s)", bestRunLevel, finishedSuccess and "Вовремя" or "Не в тайм")
        end
    else
        expColor = "ffff3333"
        expText = string.format("0 (Нет ключа, отст: %d > %d)", targetInfo.targetLevel > 0 and targetInfo.targetLevel or 0, maxDeficit)
    end

    return {
        name = name,
        class = class or "WARRIOR",
        role = role,
        ilvl = math.floor(itemLevel or 0),
        totalRio = math.floor(dungeonScore or 0),
        bestKeyLevel = bestRunLevel,
        isTimed = finishedSuccess,
        mapScore = dungeonScoreForMap,
        expColor = expColor,
        expText = expText,
        targetDungeon = targetInfo.name,
        targetLevel = targetInfo.targetLevel
    }
end

function KAR.GetUnitDungeonHeuristic(unit)
    if not UnitExists(unit) then return nil end
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    local targetInfo = KAR.GetTargetDungeonInfo()

    local bestLevel = 0
    local isTimed = false
    local totalRio = 0

    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
        if ok and summary then
            totalRio = summary.currentSeasonScore or 0
            if summary.runs then
                for _, run in ipairs(summary.runs) do
                    local runMapID = run.challengeModeID or run.mapChallengeModeID
                    if runMapID and targetInfo.challengeModeID > 0 and runMapID == targetInfo.challengeModeID then
                        local rLvl = tonumber(run.bestRunLevel or run.level or 0) or 0
                        if rLvl > bestLevel then
                            bestLevel = rLvl
                            isTimed = (run.finishedSuccess == true)
                        end
                    end
                end
            end
        end
    end

    local expColor = (bestLevel >= (targetInfo.targetLevel > 0 and targetInfo.targetLevel or 1)) and "ff00ff00" or ((bestLevel > 0) and "ffffff00" or "ffff3333")
    local expText = (bestLevel > 0) and string.format("+%d (%s)", bestLevel, isTimed and "Вовремя" or "Не в тайм") or "0 (Нет забегов в этот ключ)"

    return {
        name = name,
        class = class or "WARRIOR",
        totalRio = math.floor(totalRio or 0),
        bestKeyLevel = bestLevel,
        isTimed = isTimed,
        expColor = expColor,
        expText = expText,
        targetDungeon = targetInfo.name,
        targetLevel = targetInfo.targetLevel
    }
end

local heuristicsFrame = nil
local hRowWidgets = {}



function KAR.OpenHeuristicsGUI()
    if heuristicsFrame and heuristicsFrame:IsShown() then
        heuristicsFrame:Hide()
        return
    end

    if not heuristicsFrame then
        heuristicsFrame = CreateFrame("Frame", "KAR_HeuristicsFrame", UIParent, "BackdropTemplate")
        heuristicsFrame:SetSize(780, 620)
        heuristicsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        heuristicsFrame:SetMovable(true)
        heuristicsFrame:EnableMouse(true)
        heuristicsFrame:RegisterForDrag("LeftButton")
        heuristicsFrame:SetScript("OnDragStart", heuristicsFrame.StartMoving)
        heuristicsFrame:SetScript("OnDragStop", heuristicsFrame.StopMovingOrSizing)
        heuristicsFrame:SetClampedToScreen(true)
        heuristicsFrame:SetFrameStrata("HIGH")

        heuristicsFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        heuristicsFrame:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.90)
        tinsert(UISpecialFrames, "KAR_HeuristicsFrame")

        local hBg = heuristicsFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
        hBg:SetAllPoints()
        hBg:SetTexture(TEXTURE_DIR .. "alucard_frame_bg.tga")

        local hTint = heuristicsFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
        hTint:SetPoint("TOPLEFT", heuristicsFrame, "TOPLEFT", 8, -8)
        hTint:SetPoint("BOTTOMRIGHT", heuristicsFrame, "BOTTOMRIGHT", -8, 8)
        hTint:SetColorTexture(0.05, 0.04, 0.07, 0.82)

        local hHdr = CreateFrame("Frame", nil, heuristicsFrame)
        hHdr:SetPoint("TOPLEFT", heuristicsFrame, "TOPLEFT", 8, -8)
        hHdr:SetPoint("TOPRIGHT", heuristicsFrame, "TOPRIGHT", -8, -8)
        hHdr:SetHeight(86)
        local hHdrTex = hHdr:CreateTexture(nil, "ARTWORK")
        hHdrTex:SetAllPoints()
        hHdrTex:SetTexture(TEXTURE_DIR .. "header_heuristics.tga")

        local closeXBtn = CreateStyledButton(hHdr, 26, 22, "|cffff5555✕|r", function() heuristicsFrame:Hide() end, "red")
        closeXBtn:SetPoint("TOPRIGHT", hHdr, "TOPRIGHT", -6, -6)

        local targetBox = CreateFrame("Frame", nil, heuristicsFrame, "BackdropTemplate")
        targetBox:SetPoint("TOPLEFT", heuristicsFrame, "TOPLEFT", 14, -98)
        targetBox:SetPoint("TOPRIGHT", heuristicsFrame, "TOPRIGHT", -14, -98)
        targetBox:SetHeight(48)
        targetBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        targetBox:SetBackdropColor(0.06, 0.05, 0.08, 0.95)
        targetBox:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.85)

        local targetLabel = targetBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        targetLabel:SetPoint("LEFT", targetBox, "LEFT", 12, 0)
        heuristicsFrame.targetLabel = targetLabel

        local refreshBtn = CreateStyledButton(targetBox, 110, 24, "Обновить", function()
            KAR.RefreshHeuristicsList()
        end)
        refreshBtn:SetPoint("RIGHT", targetBox, "RIGHT", -10, 0)

        local scrollFrame = CreateFrame("ScrollFrame", "KAR_HScrollFrame", heuristicsFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", targetBox, "BOTTOMLEFT", 0, -8)
        scrollFrame:SetPoint("BOTTOMRIGHT", heuristicsFrame, "BOTTOMRIGHT", -32, 70)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(720, 400)
        scrollFrame:SetScrollChild(scrollChild)
        heuristicsFrame.scrollChild = scrollChild

        local bottomFS = heuristicsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bottomFS:SetPoint("BOTTOMLEFT", heuristicsFrame, "BOTTOMLEFT", 18, 52)
        bottomFS:SetText("|cffaaaaaaЭвристика: зеленый = закрывал этот ключ в тайм, желтый = близкий ключ, красный = нет опыта в этом данже.|r")

        KAR.AttachDockBar(heuristicsFrame, "heuristics")
    end

    heuristicsFrame:Show()
    KAR.RefreshHeuristicsList()
end

function KAR.RefreshHeuristicsList()
    if not hRowWidgets then hRowWidgets = {} end
    if not heuristicsFrame or not heuristicsFrame:IsShown() then return end

    local targetInfo = KAR.GetTargetDungeonInfo()
    local lvlStr = targetInfo.targetLevel > 0 and string.format(" (+%d)", targetInfo.targetLevel) or ""
    heuristicsFrame.targetLabel:SetText(string.format("Целевое подземелье: |cffffff00%s%s|r [Источник: %s]", targetInfo.name, lvlStr, targetInfo.source))

    for _, w in ipairs(hRowWidgets) do w:Hide() end
    hRowWidgets = {}

    local currentY = -6
    local index = 0

    if C_LFGList and C_LFGList.GetApplicants then
        local applicants = C_LFGList.GetApplicants() or {}
        if #applicants > 0 then
            local header = heuristicsFrame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPLEFT", heuristicsFrame.scrollChild, "TOPLEFT", 10, currentY)
            header:SetText(string.format("|cff00ffffВходящие заявки в LFG (%d):|r", #applicants))
            table.insert(hRowWidgets, header)
            currentY = currentY - 24

            for _, appID in ipairs(applicants) do
                local appInfo = C_LFGList.GetApplicantInfo(appID)
                local numM = appInfo and appInfo.numMembers or 1
                for mi = 1, numM do
                    local h = KAR.GetApplicantHeuristic(appID, mi)
                    if h then
                        index = index + 1
                        local row = CreateFrame("Frame", nil, heuristicsFrame.scrollChild, "BackdropTemplate")
                        row:SetSize(650, 30)
                        row:SetPoint("TOPLEFT", heuristicsFrame.scrollChild, "TOPLEFT", 10, currentY)
                        row:SetBackdrop({
                            bgFile = "Interface\\Buttons\\WHITE8X8",
                            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                            tile = true, tileSize = 16, edgeSize = 10,
                            insets = { left = 2, right = 2, top = 2, bottom = 2 }
                        })
                        local bgAlpha = (index % 2 == 0) and 0.25 or 0.15
                        row:SetBackdropColor(0.1, 0.12, 0.18, bgAlpha)
                        row:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.5)

                        local cHex = "FFFFFF"
                        if KAR.CLASS_COLORS and KAR.CLASS_COLORS[h.class] then
                            cHex = KAR.CLASS_COLORS[h.class]
                        end
                        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        nameFS:SetPoint("LEFT", row, "LEFT", 10, 0)
                        nameFS:SetText(string.format("[%s] |cff%s%s|r", h.role, cHex, h.name))

                        local statsFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        statsFS:SetPoint("LEFT", row, "LEFT", 210, 0)
                        statsFS:SetText(string.format("ilvl: |cffffff00%d|r  RIO: |cffffff00%d|r", h.ilvl, h.totalRio))

                        local expFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        expFS:SetPoint("RIGHT", row, "RIGHT", -12, 0)
                        expFS:SetText(string.format("Опыт в этом ключе: |c%s%s|r", h.expColor, h.expText))

                        table.insert(hRowWidgets, row)
                        currentY = currentY - 34
                    end
                end
            end
            currentY = currentY - 10
        end
    end

    local numMembers = GetNumGroupMembers()
    if numMembers > 0 then
        local header = heuristicsFrame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", heuristicsFrame.scrollChild, "TOPLEFT", 10, currentY)
        header:SetText(string.format("|cff00ff00Текущая группа (%d чел):|r", numMembers))
        table.insert(hRowWidgets, header)
        currentY = currentY - 24

        for i = 1, numMembers do
            local unit = (numMembers == 1 and "player") or (i == 1 and "player" or ("party" .. (i - 1)))
            local h = KAR.GetUnitDungeonHeuristic(unit)
            if h then
                index = index + 1
                local row = CreateFrame("Frame", nil, heuristicsFrame.scrollChild, "BackdropTemplate")
                row:SetSize(650, 30)
                row:SetPoint("TOPLEFT", heuristicsFrame.scrollChild, "TOPLEFT", 10, currentY)
                row:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                row:SetBackdropColor(0.08, 0.14, 0.12, 0.3)
                row:SetBackdropBorderColor(0.2, 0.6, 0.4, 0.6)

                local cHex = "FFFFFF"
                if KAR.CLASS_COLORS and KAR.CLASS_COLORS[h.class] then
                    cHex = KAR.CLASS_COLORS[h.class]
                end
                local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                nameFS:SetPoint("LEFT", row, "LEFT", 10, 0)
                nameFS:SetText(string.format("|cff%s%s|r %s", cHex, h.name, UnitIsUnit(unit, "player") and "(Вы)" or ""))

                local statsFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                statsFS:SetPoint("LEFT", row, "LEFT", 210, 0)
                statsFS:SetText(string.format("Общий RIO: |cffffff00%d|r", h.totalRio))

                local expFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                expFS:SetPoint("RIGHT", row, "RIGHT", -12, 0)
                expFS:SetText(string.format("В этом подземелье: |c%s%s|r", h.expColor, h.expText))

                table.insert(hRowWidgets, row)
                currentY = currentY - 34
            end
        end
    end

    if index == 0 then
        local emptyFS = heuristicsFrame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        emptyFS:SetPoint("CENTER", heuristicsFrame.scrollChild, "CENTER", 0, 0)
        emptyFS:SetText("|cffaaaaaaНет активных заявок в LFG и вы не в группе.\\nОткройте набор в подземелье или вступите в группу.|r")
        table.insert(hRowWidgets, emptyFS)
    end

    heuristicsFrame.scrollChild:SetHeight(math.max(math.abs(currentY) + 30, 400))
end

-- Диагностический пробник M+ API для детального анализа доступности данных
function KAR.RunAPIProbe()
    local db = KeyAutoRecruitDB
    if not db then return end

    local dump = {
        timestamp = (time and time()) or 0,
        date = (date and date("%d.%m.%Y %H:%M:%S")) or "unknown",
        player = UnitName("player") or "unknown",
        zone = GetRealZoneText() or GetZoneText() or "unknown",
        api = {}
    }

    KAR.Log("|cff00ffff=== ДИАГНОСТИЧЕСКИЙ ПРОБНИК M+ API ===|r")

    -- 1. C_ChallengeMode.GetMapTable
    local hasCM = (C_ChallengeMode ~= nil)
    dump.api.hasChallengeMode = hasCM
    if hasCM and C_ChallengeMode.GetMapTable then
        local ok, maps = pcall(C_ChallengeMode.GetMapTable)
        dump.api.mapTable = { ok = ok, count = (ok and maps and #maps) or 0, maps = maps }
        KAR.Log(string.format("C_ChallengeMode.GetMapTable: %s (карт: %d)", ok and "OK" or "FAIL", (ok and maps and #maps) or 0))
    else
        KAR.Log("C_ChallengeMode.GetMapTable: НЕ ПОДДЕРЖИВАЕТСЯ")
    end

    -- 2. C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    local hasPI = (C_PlayerInfo ~= nil and C_PlayerInfo.GetPlayerMythicPlusRatingSummary ~= nil)
    dump.api.hasPlayerRating = hasPI
    if hasPI then
        local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        if ok and summary then
            local runsCount = (summary.runs and #summary.runs) or 0
            dump.api.playerRating = {
                ok = true,
                score = summary.currentSeasonScore or 0,
                runsCount = runsCount,
                runs = summary.runs
            }
            KAR.Log(string.format("Рейтинг игрока: |cffffff00%d RIO|r, закрытых подземелий: |cffffff00%d|r", summary.currentSeasonScore or 0, runsCount))
            if summary.runs and #summary.runs > 0 then
                for i = 1, math.min(#summary.runs, 5) do
                    local r = summary.runs[i]
                    local mName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(r.challengeModeID or r.mapChallengeModeID or 0)) or ("Map #" .. tostring(r.challengeModeID or 0))
                    KAR.Log(string.format("  - %s: |c%s+%d (%s)|r Score: %s", mName, r.finishedSuccess and "ff00ff00" or "ffffff00", r.level or 0, r.finishedSuccess and "Тайм" or "Срыв", tostring(r.mapScore or 0)))
                end
            end
        else
            dump.api.playerRating = { ok = false, error = tostring(summary) }
            KAR.Log(string.format("GetPlayerMythicPlusRatingSummary: %s", tostring(summary)))
        end
    else
        KAR.Log("C_PlayerInfo.GetPlayerMythicPlusRatingSummary: НЕ ПОДДЕРЖИВАЕТСЯ")
    end

    -- 3. C_MythicPlus (Ключ в сумке и история)
    local hasMP = (C_MythicPlus ~= nil)
    dump.api.hasMythicPlus = hasMP
    if hasMP then
        local bagMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local bagLevel = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
        dump.api.bagKeystone = { mapID = bagMapID, level = bagLevel }
        if bagMapID and bagMapID > 0 then
            local kName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(bagMapID)) or ("Карта #" .. tostring(bagMapID))
            KAR.Log(string.format("Ключ в сумке: |cffffff00%s (+%d)|r", kName, bagLevel or 0))
        else
            KAR.Log("Ключ в сумке: отсутствует или нет данных")
        end

        if C_MythicPlus.GetRunHistory then
            local ok, runs = pcall(C_MythicPlus.GetRunHistory, true, true)
            dump.api.runHistory = { ok = ok, count = (ok and runs and #runs) or 0 }
            KAR.Log(string.format("C_MythicPlus.GetRunHistory: забегов найдено: %d", (ok and runs and #runs) or 0))
        end
    end

    -- 4. C_LFGList (Активный сбор и кандидаты)
    if C_LFGList then
        local hasEntry = C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
        if hasEntry then
            local actInfo = hasEntry.activityID and C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(hasEntry.activityID)
            dump.api.lfgEntry = {
                name = hasEntry.name,
                activityID = hasEntry.activityID,
                activityName = actInfo and actInfo.fullName
            }
            KAR.Log(string.format("Сбор в LFG: |cffffff00%s|r (%s)", hasEntry.name or "без имени", (actInfo and actInfo.fullName) or "нет типа"))
        else
            KAR.Log("Сбор в LFG: группа не выставлена в поиск")
        end

        local applicants = C_LFGList.GetApplicants and C_LFGList.GetApplicants()
        local appCount = (applicants and #applicants) or 0
        dump.api.applicantsCount = appCount
        KAR.Log(string.format("Кандидатов в LFG: %d", appCount))

        if applicants and #applicants > 0 then
            local aID = applicants[1]
            local mName, _, _, _, mIlvl, _, _, _, _, _, _, mScore = C_LFGList.GetApplicantMemberInfo(aID, 1)
            local sOk, sInfo = pcall(C_LFGList.GetApplicantDungeonScoreInfo, aID, 1)
            dump.api.sampleApplicant = {
                id = aID,
                name = mName,
                ilvl = mIlvl,
                score = mScore,
                scoreInfoOk = sOk,
                scoreInfo = sInfo
            }
            KAR.Log(string.format("Пример кандидата (%s): RIO=%s, ilvl=%s", tostring(mName), tostring(mScore), tostring(mIlvl)))
            if sOk and sInfo then
                KAR.Log(string.format("  - DungeonScoreInfo: лучший закрытый ключ=+%s, тайм=%s, очки=%s", tostring(sInfo.bestRunLevel), tostring(sInfo.finishedSuccess), tostring(sInfo.mapScore)))
            else
                KAR.Log("  - DungeonScoreInfo: не вернул данные")
            end
        end
    end

    -- 5. Проверка таргета
    if UnitExists("target") then
        local tName = UnitName("target")
        local ok, tSum = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "target")
        dump.api.targetRating = {
            name = tName,
            ok = ok,
            summary = tSum
        }
        if ok and tSum then
            KAR.Log(string.format("Таргет (%s): RIO=%d, забегов=%d", tName, tSum.currentSeasonScore or 0, (tSum.runs and #tSum.runs) or 0))
        else
            KAR.Log(string.format("Таргет (%s): нет данных M+ рейтинга", tName))
        end
    end

    db.lastProbe = dump
    KAR.Log("|cff00ffff=== Данные сохранены в KeyAutoRecruitDB.lastProbe ===|r")
end

-- Слэш-команды эвристики (/kh, /heuristics, /kd)
SLASH_KEYHEURISTICS1 = "/kh"
SLASH_KEYHEURISTICS2 = "/heuristics"
SLASH_KEYHEURISTICS3 = "/kd"

SlashCmdList["KEYHEURISTICS"] = function(msg)
    local raw = msg or ""
    local trimmed = raw:gsub("^%s*(.-)%s*$", "%1"):lower()

    if trimmed == "scan" or trimmed == "check" or trimmed == "probe" or trimmed == "test" or trimmed == "dump" then
        KAR.RunAPIProbe()
    else
        KAR.OpenHeuristicsGUI()
    end
end
