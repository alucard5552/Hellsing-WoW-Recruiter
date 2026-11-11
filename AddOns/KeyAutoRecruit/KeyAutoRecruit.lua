-- KeyAutoRecruit.lua (v2.2)
-- Автономный умный авто-набор со сверхбыстрым чат-мостом для демона

KeyAutoRecruit = {}
local KAR = KeyAutoRecruit

KAR.SecureQueue = KAR.SecureQueue or {}
local secureActionQueue = KAR.SecureQueue

function KAR.GetQueueLength()
    return #secureActionQueue
end
local secureUpdaterFrame = nil
local secureEventFrame = nil
local pixelIndicator = nil

-- Приватный канал связи с внешним Python-демоном
local SYNC_CHANNEL_NAME = "KAR_SYNC_BUS"

local function SendDaemonSyncMessage(msg)
    pcall(function()
        LoggingChat(true)
    end)
    local channelID = GetChannelName(SYNC_CHANNEL_NAME)
    if channelID and channelID > 0 then
        SendChatMessage(msg, "CHANNEL", nil, channelID)
    else
        -- Если канал еще подключается, используем эмоцию
        SendChatMessage("::" .. msg .. "::", "EMOTE")
    end
end

local function InitSecureHardwareBridge()
    pcall(function()
        LoggingChat(true)
    end)
    -- Подключаемся к скрытому каналу связи
    pcall(function()
        JoinChannelByName(SYNC_CHANNEL_NAME, "SecretPass999")
    end)

    -- Полноэкранный оверлей для приема аппаратного события
    secureEventFrame = CreateFrame('Frame', 'KAR_SecureEventFrame', UIParent)
    secureEventFrame:SetPoint('TOPLEFT')
    secureEventFrame:SetPoint('BOTTOMRIGHT')
    secureEventFrame:Hide()

    secureEventFrame:EnableMouse(true)
    secureEventFrame:EnableMouseWheel(true)
    secureEventFrame:SetMouseMotionEnabled(true)
    secureEventFrame:EnableGamePadButton(true)
    secureEventFrame:EnableKeyboard(true)
    secureEventFrame:SetPropagateKeyboardInput(true)

    local function RunNextSecureAction()
        while #secureActionQueue > 0 do
            local action = table.remove(secureActionQueue, 1)
            if action then action() end
        end
        if KAR.SetTriggerColor and not isShowingGroupFullPixel and not KAR.testPixelActive then
            KAR.SetTriggerColor("IDLE")
        end
    end

    secureEventFrame:SetScript("OnMouseDown", RunNextSecureAction)
    secureEventFrame:SetScript("OnMouseUp", RunNextSecureAction)
    secureEventFrame:SetScript("OnKeyDown", RunNextSecureAction)
    secureEventFrame:SetScript("OnKeyUp", RunNextSecureAction)

    -- Увеличенный визуальный пиксельный триггер для чекера (32x32 пикселя)
    -- Прекрасно виден, работает и в полноэкранном, и в оконном режиме
    pixelIndicator = CreateFrame('Frame', 'KAR_PixelTrigger', UIParent)
    pixelIndicator:SetSize(32, 32)
    pixelIndicator:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 4, -4)
    pixelIndicator:SetFrameStrata('TOOLTIP')
    pixelIndicator:SetFrameLevel(UIParent:GetFrameLevel() + 2000)
    pixelIndicator:SetClampedToScreen(true)
    pixelIndicator:SetMovable(true)
    pixelIndicator:EnableMouse(true)
    pixelIndicator:RegisterForDrag('LeftButton')
    pixelIndicator:SetScript('OnDragStart', function(self)
        if KAR.testPixelActive then self:StartMoving() end
    end)
    pixelIndicator:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
    end)

    -- Постоянная оптическая обводка и рамка (Контейнер с гарантированной обводкой)
    -- 1. Черная контрастная основа подложки
    local baseBg = pixelIndicator:CreateTexture(nil, 'BACKGROUND', nil, 0)
    baseBg:SetAllPoints()
    baseBg:SetColorTexture(0, 0, 0, 1.0)

    -- 2. Внешняя яркая оптическая обводка (2px, неоновый Cyan 0.0, 0.85, 1.0)
    local borderThickness = 2
    local bTop = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 6)
    bTop:SetPoint('TOPLEFT', pixelIndicator, 'TOPLEFT', 0, 0)
    bTop:SetPoint('BOTTOMRIGHT', pixelIndicator, 'TOPRIGHT', 0, -borderThickness)
    bTop:SetColorTexture(0.0, 0.85, 1.0, 1.0)

    local bBottom = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 6)
    bBottom:SetPoint('TOPLEFT', pixelIndicator, 'BOTTOMLEFT', 0, borderThickness)
    bBottom:SetPoint('BOTTOMRIGHT', pixelIndicator, 'BOTTOMRIGHT', 0, 0)
    bBottom:SetColorTexture(0.0, 0.85, 1.0, 1.0)

    local bLeft = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 6)
    bLeft:SetPoint('TOPLEFT', pixelIndicator, 'TOPLEFT', 0, 0)
    bLeft:SetPoint('BOTTOMRIGHT', pixelIndicator, 'BOTTOMLEFT', borderThickness, 0)
    bLeft:SetColorTexture(0.0, 0.85, 1.0, 1.0)

    local bRight = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 6)
    bRight:SetPoint('TOPLEFT', pixelIndicator, 'TOPRIGHT', -borderThickness, 0)
    bRight:SetPoint('BOTTOMRIGHT', pixelIndicator, 'BOTTOMRIGHT', 0, 0)
    bRight:SetColorTexture(0.0, 0.85, 1.0, 1.0)

    -- 3. Внутренняя черная разделительная обводка (1px) для контрастности OpenCV
    local sTop = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 5)
    sTop:SetPoint('TOPLEFT', pixelIndicator, 'TOPLEFT', 2, -2)
    sTop:SetPoint('BOTTOMRIGHT', pixelIndicator, 'TOPRIGHT', -2, -3)
    sTop:SetColorTexture(0, 0, 0, 1.0)

    local sBottom = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 5)
    sBottom:SetPoint('TOPLEFT', pixelIndicator, 'BOTTOMLEFT', 2, 3)
    sBottom:SetPoint('BOTTOMRIGHT', pixelIndicator, 'BOTTOMRIGHT', -2, 2)
    sBottom:SetColorTexture(0, 0, 0, 1.0)

    local sLeft = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 5)
    sLeft:SetPoint('TOPLEFT', pixelIndicator, 'TOPLEFT', 2, -2)
    sLeft:SetPoint('BOTTOMRIGHT', pixelIndicator, 'BOTTOMLEFT', 3, 2)
    sLeft:SetColorTexture(0, 0, 0, 1.0)

    local sRight = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 5)
    sRight:SetPoint('TOPLEFT', pixelIndicator, 'TOPRIGHT', -3, -2)
    sRight:SetPoint('BOTTOMRIGHT', pixelIndicator, 'BOTTOMRIGHT', -2, 2)
    sRight:SetColorTexture(0, 0, 0, 1.0)

    -- 4. Текстура оптического контейнера kar_container.tga
    local containerTex = pixelIndicator:CreateTexture(nil, 'OVERLAY', nil, 7)
    containerTex:SetAllPoints()
    pcall(function()
        containerTex:SetTexture([[Interface\AddOns\KeyAutoRecruit\Textures\kar_container.tga]])
    end)
    pixelIndicator.containerTex = containerTex

    -- 5. Динамический центр-пиксель 20x20 (отступ 6px)
    local bg = pixelIndicator:CreateTexture(nil, 'ARTWORK', nil, 1)
    bg:SetPoint('TOPLEFT', pixelIndicator, 'TOPLEFT', 6, -6)
    bg:SetPoint('BOTTOMRIGHT', pixelIndicator, 'BOTTOMRIGHT', -6, 6)
    bg:SetColorTexture(0.05, 0.05, 0.05, 1.0) -- В режиме ожидания: темный нейтральный фон
    pixelIndicator.bg = bg

    -- Контейнер непрерывно отображается в левом верхнем углу (постоянный)
    pixelIndicator:Show()

    local groupFullTimer = nil
    local isShowingGroupFullPixel = false

    KAR.SetTriggerColor = function(colorType)
        if not pixelIndicator or not pixelIndicator.bg then return end
        if colorType == "TANK" or colorType == "ТАНК" then
            -- Яркий голубой RGB(0, 180, 255) для Танка
            pixelIndicator.bg:SetColorTexture(0.0, 0.70, 1.0, 1.0)
        elseif colorType == "HEALER" or colorType == "ХИЛ" then
            -- Сочный неоновый зеленый RGB(0, 255, 0) для Хила
            pixelIndicator.bg:SetColorTexture(0.0, 1.0, 0.0, 1.0)
        elseif colorType == "DAMAGER" or colorType == "DPS" or colorType == "ДД" then
            -- Сочный оранжевый RGB(255, 130, 0) для ДД
            pixelIndicator.bg:SetColorTexture(1.0, 0.50, 0.0, 1.0)
        elseif colorType == "DECLINE" then
            -- Желтый RGB(255, 255, 0) для тихого отклонения
            pixelIndicator.bg:SetColorTexture(1.0, 1.0, 0.0, 1.0)
        elseif colorType == "FULL" then
            -- Пурпурный / Маджента RGB(255, 0, 255) для собранной группы 5/5
            pixelIndicator.bg:SetColorTexture(1.0, 0.0, 1.0, 1.0)
        elseif colorType == "TEST" then
            -- Чистый белый RGB(255, 255, 255) для калибровки F11 / OpenCV
            pixelIndicator.bg:SetColorTexture(1.0, 1.0, 1.0, 1.0)
        elseif colorType == "IDLE" or colorType == "STANDBY" then
            -- Нейтральный фон режима ожидания
            pixelIndicator.bg:SetColorTexture(0.05, 0.05, 0.05, 1.0)
        else
            pixelIndicator.bg:SetColorTexture(0.05, 0.05, 0.05, 1.0)
        end
    end

    KAR.ShowGroupFullPixel = function(duration)
        duration = duration or 2.5
        KAR.SetTriggerColor("FULL")
        isShowingGroupFullPixel = true
        if groupFullTimer then groupFullTimer:Cancel() end
        groupFullTimer = C_Timer.NewTimer(duration, function()
            groupFullTimer = nil
            isShowingGroupFullPixel = false
            if #secureActionQueue == 0 and not KAR.testPixelActive then
                KAR.SetTriggerColor("IDLE")
            end
        end)
    end

    secureUpdaterFrame = CreateFrame('Frame')
    secureUpdaterFrame:SetScript('OnUpdate', function()
        -- Постоянный контейнер всегда активен на экране
        if not pixelIndicator:IsShown() then
            pixelIndicator:Show()
        end
        if #secureActionQueue > 0 then
            secureEventFrame:SetFrameStrata('TOOLTIP')
            secureEventFrame:SetFrameLevel(UIParent:GetFrameLevel() + 1000)
            secureEventFrame:Show()
        elseif isShowingGroupFullPixel then
            secureEventFrame:Hide()
        else
            secureEventFrame:Hide()
            if not KAR.testPixelActive and #secureActionQueue == 0 and not isShowingGroupFullPixel then
                KAR.SetTriggerColor("IDLE")
            end
        end
    end)
end

KAR.testPixelActive = false
KAR.ToggleTestPixel = function(state)
    if state ~= nil then
        KAR.testPixelActive = state
    else
        KAR.testPixelActive = not KAR.testPixelActive
    end
    if pixelIndicator then
        pixelIndicator:Show()
        if KAR.testPixelActive then
            KAR.SetTriggerColor("TEST")
            print("|cff00ff00[KAR]|r Оптический контейнер: Тестовый белый пиксель ВКЛЮЧЕН.")
            print("|cff00ff00[KAR]|r Авто-сканер OpenCV или F11 могут зафиксировать координаты.")
        else
            if #secureActionQueue == 0 and not isShowingGroupFullPixel then
                KAR.SetTriggerColor("IDLE")
            end
            print("|cffff8800[KAR]|r Оптический контейнер: переведен в режим ожидания (IDLE).")
        end
    end
    return KAR.testPixelActive
end

KAR.EnqueueSecureAction = function(fn, roleCode)
    if type(fn) == "function" then
        if roleCode and KAR.SetTriggerColor then
            KAR.SetTriggerColor(roleCode)
        end
        table.insert(secureActionQueue, fn)
        -- Моментально посылаем сигнал демону в лог чата: НАЖМИ F12!
        SendDaemonSyncMessage("KAR_TRIGGER_F12")
    end
end

KAR.TestRoleAnnouncement = function(role)
    local rTitle = (role == "TANK") and "ТАНК" or ((role == "HEALER") and "ХИЛ" or "ДД")
    if KAR.AnnounceCandidateFound then
        KAR.AnnounceCandidateFound(rTitle, "ТестовыйКандидат", "ТестСпек", 615, 2600, true, true)
    end
    KAR.EnqueueSecureAction(function()
        KAR.Log("|cff00ff00[ТЕСТ F12]|r Тестовое действие выполнено успешно!")
    end, role)
end

-- База всех 39 специализаций The War Within
KAR.SPECIALIZATIONS = {
    [71]  = { id = 71,  class = "WARRIOR",     name = "Arms",     role = "DAMAGER", lust = false, brez = false },
    [72]  = { id = 72,  class = "WARRIOR",     name = "Fury",     role = "DAMAGER", lust = false, brez = false },
    [73]  = { id = 73,  class = "WARRIOR",     name = "Prot",     role = "TANK",    lust = false, brez = false },

    [65]  = { id = 65,  class = "PALADIN",     name = "Holy",     role = "HEALER",  lust = false, brez = true },
    [66]  = { id = 66,  class = "PALADIN",     name = "Prot",     role = "TANK",    lust = false, brez = true },
    [70]  = { id = 70,  class = "PALADIN",     name = "Ret",      role = "DAMAGER", lust = false, brez = true },

    [253] = { id = 253, class = "HUNTER",      name = "BM",       role = "DAMAGER", lust = true,  brez = false },
    [254] = { id = 254, class = "HUNTER",      name = "MM",       role = "DAMAGER", lust = true,  brez = false },
    [255] = { id = 255, class = "HUNTER",      name = "Surv",     role = "DAMAGER", lust = true,  brez = false },

    [259] = { id = 259, class = "ROGUE",       name = "Assa",     role = "DAMAGER", lust = false, brez = false },
    [260] = { id = 260, class = "ROGUE",       name = "Outlaw",   role = "DAMAGER", lust = false, brez = false },
    [261] = { id = 261, class = "ROGUE",       name = "Sub",      role = "DAMAGER", lust = false, brez = false },

    [256] = { id = 256, class = "PRIEST",      name = "Disc",     role = "HEALER",  lust = false, brez = false },
    [257] = { id = 257, class = "PRIEST",      name = "Holy",     role = "HEALER",  lust = false, brez = false },
    [258] = { id = 258, class = "PRIEST",      name = "Shadow",   role = "DAMAGER", lust = false, brez = false },

    [250] = { id = 250, class = "DEATHKNIGHT", name = "Blood",    role = "TANK",    lust = false, brez = true },
    [251] = { id = 251, class = "DEATHKNIGHT", name = "Frost",    role = "DAMAGER", lust = false, brez = true },
    [252] = { id = 252, class = "DEATHKNIGHT", name = "Unholy",   role = "DAMAGER", lust = false, brez = true },

    [262] = { id = 262, class = "SHAMAN",      name = "Ele",      role = "DAMAGER", lust = true,  brez = false },
    [263] = { id = 263, class = "SHAMAN",      name = "Enh",      role = "DAMAGER", lust = true,  brez = false },
    [264] = { id = 264, class = "SHAMAN",      name = "Resto",    role = "HEALER",  lust = true,  brez = false },

    [62]  = { id = 62,  class = "MAGE",        name = "Arcane",   role = "DAMAGER", lust = true,  brez = false },
    [63]  = { id = 63,  class = "MAGE",        name = "Fire",     role = "DAMAGER", lust = true,  brez = false },
    [64]  = { id = 64,  class = "MAGE",        name = "Frost",    role = "DAMAGER", lust = true,  brez = false },

    [265] = { id = 265, class = "WARLOCK",     name = "Affli",    role = "DAMAGER", lust = false, brez = true },
    [266] = { id = 266, class = "WARLOCK",     name = "Demo",     role = "DAMAGER", lust = false, brez = true },
    [267] = { id = 267, class = "WARLOCK",     name = "Destro",   role = "DAMAGER", lust = false, brez = true },

    [268] = { id = 268, class = "MONK",        name = "Brew",     role = "TANK",    lust = false, brez = false },
    [269] = { id = 269, class = "MONK",        name = "Mist",     role = "HEALER",  lust = false, brez = false },
    [270] = { id = 270, class = "MONK",        name = "WW",       role = "DAMAGER", lust = false, brez = false },

    [102] = { id = 102, class = "DRUID",       name = "Boomkin",  role = "DAMAGER", lust = false, brez = true },
    [103] = { id = 103, class = "DRUID",       name = "Feral",    role = "DAMAGER", lust = false, brez = true },
    [104] = { id = 104, class = "DRUID",       name = "Bear",     role = "TANK",    lust = false, brez = true },
    [105] = { id = 105, class = "DRUID",       name = "Tree",     role = "HEALER",  lust = false, brez = true },

    [577] = { id = 577, class = "DEMONHUNTER", name = "Havoc",    role = "DAMAGER", lust = false, brez = false },
    [581] = { id = 581, class = "DEMONHUNTER", name = "Veng",     role = "TANK",    lust = false, brez = false },
    [1480] = { id = 1480, class = "DEMONHUNTER", name = "Devourer (Пожиратель)", role = "DAMAGER", lust = false, brez = false },

    [1467]= { id = 1467,class = "EVOKER",      name = "Devast",   role = "DAMAGER", lust = true,  brez = false },
    [1468]= { id = 1468,class = "EVOKER",      name = "Preserv",  role = "HEALER",  lust = true,  brez = false },
    [1473]= { id = 1473,class = "EVOKER",      name = "Augment",  role = "DAMAGER", lust = true,  brez = false },
}

KAR.ORDERED_CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
    "DRUID", "DEMONHUNTER", "EVOKER"
}

KAR.CLASS_SPECS = {}
for specID, info in pairs(KAR.SPECIALIZATIONS) do
    KAR.CLASS_SPECS[info.class] = KAR.CLASS_SPECS[info.class] or {}
    table.insert(KAR.CLASS_SPECS[info.class], specID)
end
KAR.CLASSES = KAR.CLASS_SPECS

KAR.CLASS_COLORS = {
    ["WARRIOR"]     = "C79C6E",
    ["PALADIN"]     = "F58CBA",
    ["HUNTER"]      = "ABD473",
    ["ROGUE"]       = "FFF569",
    ["PRIEST"]      = "FFFFFF",
    ["DEATHKNIGHT"] = "C41F3B",
    ["SHAMAN"]      = "0070DE",
    ["MAGE"]        = "69CCF0",
    ["WARLOCK"]     = "9482C9",
    ["MONK"]        = "00FF96",
    ["DRUID"]       = "FF7D0A",
    ["DEMONHUNTER"] = "A330C9",
    ["EVOKER"]      = "33937F",
}

local defaultDB = {
    enabled = false,
    minRio = 0,
    minIlvl = 200,
    minLust = 1,
    minBrez = 1,
    minDpsBrez = 1,
    autoDecline = true,
    kickWrongSpec = true,
    -- Определение серверных диапазонов и актуального ilvl сезона
    seasonMinIlvl = 200,     -- Актуальный мин. ilvl сезона (свежий 80 ур / нормал)
    seasonMaxIlvl = 730,     -- Актуальный макс. ilvl сезона (топ мифик / бис)
    seasonMinRio  = 0,       -- Актуальный мин. RIO сезона
    seasonMaxRio  = 3000,    -- Актуальный макс. RIO сезона (сильный пушер)
    -- Эвристика совместных заявок
    groupMinScore = 40,      -- Мин. сила группы (0-100%)
    allowOneVagon = true,    -- Разрешить связку, если в ней ровно один вагон
    vagonMaxIlvlDiff = 35,   -- Макс. отставание вагона по ilvl от локомотива
    -- Настройки авто-замены слабых пугов (High-End Replacement)
    upgradeFullGroup = true,     -- Авто-замена более сильным соло кандидатом (включая 4/5 и 5/5)
    upgradeMultiGroup = true,    -- Авто-замена пугов при заявке сыгранной группы (2, 3 или 4 человека)
    upgradeIlvlDiff = 15,        -- Мин. прирост ilvl
    upgradeRioDiff = 250,        -- Мин. прирост RIO для замены (по умолчанию 250)
    protectedRio = 2500,         -- Защита пугов/друзей: если их RIO выше этого порога, не кикать!

    -- Эмуляция человека (задержка перед инвайтом)
    humanDelayEnabled = true,    -- Задержка перед инвайтом
    inviteDelayMin = 4,          -- Мин. задержка (сек)
    inviteDelayMax = 7,          -- Макс. задержка (сек)

    -- Контроль опыта в целевое подземелье (Heuristics Deficit Model)
    dungeonKeyCheckEnabled = true,   -- Фильтр по закрытому ключу в целевой данж
    maxDungeonKeyDeficit = 2,        -- Макс. отставание по уровню ключа (0-10)
    requireDungeonTimed = false,     -- Требовать закрытие исключительно в тайм

    -- Статистика
    stats = {
        totalInvited = 0,
    },

    -- Черный список (Blacklist)
    blacklist = {},

    -- История последних 5 групп
    recentGroups = {},

    -- Сетевой модуль P2P сопряжения и синхронизации ЧС
    p2pAutoAccept = false,        -- Авто-прием рукопожатий (по умолчанию отключен, требует подтверждения)
    autoFriendSync = true,       -- Автоматическое сопряжение и обмен базами при появлении друга
    p2pMutedPlayers = {},        -- Список игроков, для которых выбрано "Не уведомлять" (тихий отказ MUTED)

    specs = {},
    groupDumps = {}
}

for specID, _ in pairs(KAR.SPECIALIZATIONS) do
    defaultDB.specs[specID] = true
end

KAR.Log = function(msg)
    print("|cff00ff00[KAR]|r " .. msg)
end

KAR.IsFriend = function(playerName)
    if not playerName or playerName == "" then return false end

    -- Проверка по GUID (если передан unit GUID)
    if type(playerName) == "string" and playerName:find("^Player%-") then
        if C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(playerName) then
            return true
        end
    end

    local cleanName = string.match(playerName, "([^-]+)") or playerName
    cleanName = cleanName:gsub("%s+", "")
    local cleanLower = string.lower(cleanName)

    -- 1. Локальные друзья персонажа (WoW Friends)
    local numFriends = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or (GetNumFriends and GetNumFriends() or 0)
    for i = 1, numFriends do
        local fInfo = C_FriendList and C_FriendList.GetFriendInfoByIndex and C_FriendList.GetFriendInfoByIndex(i)
        local fName = fInfo and fInfo.name or (GetFriendInfo and GetFriendInfo(i))
        if fName then
            local cleanFName = string.match(fName, "([^-]+)") or fName
            cleanFName = cleanFName:gsub("%s+", "")
            if string.lower(cleanFName) == cleanLower then return true end
        end
    end

    -- 2. Battle.net друзья (BNet Friends)
    local numBNet = BNGetNumFriends and BNGetNumFriends() or 0
    for i = 1, numBNet do
        if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
            local acc = C_BattleNet.GetFriendAccountInfo(i)
            if acc and acc.gameAccountInfo and acc.gameAccountInfo.characterName then
                local bName = string.match(acc.gameAccountInfo.characterName, "([^-]+)") or acc.gameAccountInfo.characterName
                bName = bName:gsub("%s+", "")
                if string.lower(bName) == cleanLower then return true end
            end
        end
        local numAccounts = C_BattleNet and C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendNumGameAccounts(i) or 1
        for a = 1, numAccounts do
            local gameInfo = C_BattleNet and C_BattleNet.GetFriendGameAccountInfo and C_BattleNet.GetFriendGameAccountInfo(i, a)
            if gameInfo and gameInfo.characterName then
                local bName = string.match(gameInfo.characterName, "([^-]+)") or gameInfo.characterName
                bName = bName:gsub("%s+", "")
                if string.lower(bName) == cleanLower then return true end
            end
        end
    end

    -- 3. Согильдийцы (Guild Members) - опционально защищаем
    if IsInGuild and IsInGuild() and GetNumGuildMembers then
        local gCount = GetNumGuildMembers()
        for i = 1, gCount do
            local gName = GetGuildRosterInfo(i)
            if gName then
                local cleanGName = string.match(gName, "([^-]+)") or gName
                cleanGName = cleanGName:gsub("%s+", "")
                if string.lower(cleanGName) == cleanLower then return true end
            end
        end
    end

    return false
end

KAR.InspectedMembers = {}
local soloJoinedMembers = {} -- Отслеживание игроков, которые вступили в одиночку (не связкой)
KAR.ApplicantDataCache = {} -- Кэш точных характеристик (RIO, ilvl, роль, lust, brez) кандидатов из LFG
local pendingInvitedRoles = {} -- Отслеживание ролей приглашенных игроков, ожидающих принятия инвайта
local awaitingInspectGUID = nil
local awaitingInspectUnit = nil
local inspectTimeoutTimer = nil
local hasAnnouncedFull = false

local eventFrame = CreateFrame("Frame", "KeyAutoRecruitCoreFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

local pendingHumanInvites = {} -- [applicantID] = true (отслеживание активных таймеров задержки)
local blacklistAlertDebounce = {} -- [cleanName] = timestamp (анти-спам оповещений ЧС)

local function InitDB()
    if not KeyAutoRecruitDB then
        KeyAutoRecruitDB = CopyTable(defaultDB)
    else
        for k, v in pairs(defaultDB) do
            if KeyAutoRecruitDB[k] == nil then KeyAutoRecruitDB[k] = v end
        end
        if not KeyAutoRecruitDB.specs then KeyAutoRecruitDB.specs = {} end
        for specID, _ in pairs(KAR.SPECIALIZATIONS) do
            if KeyAutoRecruitDB.specs[specID] == nil then
                KeyAutoRecruitDB.specs[specID] = true
            end
        end
    end

    if KeyAutoRecruitDB.humanDelayEnabled == nil then
        KeyAutoRecruitDB.humanDelayEnabled = defaultDB.humanDelayEnabled
    end
    if KeyAutoRecruitDB.inviteDelayMin == nil then
        KeyAutoRecruitDB.inviteDelayMin = defaultDB.inviteDelayMin
    end
    if KeyAutoRecruitDB.inviteDelayMax == nil then
        KeyAutoRecruitDB.inviteDelayMax = defaultDB.inviteDelayMax
    end
    if not KeyAutoRecruitDB.blacklist then
        KeyAutoRecruitDB.blacklist = {}
    end
    if not KeyAutoRecruitDB.recentGroups then
        KeyAutoRecruitDB.recentGroups = {}
    end
    if not KeyAutoRecruitDB.stats then
        KeyAutoRecruitDB.stats = { totalInvited = 0 }
    end

    -- Настройки P2P сопряжения и синхронизации ЧС
    if KeyAutoRecruitDB.p2pAutoAccept == nil then
        KeyAutoRecruitDB.p2pAutoAccept = false
    end
    if KeyAutoRecruitDB.autoFriendSync == nil then
        KeyAutoRecruitDB.autoFriendSync = true
    end
    if not KeyAutoRecruitDB.p2pMutedPlayers then
        KeyAutoRecruitDB.p2pMutedPlayers = {}
    end

    -- Защита от повреждения SavedVariables таблицами вместо boolean
    if type(KeyAutoRecruitDB.dungeonKeyCheckEnabled) ~= "boolean" then
        KeyAutoRecruitDB.dungeonKeyCheckEnabled = (KeyAutoRecruitDB.dungeonKeyCheckEnabled == true)
    end
    if KeyAutoRecruitDB.maxDungeonKeyDeficit == nil then
        KeyAutoRecruitDB.maxDungeonKeyDeficit = defaultDB.maxDungeonKeyDeficit
    end
    if type(KeyAutoRecruitDB.requireDungeonTimed) ~= "boolean" then
        KeyAutoRecruitDB.requireDungeonTimed = (KeyAutoRecruitDB.requireDungeonTimed == true)
    end
    if type(KeyAutoRecruitDB.allowOneVagon) ~= "boolean" then
        KeyAutoRecruitDB.allowOneVagon = (KeyAutoRecruitDB.allowOneVagon == true)
    end

    -- Защита от сбоя: если minIlvl не задан или сбит (< 100)
    local seasonMin = KeyAutoRecruitDB.seasonMinIlvl or defaultDB.seasonMinIlvl or 200
    if not KeyAutoRecruitDB.minIlvl or KeyAutoRecruitDB.minIlvl < 100 then
        KeyAutoRecruitDB.minIlvl = seasonMin
    end

    -- Авто-исправление старых TWW дефолтов (590/600), блокировавших прием на серверах Midnight 12.0.7
    if KeyAutoRecruitDB.seasonMinIlvl and KeyAutoRecruitDB.seasonMinIlvl >= 500 then
        KeyAutoRecruitDB.seasonMinIlvl = 200
    end
    if KeyAutoRecruitDB.minIlvl and KeyAutoRecruitDB.minIlvl >= 590 then
        KeyAutoRecruitDB.minIlvl = 200
    end
    if KeyAutoRecruitDB.thresholds and KeyAutoRecruitDB.thresholds.minItemLevel and KeyAutoRecruitDB.thresholds.minItemLevel >= 590 then
        KeyAutoRecruitDB.thresholds.minItemLevel = 200
    end

    -- Синхронизация структуры options и thresholds
    if not KeyAutoRecruitDB.options then KeyAutoRecruitDB.options = {} end
    if KeyAutoRecruitDB.options.announceToChat == nil then KeyAutoRecruitDB.options.announceToChat = true end
    if KeyAutoRecruitDB.minBrez == nil then KeyAutoRecruitDB.minBrez = defaultDB.minBrez or 1 end
    if KeyAutoRecruitDB.minDpsBrez == nil then KeyAutoRecruitDB.minDpsBrez = defaultDB.minDpsBrez or 1 end
    if KeyAutoRecruitDB.options.requireBrez == nil then KeyAutoRecruitDB.options.requireBrez = (KeyAutoRecruitDB.minBrez and KeyAutoRecruitDB.minBrez > 0) or false end
    if KeyAutoRecruitDB.options.requireDpsBrez == nil then KeyAutoRecruitDB.options.requireDpsBrez = (KeyAutoRecruitDB.minDpsBrez and KeyAutoRecruitDB.minDpsBrez > 0) or false end
    if KeyAutoRecruitDB.options.requireLust == nil then KeyAutoRecruitDB.options.requireLust = (KeyAutoRecruitDB.minLust and KeyAutoRecruitDB.minLust > 0) or false end
    if KeyAutoRecruitDB.options.whisperDeclined == nil then KeyAutoRecruitDB.options.whisperDeclined = KeyAutoRecruitDB.autoDecline or false end

    if not KeyAutoRecruitDB.thresholds then KeyAutoRecruitDB.thresholds = {} end
    if KeyAutoRecruitDB.options.dungeonKeyCheck == nil then KeyAutoRecruitDB.options.dungeonKeyCheck = KeyAutoRecruitDB.dungeonKeyCheckEnabled end
    if KeyAutoRecruitDB.options.requireDungeonTimed == nil then KeyAutoRecruitDB.options.requireDungeonTimed = KeyAutoRecruitDB.requireDungeonTimed end
    if KeyAutoRecruitDB.thresholds.maxKeyDeficit == nil then KeyAutoRecruitDB.thresholds.maxKeyDeficit = KeyAutoRecruitDB.maxDungeonKeyDeficit end
    if not KeyAutoRecruitDB.thresholds.minOverallScore then KeyAutoRecruitDB.thresholds.minOverallScore = KeyAutoRecruitDB.minRio or 0 end
    if not KeyAutoRecruitDB.thresholds.minDungeonScore then KeyAutoRecruitDB.thresholds.minDungeonScore = 0 end
    if not KeyAutoRecruitDB.thresholds.minItemLevel then KeyAutoRecruitDB.thresholds.minItemLevel = KeyAutoRecruitDB.minIlvl or 200 end
end

function KAR.StartRecruiting()
    local db = KeyAutoRecruitDB
    if db then
        db.enabled = true
        db.active = true
    end
    KAR.IsScanning = true
    KAR.Log("Авто-набор активирован.")
    if KAR.ProcessApplicants then
        KAR.ProcessApplicants()
    end
end

function KAR.StopRecruiting()
    local db = KeyAutoRecruitDB
    if db then
        db.enabled = false
        db.active = false
    end
    KAR.IsScanning = false
    KAR.Log("Авто-набор остановлен.")
end

-- -------------------------------------------------------------
-- Подсистема Черного Списка (Blacklist System)
-- -------------------------------------------------------------
function KAR.IsBlacklisted(playerName)
    if not playerName or playerName == "" then return false, nil end
    local cleanName = string.match(playerName, "([^-]+)") or playerName
    cleanName = string.lower(cleanName)

    local db = KeyAutoRecruitDB
    if not db or not db.blacklist then return false, nil end

    for blName, blData in pairs(db.blacklist) do
        local cleanBL = string.match(blName, "([^-]+)") or blName
        if string.lower(cleanBL) == cleanName then
            return true, blData
        end
    end
    return false, nil
end

function KAR.AddToBlacklist(playerName, reason)
    if not playerName or playerName == "" then return end
    local cleanName = string.match(playerName, "([^-]+)") or playerName

    local db = KeyAutoRecruitDB
    if not db then return end
    if not db.blacklist then db.blacklist = {} end

    reason = reason or "Без описания"
    if reason:gsub("%s+", "") == "" then reason = "Без описания" end
    local nowTime = (time and time()) or 0
    local nowDate = (date and date("%d.%m.%Y %H:%M")) or "сегодня"

    db.blacklist[cleanName] = {
        name = cleanName,
        fullName = playerName,
        reason = reason,
        date = nowDate,
        timestamp = nowTime
    }

    KAR.Log(string.format("|cffff2020[ЧЕРНЫЙ СПИСОК]|r Игрок |cffffff00%s|r внесен в ЧС! Причина: |cffffaa00%s|r (%s)", cleanName, reason, nowDate))
    if KAR.RefreshOpenGUIs then KAR.RefreshOpenGUIs() end
end

function KAR.RemoveFromBlacklist(playerName)
    if not playerName or playerName == "" then return end
    local cleanName = string.match(playerName, "([^-]+)") or playerName
    local db = KeyAutoRecruitDB
    if not db or not db.blacklist then return end

    local foundKey = nil
    for k, _ in pairs(db.blacklist) do
        local cKey = string.match(k, "([^-]+)") or k
        if string.lower(cKey) == string.lower(cleanName) then
            foundKey = k
            break
        end
    end

    if foundKey then
        db.blacklist[foundKey] = nil
        KAR.Log(string.format("|cff00ff00[ЧЕРНЫЙ СПИСОК]|r Игрок |cffffff00%s|r удален из черного списка.", cleanName))
    else
        KAR.Log(string.format("Игрок |cffffff00%s|r не найден в черном списке.", cleanName))
    end
    if KAR.RefreshOpenGUIs then KAR.RefreshOpenGUIs() end
end

function KAR.PrintBlacklist()
    local db = KeyAutoRecruitDB
    local bl = db and db.blacklist
    if not bl or next(bl) == nil then
        KAR.Log("|cff00ff00Черный список пуст.|r")
        return
    end

    KAR.Log("|cffff2020=== Черный список KeyAutoRecruit ===|r")
    local count = 0
    for name, data in pairs(bl) do
        count = count + 1
        local r = data.reason or "Без описания"
        local d = data.date or ""
        print(string.format("  %d. |cffffff00%s|r: |cffffaa00%s|r (|cff888888%s|r)", count, name, r, d))
    end
    KAR.Log(string.format("Всего в черном списке: |cffffff00%d|r игроков.", count))
end

function KAR.GetGroupLeaderName()
    if not IsInGroup() then return nil end
    local num = GetNumGroupMembers()
    local isRaid = IsInRaid()
    for i = 1, num do
        local unit = isRaid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        if UnitExists(unit) and UnitIsGroupLeader(unit) then
            local leaderName, leaderRealm = UnitName(unit)
            if leaderRealm and leaderRealm ~= "" then
                return leaderName .. "-" .. leaderRealm
            end
            return leaderName
        end
    end
    return nil
end

function KAR.CheckApplicantsForBlacklist(applicants)
    if not applicants or #applicants == 0 then return end
    local now = GetTime()
    local isLeader = (not IsInGroup()) or (GetNumGroupMembers() <= 1) or UnitIsGroupLeader("player")

    for _, applicantID in ipairs(applicants) do
        local appInfo = C_LFGList.GetApplicantInfo(applicantID)
        if appInfo and appInfo.applicationStatus == "applied" then
            local numApp = appInfo.numMembers or 1
            for mi = 1, numApp do
                local mName = C_LFGList.GetApplicantMemberInfo(applicantID, mi)
                if mName then
                    local isBL, blInfo = KAR.IsBlacklisted(mName)
                    if isBL then
                        local cleanName = string.match(mName, "([^-]+)") or mName
                        local lastAlert = blacklistAlertDebounce[cleanName] or 0
                        if (now - lastAlert) > 30 then
                            blacklistAlertDebounce[cleanName] = now
                            local reason = (blInfo and blInfo.reason) or "ЧС"
                            local blDate = (blInfo and blInfo.date) or ""

                            -- 1. Уведомление в личный чат игрока
                            print(string.format("|cffff2020[KAR Черный список]|r Внимание! Игрок |cffffff00%s|r подал заявку в группу! Причина ЧС: |cffffaa00%s|r (|cff888888%s|r)", cleanName, reason, blDate))

                            -- 2. Звуковой сигнал и баннер на экран
                            pcall(function()
                                if SOUNDKIT and SOUNDKIT.RAID_WARNING then
                                    PlaySound(SOUNDKIT.RAID_WARNING, "Master")
                                else
                                    PlaySound(8959, "Master")
                                end
                            end)
                            FlashClientIcon()
                            if RaidNotice_AddMessage and RaidWarningFrame then
                                RaidNotice_AddMessage(RaidWarningFrame, string.format("|cffff2020[KAR ЧС] Кандидат %s в черном списке: %s|r", cleanName, reason), ChatTypeInfo["RAID_WARNING"])
                            end

                            -- 3. Если пользователь НЕ лидер группы: находим лидера и отправляем ему шепот
                            if not isLeader then
                                local leaderName = KAR.GetGroupLeaderName()
                                local myName = UnitName("player")
                                if leaderName and leaderName ~= "" and leaderName ~= myName then
                                    local whisperMsg = string.format("[KAR] Внимание! Кандидат %s находится у меня в черном списке. Причина: %s", cleanName, reason)
                                    SendChatMessage(whisperMsg, "WHISPER", nil, leaderName)
                                    KAR.Log(string.format("Отправлено предупреждение лидеру (|cffffff00%s|r): %s", leaderName, whisperMsg))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Диалоговое окно для ввода причины ЧС
StaticPopupDialogs["KAR_BLACKLIST_REASON_PROMPT"] = {
    text = "|cffff2020[KeyAutoRecruit]|r Добавление игрока |cffffff00%s|r в черный список.\n\nВведите причину ЧС:",
    button1 = "Добавить в ЧС",
    button2 = "Отмена",
    hasEditBox = true,
    maxLetters = 120,
    editBoxWidth = 260,
    OnShow = function(self, data)
        local eb = self.EditBox or self.editBox or _G[self:GetName() .. "EditBox"]
        if eb then
            eb:SetText("")
            eb:SetFocus()
        end
    end,
    OnAccept = function(self, data)
        local eb = self.EditBox or self.editBox or _G[self:GetName() .. "EditBox"]
        local reason = (eb and eb:GetText()) or "Без описания"
        if reason:gsub("%s+", "") == "" then reason = "Без описания" end
        local pName = data and data.name
        if pName then
            KAR.AddToBlacklist(pName, reason)
        end
    end,
    EditBoxOnEnterPressed = function(self, data)
        local parent = self:GetParent()
        local reason = self:GetText() or "Без описания"
        if reason:gsub("%s+", "") == "" then reason = "Без описания" end
        local pData = parent and parent.data
        local pName = pData and pData.name
        if pName then
            KAR.AddToBlacklist(pName, reason)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["KAR_BLACKLIST_ADD_MANUAL"] = {
    text = "|cffff2020[KeyAutoRecruit]|r Добавление игрока в черный список.\n\nВведите имя персонажа:",
    button1 = "Далее (Причина)",
    button2 = "Отмена",
    hasEditBox = true,
    maxLetters = 60,
    editBoxWidth = 240,
    OnShow = function(self)
        local eb = self.EditBox or self.editBox or _G[self:GetName() .. "EditBox"]
        if eb then eb:SetText(""); eb:SetFocus() end
    end,
    OnAccept = function(self)
        local eb = self.EditBox or self.editBox or _G[self:GetName() .. "EditBox"]
        local name = eb and eb:GetText() or ""
        name = name:gsub("%s+", "")
        if name ~= "" then
            C_Timer.After(0.1, function()
                StaticPopup_Show("KAR_BLACKLIST_REASON_PROMPT", name, nil, { name = name })
            end)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = self:GetText() or ""
        name = name:gsub("%s+", "")
        if name ~= "" then
            C_Timer.After(0.1, function()
                StaticPopup_Show("KAR_BLACKLIST_REASON_PROMPT", name, nil, { name = name })
            end)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["KAR_BLACKLIST_EDIT_REASON"] = {
    text = "|cffff2020[KeyAutoRecruit]|r Изменение причины ЧС для игрока |cffffff00%s|r:\n\nВведите новую причину:",
    button1 = "Сохранить",
    button2 = "Отмена",
    hasEditBox = true,
    maxLetters = 120,
    editBoxWidth = 260,
    OnShow = function(self, data)
        local eb = self.EditBox or self.editBox or _G[self:GetName() .. "EditBox"]
        if eb then
            local currentReason = data and data.reason or ""
            eb:SetText(currentReason)
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    OnAccept = function(self, data)
        local eb = self.EditBox or self.editBox or _G[self:GetName() .. "EditBox"]
        local reason = eb and eb:GetText() or "Без описания"
        if reason:gsub("%s+", "") == "" then reason = "Без описания" end
        if data and data.name then
            KAR.AddToBlacklist(data.name, reason)
        end
    end,
    EditBoxOnEnterPressed = function(self, data)
        local parent = self:GetParent()
        local reason = self:GetText() or "Без описания"
        if reason:gsub("%s+", "") == "" then reason = "Без описания" end
        local pData = parent and parent.data
        if pData and pData.name then
            KAR.AddToBlacklist(pData.name, reason)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Диалог подтверждения рукопожатия (P2P сопряжение)
StaticPopupDialogs["KAR_HANDSHAKE_REQUEST"] = {
    text = "|cff00ffcc[KeyAutoRecruit]|r\nИгрок |cffffff00%s|r запрашивает рукопожатие для сопряжения баз ЧС.\n\nПринять сопряжение?",
    button1 = "Принять",
    button2 = "Отклонить",
    button3 = "Не уведомлять",
    OnAccept = function(self, data)
        if KAR.Comm and KAR.Comm.AcceptHandshake then
            KAR.Comm.AcceptHandshake(data)
        end
    end,
    OnCancel = function(self, data)
        if KAR.Comm and KAR.Comm.DeclineHandshake then
            KAR.Comm.DeclineHandshake(data, "DECLINED_MANUAL")
        end
    end,
    OnAlt = function(self, data)
        if KAR.Comm and KAR.Comm.MuteAndDeclineHandshake then
            KAR.Comm.MuteAndDeclineHandshake(data)
        end
    end,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- =============================================================
-- МОДУЛЬ JSON: PURE-LUA КОДЕР И ДЕКОДЕР ДЛЯ WOW
-- =============================================================
KAR.JSON = {}

function KAR.JSON.Encode(val, pretty, indent)
    indent = indent or ""
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        local s = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
        return '"' .. s .. '"'
    elseif t == "table" then
        local isArray = true
        local maxIndex = 0
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) == "number" and k > 0 and math.floor(k) == k then
                if k > maxIndex then maxIndex = k end
            else
                isArray = false
            end
        end
        if count == 0 then return "{}" end
        if isArray and maxIndex == count then
            local items = {}
            local nextIndent = pretty and (indent .. "  ") or ""
            for i = 1, count do
                local s = KAR.JSON.Encode(val[i], pretty, nextIndent)
                table.insert(items, (pretty and nextIndent or "") .. s)
            end
            if pretty then
                return "[\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "]"
            else
                return "[" .. table.concat(items, ",") .. "]"
            end
        else
            local items = {}
            local nextIndent = pretty and (indent .. "  ") or ""
            local keys = {}
            for k in pairs(val) do table.insert(keys, tostring(k)) end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = val[k]
                local encodedKey = '"' .. tostring(k):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
                local encodedVal = KAR.JSON.Encode(v, pretty, nextIndent)
                table.insert(items, (pretty and nextIndent or "") .. encodedKey .. ": " .. encodedVal)
            end
            if pretty then
                return "{\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "}"
            else
                return "{" .. table.concat(items, ",") .. "}"
            end
        end
    else
        return '"' .. tostring(val) .. '"'
    end
end

function KAR.JSON.Decode(str)
    if not str or type(str) ~= "string" then return nil, "Invalid input" end
    local pos = 1
    local len = #str

    local function skipWhitespace()
        while pos <= len do
            local b = str:byte(pos)
            if b == 32 or b == 9 or b == 10 or b == 13 then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parseValue

    local function parseString()
        pos = pos + 1
        local chars = {}
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(chars)
            elseif c == '\\' then
                pos = pos + 1
                local esc = str:sub(pos, pos)
                if esc == '"' then table.insert(chars, '"')
                elseif esc == '\\' then table.insert(chars, '\\')
                elseif esc == '/' then table.insert(chars, '/')
                elseif esc == 'b' then table.insert(chars, '\b')
                elseif esc == 'f' then table.insert(chars, '\f')
                elseif esc == 'n' then table.insert(chars, '\n')
                elseif esc == 'r' then table.insert(chars, '\r')
                elseif esc == 't' then table.insert(chars, '\t')
                elseif esc == 'u' then
                    local hex = str:sub(pos + 1, pos + 4)
                    pos = pos + 4
                    local code = tonumber(hex, 16)
                    if code then
                        if code < 128 then
                            table.insert(chars, string.char(code))
                        elseif code < 2048 then
                            table.insert(chars, string.char(192 + math.floor(code / 64), 128 + (code % 64)))
                        else
                            table.insert(chars, string.char(224 + math.floor(code / 4096), 128 + (math.floor(code / 64) % 64), 128 + (code % 64)))
                        end
                    end
                else
                    table.insert(chars, esc)
                end
                pos = pos + 1
            else
                table.insert(chars, c)
                pos = pos + 1
            end
        end
        return table.concat(chars)
    end

    local function parseNumber()
        local startPos = pos
        if str:sub(pos, pos) == '-' then pos = pos + 1 end
        while pos <= len do
            local b = str:byte(pos)
            if (b >= 48 and b <= 57) or b == 46 or b == 101 or b == 69 or b == 43 or b == 45 then
                pos = pos + 1
            else
                break
            end
        end
        local numStr = str:sub(startPos, pos - 1)
        return tonumber(numStr) or 0
    end

    local function parseArray()
        pos = pos + 1
        local arr = {}
        skipWhitespace()
        if pos <= len and str:sub(pos, pos) == ']' then
            pos = pos + 1
            return arr
        end
        while pos <= len do
            local val = parseValue()
            table.insert(arr, val)
            skipWhitespace()
            local c = str:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            elseif c == ',' then
                pos = pos + 1
                skipWhitespace()
            else
                pos = pos + 1
                return arr
            end
        end
        return arr
    end

    local function parseObject()
        pos = pos + 1
        local obj = {}
        skipWhitespace()
        if pos <= len and str:sub(pos, pos) == '}' then
            pos = pos + 1
            return obj
        end
        while pos <= len do
            skipWhitespace()
            if str:sub(pos, pos) ~= '"' then break end
            local key = parseString()
            skipWhitespace()
            if str:sub(pos, pos) == ':' then pos = pos + 1 end
            local val = parseValue()
            obj[key] = val
            skipWhitespace()
            local c = str:sub(pos, pos)
            if c == '}' then
                pos = pos + 1
                return obj
            elseif c == ',' then
                pos = pos + 1
                skipWhitespace()
            else
                pos = pos + 1
                return obj
            end
        end
        return obj
    end

    parseValue = function()
        skipWhitespace()
        if pos > len then return nil end
        local c = str:sub(pos, pos)
        if c == '"' then
            return parseString()
        elseif c == '{' then
            return parseObject()
        elseif c == '[' then
            return parseArray()
        elseif c == 't' and str:sub(pos, pos + 3) == 'true' then
            pos = pos + 4
            return true
        elseif c == 'f' and str:sub(pos, pos + 4) == 'false' then
            pos = pos + 5
            return false
        elseif c == 'n' and str:sub(pos, pos + 3) == 'null' then
            pos = pos + 4
            return nil
        else
            return parseNumber()
        end
    end

    return parseValue()
end

-- =============================================================
-- МОДУЛЬ СОПРЯЖЕНИЯ И РУКОПОЖАТИЯ КЛИЕНТОВ (P2P COMM)
-- =============================================================
KAR.Comm = {
    state = "IDLE", -- "IDLE", "WAIT_ACK", "PAIRED", "TRANSFERRING"
    partner = nil,
    sessionID = nil,
    incoming = nil,
    hsStartTime = 0,
    txCount = 0,
    rxCount = 0,
    logHistory = {},
    blockedPartners = {},
    autoSyncFriend = nil,
    reqFlag = "MANUAL",
}

KAR.FriendSyncCooldowns = {}

local function GetFormattedCommTime()
    local s = (date and date("%H:%M:%S")) or "00:00:00"
    local ms = math.floor(((GetTime and GetTime() or 0) % 1) * 1000)
    return string.format("%s.%03d", s, ms)
end

function KAR.Comm.AddLog(dir, text, bytes)
    local tStamp = GetFormattedCommTime()
    local tag = ""
    if dir == "TX" then
        tag = "|cff00ccff[TX]|r"
    elseif dir == "RX" then
        tag = "|cff00ff7f[RX]|r"
    elseif dir == "HEUR" then
        tag = "|cffffcc00[ЭВРИСТИКА]|r"
    elseif dir == "STATE" then
        tag = "|cffb366ff[СТАТУС]|r"
    elseif dir == "ERROR" then
        tag = "|cffff3333[ОШИБКА]|r"
    else
        tag = "|cffffffff[ИНФО]|r"
    end

    local entry = string.format("[%s] %s %s", tStamp, tag, text)
    table.insert(KAR.Comm.logHistory, entry)
    if #KAR.Comm.logHistory > 200 then
        table.remove(KAR.Comm.logHistory, 1)
    end

    if KAR.UpdateTelemetryLog then
        KAR.UpdateTelemetryLog()
    end
end

local COMM_PREFIX = "KAR_SYNC"

local function SendCommPacket(msg, target)
    if not target or target == "" then return false end
    local byteLen = #msg
    local mtuStatus = (byteLen <= 255) and string.format("|cff00ff00[MTU OK: %db/255b]|r", byteLen) or string.format("|cffff0000[MTU DROP: %db > 255b]|r", byteLen)

    local sendFunc = (C_ChatInfo and (C_ChatInfo.SendAddonMessage or C_ChatInfo.SendAddOnMessage))
                     or SendAddonMessage or SendAddOnMessage
    if sendFunc then
        local ok, res = pcall(sendFunc, COMM_PREFIX, msg, "WHISPER", target)
        local resCode = tonumber(res)
        local isSuccess = ok and (resCode == nil or resCode == 0 or res == true)
        if isSuccess then
            KAR.Comm.txCount = KAR.Comm.txCount + 1
            KAR.Comm.AddLog("TX", string.format("-> %s | %s | %s", target, msg, mtuStatus), byteLen)
            if KAR.UpdatePasteStatus then KAR.UpdatePasteStatus() end
            return true
        else
            local errDetail = not ok and tostring(res) or string.format("Код Blizzard: %s", tostring(res))
            KAR.Comm.AddLog("ERROR", string.format("Сбой отправки на %s! (%s)", target, errDetail), byteLen)
            return false
        end
    end
    return false
end

function KAR.Comm.RequestHandshake(targetName, reqFlag)
    if not targetName or targetName:gsub("%s+", "") == "" then
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus("|cffff3333Введите имя напарника для сопряжения!|r")
        end
        return
    end

    local cleanTarget = string.match(targetName, "([^-]+)") or targetName
    cleanTarget = cleanTarget:gsub("%s+", "")
    local myName = UnitName("player") or ""
    if cleanTarget:lower() == myName:lower() then
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus("|cffff3333Нельзя сопрягаться с самим собой!|r")
        end
        return
    end

    local cTargetLower = cleanTarget:lower()
    if KAR.Comm.blockedPartners and KAR.Comm.blockedPartners[cTargetLower] then
        local unblockTime = KAR.Comm.blockedPartners[cTargetLower]
        local now = GetTime()
        if now < unblockTime then
            local remainSec = math.ceil(unblockTime - now)
            local msg = string.format("Запросы к %s заблокированы (напарник отклонил запрос, осталось %d с).", cleanTarget, remainSec)
            if KAR.UpdatePasteStatus then
                KAR.UpdatePasteStatus("|cffff3333" .. msg .. "|r")
            end
            KAR.Comm.AddLog("ERROR", msg, 0)
            return
        else
            KAR.Comm.blockedPartners[cTargetLower] = nil
        end
    end

    reqFlag = reqFlag or "MANUAL"
    local sessID = tostring(math.random(100000, 999999))
    KAR.Comm.state = "WAIT_ACK"
    KAR.Comm.partner = cleanTarget
    KAR.Comm.sessionID = sessID
    KAR.Comm.hsStartTime = GetTime()
    KAR.Comm.reqFlag = reqFlag

    local pkt = string.format("HS_REQ:%s:2.2:%s:%s", sessID, myName, reqFlag)
    KAR.Comm.AddLog("STATE", string.format("Инициализация рукопожатия с |cffffff00%s|r [Флаг: %s] (Сессия: #%s)...", cleanTarget, reqFlag, sessID), #pkt)
    SendCommPacket(pkt, cleanTarget)

    if KAR.UpdatePasteStatus then
        KAR.UpdatePasteStatus(string.format("|cffffff00Ожидание ответа рукопожатия от %s (%s)...|r", cleanTarget, reqFlag))
    end
    KAR.Log(string.format("|cff00ffff[ЧС Сопряжение]|r Запрос рукопожатия [%s] отправлен игроку |cffffff00%s|r...", reqFlag, cleanTarget))

    C_Timer.After(25, function()
        if KAR.Comm.state == "WAIT_ACK" and KAR.Comm.partner == cleanTarget then
            KAR.Comm.state = "IDLE"
            KAR.Comm.partner = nil
            if KAR.UpdatePasteStatus then
                KAR.UpdatePasteStatus("|cffff3333Таймаут: напарник не ответил на рукопожатие.|r")
            end
        end
    end)
end

function KAR.Comm.AcceptHandshake(senderData)
    local cleanSender = senderData.sender
    local sessID = senderData.sessID
    local myName = UnitName("player") or ""

    KAR.Comm.state = "PAIRED"
    KAR.Comm.partner = cleanSender
    KAR.Comm.sessionID = sessID

    local pkt = string.format("HS_ACK:%s:2.2:%s", sessID, myName)
    SendCommPacket(pkt, cleanSender)

    if KAR.UpdatePasteStatus then
        KAR.UpdatePasteStatus(string.format("|cff00ff00● Сопряжено с: %s|r", cleanSender))
    end
    KAR.Log(string.format("|cff00ff00[ЧС Сопряжение]|r Рукопожатие принято! Вы успешно сопряжены с |cffffff00%s|r.", cleanSender))
    if KAR.RefreshOpenGUIs then KAR.RefreshOpenGUIs() end
end

function KAR.Comm.DeclineHandshake(senderData, reason)
    local cleanSender = senderData.sender
    local sessID = senderData.sessID or "0"
    reason = reason or "DECLINED_MANUAL"
    SendCommPacket("HS_REJ:" .. sessID .. ":" .. reason, cleanSender)
    KAR.Comm.AddLog("STATE", string.format("Рукопожатие с %s отклонено (Причина: %s).", cleanSender, reason), 0)
    KAR.Log(string.format("|cffffaa00[ЧС Сопряжение]|r Рукопожатие с %s отклонено.", cleanSender))
end

function KAR.Comm.MuteAndDeclineHandshake(senderData)
    local cleanSender = senderData.sender
    local sessID = senderData.sessID or "0"
    if KeyAutoRecruitDB then
        if not KeyAutoRecruitDB.p2pMutedPlayers then KeyAutoRecruitDB.p2pMutedPlayers = {} end
        KeyAutoRecruitDB.p2pMutedPlayers[cleanSender:lower()] = true
    end
    SendCommPacket("HS_REJ:" .. sessID .. ":MUTED", cleanSender)
    KAR.Comm.AddLog("STATE", string.format("Игрок %s заблокирован ('Не уведомлять'). Отправлен HS_REJ:MUTED.", cleanSender), 0)
    KAR.Log(string.format("|cffff5555[ЧС Сопряжение]|r Игрок |cffffff00%s|r добавлен в список 'Не уведомлять'. Запросы от него заблокированы.", cleanSender))
end

function KAR.CheckAndSyncFriendUnit(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end
    if UnitIsUnit(unit, "player") then return end

    local db = KeyAutoRecruitDB
    if db and db.autoFriendSync == false then return end

    if UnitIsVisible and not UnitIsVisible(unit) then return end

    local rawName = UnitName(unit)
    if not rawName or rawName == "" or rawName == UNKNOWN then return end
    local cleanName = string.match(rawName, "([^-]+)") or rawName
    cleanName = cleanName:gsub("%s+", "")
    if cleanName == "" then return end

    local myName = UnitName("player") or ""
    if cleanName:lower() == myName:lower() then return end

    local guid = UnitGUID(unit)
    local isFriend = false
    if KAR.IsFriend then
        isFriend = KAR.IsFriend(cleanName) or (guid and KAR.IsFriend(guid))
    end
    if not isFriend then return end

    local now = GetTime()
    local cKey = cleanName:lower()
    local lastSync = KAR.FriendSyncCooldowns[cKey] or 0
    if (now - lastSync) < 300 then
        return
    end

    if KAR.Comm and KAR.Comm.state == "TRANSFERRING" then
        return
    end

    KAR.FriendSyncCooldowns[cKey] = now
    KAR.Comm.autoSyncFriend = cleanName

    KAR.Comm.AddLog("HEUR", string.format("Обнаружен друг |cffffff00%s|r рядом! Инициализация автоматической синхронизации ЧС...", cleanName), 0)
    KAR.Log(string.format("|cff00ffcc[P2P Друзья]|r Друг |cffffff00%s|r замечен рядом! Запуск автоматического сопряжения и синхронизации ЧС...", cleanName))
    PlaySound(84)

    KAR.Comm.RequestHandshake(cleanName, "AUTO_FRIEND")
end

function KAR.Comm.Disconnect()
    if KAR.Comm.partner then
        SendCommPacket("DISC:" .. (KAR.Comm.sessionID or "0"), KAR.Comm.partner)
        KAR.Log(string.format("|cffaaaaaa[ЧС Сопряжение]|r Сопряжение с %s разорвано.", KAR.Comm.partner))
    end
    KAR.Comm.state = "IDLE"
    KAR.Comm.partner = nil
    KAR.Comm.sessionID = nil
    if KAR.UpdatePasteStatus then
        KAR.UpdatePasteStatus("|cffaaaaaa● Состояние: Не сопряжено|r")
    end
end

function KAR.Comm.SendPing()
    if not KAR.Comm.partner or KAR.Comm.state ~= "PAIRED" then
        KAR.Comm.AddLog("ERROR", "Пинг невозможен: сначала выполните сопряжение (PAIRED)!", 0)
        return
    end
    local nowMs = math.floor(GetTime() * 1000)
    local pkt = string.format("PING:%s:%d", KAR.Comm.sessionID or "0", nowMs)
    KAR.Comm.AddLog("TX", string.format("Отправлен PING напарнику %s...", KAR.Comm.partner), #pkt)
    SendCommPacket(pkt, KAR.Comm.partner)
end

function KAR.Comm.SendDatabaseToPartner()
    if KAR.Comm.state ~= "PAIRED" or not KAR.Comm.partner then
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus("|cffff3333Ошибка: Сначала выполните сопряжение (рукопожатие)!|r")
        end
        return
    end

    local db = KeyAutoRecruitDB
    local bl = db and db.blacklist
    if not bl or next(bl) == nil then
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus("|cffffcc00База ЧС пуста! Нечего отправлять.|r")
        end
        return
    end

    local list = {}
    for name, data in pairs(bl) do
        table.insert(list, {
            data.name or name,
            data.reason or "Без описания",
            data.date or "сегодня",
            data.timestamp or 0
        })
    end

    local payloadTable = {
        type = "KAR_BL_SYNC",
        v = 1,
        sender = UnitName("player") or "Unknown",
        count = #list,
        items = list
    }

    local jsonStr = KAR.JSON.Encode(payloadTable, false)
    local chunkSize = 160
    local len = #jsonStr
    local totalChunks = math.ceil(len / chunkSize)
    local sessID = KAR.Comm.sessionID or tostring(math.random(100000, 999999))
    local partner = KAR.Comm.partner

    KAR.Comm.state = "TRANSFERRING"
    if KAR.UpdatePasteStatus then
        KAR.UpdatePasteStatus(string.format("|cff00ccffОтправка базы ЧС (%d записей, %d пакетов)...|r", #list, totalChunks))
    end

    SendCommPacket(string.format("DATA_START:%s:%d:%d", sessID, totalChunks, len), partner)

    for i = 1, totalChunks do
        local startIdx = (i - 1) * chunkSize + 1
        local endIdx = math.min(i * chunkSize, len)
        local chunkData = jsonStr:sub(startIdx, endIdx)

        C_Timer.After((i - 1) * 0.04, function()
            local pkt = string.format("DATA_CHUNK:%s:%d:%d:%s", sessID, i, totalChunks, chunkData)
            SendCommPacket(pkt, partner)

            if KAR.UpdatePasteStatus then
                local pct = math.floor((i / totalChunks) * 100)
                KAR.UpdatePasteStatus(string.format("|cff00ccffОтправка напарнику: %d%% (%d/%d)...|r", pct, i, totalChunks))
            end

            if i == totalChunks then
                C_Timer.After(0.05, function()
                    SendCommPacket(string.format("DATA_END:%s:%d", sessID, totalChunks), partner)
                    KAR.Comm.state = "PAIRED"
                    if KAR.UpdatePasteStatus then
                        KAR.UpdatePasteStatus(string.format("|cff00ff00Пакеты отправлены! Ожидание подтверждения от %s...|r", partner))
                    end
                end)
            end
        end)
    end
end

function KAR.Comm.RequestDatabaseFromPartner()
    if KAR.Comm.state ~= "PAIRED" or not KAR.Comm.partner then
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus("|cffff3333Ошибка: Сначала выполните сопряжение (рукопожатие)!|r")
        end
        return
    end

    local sessID = KAR.Comm.sessionID or "0"
    SendCommPacket("REQ_DB:" .. sessID, KAR.Comm.partner)
    if KAR.UpdatePasteStatus then
        KAR.UpdatePasteStatus(string.format("|cff00ccffЗапрос базы отправлен напарнику %s...|r", KAR.Comm.partner))
    end
    KAR.Log(string.format("|cff00ffff[ЧС Сопряжение]|r Запрос базы ЧС отправлен игроку |cffffff00%s|r...", KAR.Comm.partner))
end

function KAR.OnCommMessage(msg, channel, sender)
    if not msg or msg == "" then return end
    local cleanSender = string.match(sender, "([^-]+)") or sender
    local myName = UnitName("player") or ""
    if cleanSender:lower() == myName:lower() then return end

    local byteLen = #msg
    KAR.Comm.rxCount = KAR.Comm.rxCount + 1
    KAR.Comm.AddLog("RX", string.format("<- %s | %s (%db)", cleanSender, msg, byteLen), byteLen)
    if KAR.UpdatePasteStatus then KAR.UpdatePasteStatus() end

    local cmd, rest = msg:match("^([^:]+):?(.*)$")
    if not cmd then return end

    if cmd == "HS_REQ" then
        local parts = {}
        for p in string.gmatch(rest or "", "([^:]+)") do table.insert(parts, p) end
        local sessID = parts[1] or "0"
        local ver = parts[2] or "2.2"
        local senderName = parts[3] or cleanSender
        local reqFlag = parts[4] or "MANUAL"
        local displayName = (senderName and senderName ~= "") and senderName or cleanSender

        KAR.Comm.AddLog("HEUR", string.format("Входящий запрос рукопожатия от |cffffff00%s|r [Флаг: %s] (v%s, Сессия #%s)", displayName, reqFlag, ver, sessID), byteLen)

        -- 1. Проверка списка "Не уведомлять" (тихий отказ с кодом MUTED)
        local sLower = cleanSender:lower()
        if KeyAutoRecruitDB and KeyAutoRecruitDB.p2pMutedPlayers and KeyAutoRecruitDB.p2pMutedPlayers[sLower] then
            SendCommPacket("HS_REJ:" .. sessID .. ":MUTED", cleanSender)
            KAR.Comm.AddLog("HEUR", string.format("Запрос от %s проигнорирован (в списке 'Не уведомлять'). Отправлен MUTED.", cleanSender), byteLen)
            return
        end

        -- 2. Проверка боевого режима: если игрок в бою, отклоняем с кодом BUSY, чтобы не отвлекать от ключа/босса
        if InCombatLockdown and InCombatLockdown() then
            SendCommPacket("HS_REJ:" .. sessID .. ":BUSY", cleanSender)
            KAR.Comm.AddLog("STATE", string.format("Запрос от %s отклонен автоматически (вы в бою, отправлен BUSY).", displayName), byteLen)
            return
        end

        -- 3. Встречный одновременный запрос (Simultaneous Handshake Resolution)
        if KAR.Comm.state == "WAIT_ACK" and KAR.Comm.partner and KAR.Comm.partner:lower() == sLower then
            KAR.Comm.AddLog("HEUR", string.format("Встречный запрос от %s разрешен (одновременное сопряжение)!", cleanSender), byteLen)
            KAR.Comm.AcceptHandshake({ sender = cleanSender, sessID = sessID })
            return
        end

        -- 4. Проверка друга
        local isFriend = (KAR.IsFriend and (KAR.IsFriend(cleanSender) or KAR.IsFriend(displayName))) or false
        local autoFriendSyncEnabled = (KeyAutoRecruitDB and KeyAutoRecruitDB.autoFriendSync ~= false)
        local autoAcceptManual = (KeyAutoRecruitDB and KeyAutoRecruitDB.p2pAutoAccept == true)

        if isFriend and autoFriendSyncEnabled then
            -- Рукопожатие от друга: АВТО-ПРИЕМ и взаимная синхронизация без всплывающих окон
            KAR.Comm.autoSyncFriend = cleanSender
            KAR.Comm.AddLog("HEUR", string.format("Авто-прием от ДРУГА |cffffff00%s|r! Мгновенное сопряжение и запуск синхронизации...", displayName), byteLen)
            C_Timer.After(0.1, function()
                KAR.Comm.AcceptHandshake({ sender = cleanSender, sessID = sessID })
            end)
        elseif autoAcceptManual then
            -- Ручной режим авто-приема (если пользователь включил галочку в UI)
            KAR.Comm.AddLog("STATE", string.format("АВТО-ПРИЕМ рукопожатия: мгновенный ответ напарнику %s...", displayName), byteLen)
            C_Timer.After(0.1, function()
                KAR.Comm.AcceptHandshake({ sender = cleanSender, sessID = sessID })
            end)
        else
            -- БЕЗ АВТО-ПРИНЯТИЯ: спрашиваем пользователя через диалог с кнопкой "Не уведомлять"
            StaticPopup_Show("KAR_HANDSHAKE_REQUEST", displayName, nil, {
                sender = cleanSender,
                sessID = sessID
            })
            KAR.Comm.AddLog("STATE", string.format("Ожидание ручного подтверждения рукопожатия от %s...", displayName), byteLen)
            KAR.Log(string.format("|cffffff00[ЧС Сопряжение]|r Игрок |cff00ff00%s|r запрашивает рукопожатие. Подтвердите в диалоге!", displayName))
            PlaySound(8959)
        end

    elseif cmd == "HS_ACK" then
        local parts = {}
        for p in string.gmatch(rest or "", "([^:]+)") do table.insert(parts, p) end
        local sessID = parts[1] or "0"
        local ver = parts[2] or "2.2"
        local partnerName = parts[3] or cleanSender
        local rtt = (KAR.Comm.hsStartTime > 0) and math.floor((GetTime() - KAR.Comm.hsStartTime) * 1000) or 0
        KAR.Comm.state = "PAIRED"
        KAR.Comm.partner = cleanSender
        KAR.Comm.sessionID = sessID
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus(string.format("|cff00ff00● Сопряжено с: %s|r", cleanSender))
        end
        KAR.Comm.AddLog("HEUR", string.format("РУКОПОЖАТИЕ УСПЕШНО! Сопряжено с: |cffffff00%s|r (RTT рукопожатия: %d мс, v%s)", cleanSender, rtt, ver or "2.2"), byteLen)
        KAR.Log(string.format("|cff00ff00[ЧС Сопряжение]|r Рукопожатие успешно! Вы сопряжены с |cffffff00%s|r (RTT: %d мс).", cleanSender, rtt))
        PlaySound(888)
        if KAR.RefreshOpenGUIs then KAR.RefreshOpenGUIs() end

        -- Если сопряжение произошло с другом в рамках авто-синхронизации:
        if KAR.Comm.autoSyncFriend and KAR.Comm.autoSyncFriend:lower() == cleanSender:lower() then
            KAR.Comm.AddLog("HEUR", string.format("Авто-синхронизация с другом |cffffff00%s|r: запуск обмена базами...", cleanSender), byteLen)
            C_Timer.After(0.3, function()
                KAR.Comm.SendDatabaseToPartner()
                C_Timer.After(0.5, function()
                    KAR.Comm.RequestDatabaseFromPartner()
                end)
            end)
        end

    elseif cmd == "HS_REJ" then
        local sessID, reason = rest:match("^([^:]+):?(.*)$")
        reason = (reason and reason ~= "") and reason or "DECLINED"
        KAR.Comm.state = "IDLE"
        KAR.Comm.partner = nil

        local reasonDesc = "Отклонено напарником"
        local blockDuration = 60
        if reason == "MUTED" then
            reasonDesc = "Заблокировано ('Не уведомлять'). Повторные запросы отключены на 1 час"
            blockDuration = 3600
        elseif reason == "DECLINED_MANUAL" then
            reasonDesc = "Отклонено вручную пользователем"
            blockDuration = 900
        elseif reason == "BUSY" then
            reasonDesc = "Напарник занят передачей данных"
            blockDuration = 30
        end

        if not KAR.Comm.blockedPartners then KAR.Comm.blockedPartners = {} end
        KAR.Comm.blockedPartners[cleanSender:lower()] = GetTime() + blockDuration

        KAR.Comm.AddLog("ERROR", string.format("ОТКАЗ от %s! Причина: %s.", cleanSender, reasonDesc), byteLen)
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus(string.format("|cffff3333Отказ от %s: %s.|r", cleanSender, reasonDesc))
        end
        KAR.Log(string.format("|cffff3333[ЧС Сопряжение]|r Игрок %s отклонил сопряжение (%s).", cleanSender, reasonDesc))

    elseif cmd == "DISC" then
        KAR.Comm.state = "IDLE"
        KAR.Comm.partner = nil
        KAR.Comm.sessionID = nil
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus("|cffaaaaaa● Состояние: Не сопряжено (напарник отключился)|r")
        end
        KAR.Log(string.format("|cffaaaaaa[ЧС Сопряжение]|r Напарник %s разорвал сопряжение.", cleanSender))

    elseif cmd == "PING" then
        local sessID, clientMs = rest:match("^([^:]+):?([^:]*)$")
        local pkt = string.format("PONG:%s:%s", sessID or "0", clientMs or "0")
        SendCommPacket(pkt, cleanSender)
        KAR.Log(string.format("|cff00ccff[ЧС Сопряжение]|r Пинг получен от %s. Отправлен PONG.", cleanSender))

    elseif cmd == "PONG" then
        local sessID, clientMs = rest:match("^([^:]+):?([^:]*)$")
        local nowMs = math.floor(GetTime() * 1000)
        local startMs = tonumber(clientMs) or nowMs
        local rtt = math.max(0, nowMs - startMs)
        KAR.Log(string.format("|cff00ff00[ЧС Сопряжение]|r PONG от %s получен! RTT: %d мс.", cleanSender, rtt))

    elseif cmd == "REQ_DB" then
        if KAR.Comm.partner and KAR.Comm.partner:lower() == cleanSender:lower() then
            KAR.Log(string.format("|cff00ffff[ЧС Сопряжение]|r Напарник %s запросил базу ЧС. Отправка...|r", cleanSender))
            KAR.Comm.SendDatabaseToPartner()
        end

    elseif cmd == "DATA_START" then
        local sessID, totalChunks, totalBytes = rest:match("^([^:]+):([^:]+):([^:]+)$")
        KAR.Comm.incoming = {
            sessID = sessID,
            totalChunks = tonumber(totalChunks) or 1,
            totalBytes = tonumber(totalBytes) or 0,
            chunks = {},
            countReceived = 0,
            sender = cleanSender
        }
        KAR.Comm.state = "TRANSFERRING"
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus(string.format("|cff00ccffПрием базы ЧС от %s: 0%%...|r", cleanSender))
        end

    elseif cmd == "DATA_CHUNK" then
        local sessID, chunkNum, totalChunks, chunkPayload = rest:match("^([^:]+):([^:]+):([^:]+):(.*)$")
        chunkNum = tonumber(chunkNum)
        totalChunks = tonumber(totalChunks)
        if KAR.Comm.incoming and chunkNum and chunkPayload then
            KAR.Comm.incoming.chunks[chunkNum] = chunkPayload
            KAR.Comm.incoming.countReceived = KAR.Comm.incoming.countReceived + 1
            if KAR.UpdatePasteStatus then
                local pct = math.floor((KAR.Comm.incoming.countReceived / (KAR.Comm.incoming.totalChunks or totalChunks or 1)) * 100)
                KAR.UpdatePasteStatus(string.format("|cff00ccffПрием от %s: %d%% (%d/%d)...|r", cleanSender, pct, KAR.Comm.incoming.countReceived, totalChunks or 1))
            end
        end

    elseif cmd == "DATA_END" then
        local sessID, totalChunks = rest:match("^([^:]+):?(.*)$")
        if KAR.Comm.incoming and KAR.Comm.incoming.chunks then
            local fullJSON = table.concat(KAR.Comm.incoming.chunks, "")
            KAR.Comm.incoming = nil
            KAR.Comm.state = "PAIRED"

            local ok, parsed = pcall(KAR.JSON.Decode, fullJSON)
            if ok and parsed and parsed.items then
                local db = KeyAutoRecruitDB
                if not db then return end
                if not db.blacklist then db.blacklist = {} end

                local nowTime = (time and time()) or 0
                local nowDate = (date and date("%d.%m.%Y %H:%M")) or "сегодня"
                local added = 0
                local updated = 0

                for _, item in ipairs(parsed.items) do
                    local pName = item[1]
                    local pReason = item[2]
                    local pDate = item[3]
                    local pTimestamp = item[4]

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

                local totalNow = 0
                for _ in pairs(db.blacklist) do totalNow = totalNow + 1 end

                SendCommPacket(string.format("SYNC_ACK:%s:%d:%d:%d", sessID or "0", added, updated, totalNow), cleanSender)

                if KAR.UpdatePasteStatus then
                    KAR.UpdatePasteStatus(string.format("|cff00ff00Синхронизация успешна! Получено: %d (новых: %d, перезаписано: %d). Всего: %d.|r", added + updated, added, updated, totalNow))
                end
                KAR.Log(string.format("|cff00ff00[ЧС Сопряжение]|r База обновлена от %s! Добавлено: %d, перезаписано: %d. Всего в ЧС: %d игроков.", cleanSender, added, updated, totalNow))

                if KAR.RefreshOpenGUIs then KAR.RefreshOpenGUIs() end
            else
                if KAR.UpdatePasteStatus then
                    KAR.UpdatePasteStatus("|cffff3333Ошибка декодирования полученных данных JSON!|r")
                end
            end
        end

    elseif cmd == "SYNC_ACK" then
        local sessID, added, updated, total = rest:match("^([^:]+):([^:]+):([^:]+):?(.*)$")
        if KAR.UpdatePasteStatus then
            KAR.UpdatePasteStatus(string.format("|cff00ff00Напарник %s успешно принял базу! (+%s новых, %s перезаписано).|r", cleanSender, added or "0", updated or "0"))
        end
        KAR.Log(string.format("|cff00ff00[ЧС Сопряжение]|r Напарник %s успешно применил базу ЧС (+%s новых, %s перезаписано).", cleanSender, added or "0", updated or "0"))
    end
end

-- Инициализация контекстного меню для добавления/удаления игроков из ЧС
local function InitBlacklistContextMenu()
    -- 1. Modern WoW 11.x / Midnight 12.0.7 Context Menu API (Menu.ModifyMenu)
    if Menu and Menu.ModifyMenu then
        local function BlacklistMenuGenerator(owner, rootDescription, contextData)
            local unit = contextData and contextData.unit
            local name = contextData and contextData.name
            if unit and UnitExists(unit) then
                name = UnitName(unit)
            end
            if not name and UIDROPDOWNMENU_INIT_MENU then
                name = UIDROPDOWNMENU_INIT_MENU.name or (UIDROPDOWNMENU_INIT_MENU.unit and UnitName(UIDROPDOWNMENU_INIT_MENU.unit))
            end
            if not name and UnitExists("target") then
                name = UnitName("target")
            end
            if not name or name == "" then return end

            local cleanName = string.match(name, "([^-]+)") or name
            local isBL, blInfo = KAR.IsBlacklisted(cleanName)

            rootDescription:CreateDivider()
            if isBL then
                rootDescription:CreateButton("|cff00ff00[KAR] Удалить из ЧС|r", function()
                    KAR.RemoveFromBlacklist(name)
                end)
            else
                rootDescription:CreateButton("|cffff2020[KAR] В черный список|r", function()
                    StaticPopup_Show("KAR_BLACKLIST_REASON_PROMPT", name, nil, { name = name })
                end)
            end
        end

        local menuTags = {
            "MENU_UNIT_PLAYER",
            "MENU_UNIT_TARGET",
            "MENU_UNIT_PARTY",
            "MENU_UNIT_RAID",
            "MENU_UNIT_FOCUS",
            "MENU_UNIT_ENEMY_PLAYER",
            "MENU_UNIT_FRIEND",
            "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
            "MENU_UNIT_COMMUNITIES_MEMBER",
            "MENU_LFG_FRAME_SEARCH_ENTRY",
            "MENU_LFG_FRAME_MEMBER_APPLY",
        }
        for _, tag in ipairs(menuTags) do
            pcall(Menu.ModifyMenu, tag, BlacklistMenuGenerator)
        end
    end

    -- 2. Fallback для UnitPopupMenus
    if UnitPopupButtons then
        UnitPopupButtons["KAR_BLACKLIST_ADD"] = {
            text = "|cffff2020[KAR] В черный список|r",
            dist = 0,
        }
        UnitPopupButtons["KAR_BLACKLIST_REMOVE"] = {
            text = "|cff00ff00[KAR] Удалить из ЧС|r",
            dist = 0,
        }

        local popupLists = {
            "PLAYER", "TARGET", "PARTY", "RAID", "RAID_PLAYER", "FRIEND", "BN_FRIEND", "COMMUNITIES_GUILD_MEMBER"
        }
        for _, listKey in ipairs(popupLists) do
            if UnitPopupMenus and UnitPopupMenus[listKey] then
                table.insert(UnitPopupMenus[listKey], "KAR_BLACKLIST_ADD")
                table.insert(UnitPopupMenus[listKey], "KAR_BLACKLIST_REMOVE")
            end
        end

        if hooksecurefunc then
            pcall(hooksecurefunc, "UnitPopup_ShowMenu", function(dropdownMenu, which, unit, name, userData)
                local targetName = name or (unit and UnitName(unit)) or (UIDROPDOWNMENU_INIT_MENU and UIDROPDOWNMENU_INIT_MENU.name)
                if not targetName and UnitExists("target") then targetName = UnitName("target") end
                if not targetName then return end

                local isBL = KAR.IsBlacklisted(targetName)
                local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
                for i = 1, maxButtons do
                    local btn = _G["DropDownList1Button" .. i]
                    if btn and btn:IsShown() then
                        if btn.value == "KAR_BLACKLIST_ADD" then
                            btn:SetShown(not isBL)
                        elseif btn.value == "KAR_BLACKLIST_REMOVE" then
                            btn:SetShown(isBL)
                        end
                    end
                end
            end)

            pcall(hooksecurefunc, "UnitPopup_OnClick", function(self)
                local btnValue = self.value
                if btnValue == "KAR_BLACKLIST_ADD" or btnValue == "KAR_BLACKLIST_REMOVE" then
                    local dropdown = UIDROPDOWNMENU_INIT_MENU
                    local name = dropdown and (dropdown.name or (dropdown.unit and UnitName(dropdown.unit)))
                    if not name and UnitExists("target") then name = UnitName("target") end
                    if not name then return end

                    if btnValue == "KAR_BLACKLIST_ADD" then
                        StaticPopup_Show("KAR_BLACKLIST_REASON_PROMPT", name, nil, { name = name })
                    elseif btnValue == "KAR_BLACKLIST_REMOVE" then
                        KAR.RemoveFromBlacklist(name)
                    end
                end
            end)
        end
    end
end

function KAR.GetEffectiveMinIlvl()
    local db = KeyAutoRecruitDB
    if not db then return 200 end

    local userMinIlvl = tonumber(db.minIlvl) or 0
    local seasonMinIlvl = tonumber(db.seasonMinIlvl or db.serverMinIlvl) or 200

    -- Если minIlvl сбит или меньше 100 - берем базовый минимум сезона
    local effective = (userMinIlvl >= 100) and userMinIlvl or seasonMinIlvl

    -- Синхронизация с системным поиском групп Blizzard (если лидер выставил планку ilvl при создании группы)
    if C_LFGList and C_LFGList.GetActiveEntryInfo then
        local ok, entryInfo = pcall(C_LFGList.GetActiveEntryInfo)
        if ok and entryInfo and entryInfo.requiredItemLevel and entryInfo.requiredItemLevel > 0 then
            if entryInfo.requiredItemLevel > effective then
                effective = entryInfo.requiredItemLevel
            end
        end
    end

    return effective
end

KAR.GetGroupStatus = function()
    local numMembers = GetNumGroupMembers()
    local numTanks, numHealers, numDps = 0, 0, 0
    local hasLustCount = 0
    local hasBrezCount = 0
    local dpsBrezCount = 0
    local dpsLustCount = 0

    local isRaid = IsInRaid()
    local count = numMembers > 0 and numMembers or 1

    for i = 1, count do
        local unit = (numMembers == 0) and "player" or (isRaid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1))))
        if UnitExists(unit) then
            local _, classTag = UnitClass(unit)
            local role = UnitGroupRolesAssigned(unit)
            local guid = UnitGUID(unit)

            if UnitIsUnit(unit, "player") then
                local currentSpecIndex = GetSpecialization and GetSpecialization()
                if currentSpecIndex then
                    local id, name, desc, icon, specRole = GetSpecializationInfo(currentSpecIndex)
                    if specRole and specRole ~= "NONE" then role = specRole end
                end
            else            local inspected = guid and KAR.InspectedMembers[guid]
            local uName = UnitName(unit)
            local cleanUName = uName and (string.match(uName, "([^-]+)") or uName)
            local cached = cleanUName and KAR.ApplicantDataCache and KAR.ApplicantDataCache[cleanUName]
            if inspected and inspected.role then
                role = inspected.role
            elseif cached and cached.role then
                role = cached.role
            end
            end

            local unitHasLust = false
            local unitHasBrez = false            local inspected = guid and KAR.InspectedMembers[guid]
            local uName = UnitName(unit)
            local cleanUName = uName and (string.match(uName, "([^-]+)") or uName)
            local cached = cleanUName and KAR.ApplicantDataCache and KAR.ApplicantDataCache[cleanUName]
            if inspected then
                if inspected.lust then unitHasLust = true end
                if inspected.brez then unitHasBrez = true end
            elseif cached then
                if cached.lust then unitHasLust = true end
                if cached.brez then unitHasBrez = true end
            else
                if classTag and (classTag == "SHAMAN" or classTag == "MAGE" or classTag == "HUNTER" or classTag == "EVOKER") then
                    unitHasLust = true
                end
                if classTag and (classTag == "DRUID" or classTag == "DEATHKNIGHT" or classTag == "WARLOCK" or classTag == "PALADIN") then
                    unitHasBrez = true
                end
            end

            if unitHasLust then hasLustCount = hasLustCount + 1 end
            if unitHasBrez then hasBrezCount = hasBrezCount + 1 end

            if role == "TANK" then
                numTanks = numTanks + 1
            elseif role == "HEALER" then
                numHealers = numHealers + 1
            elseif role == "DAMAGER" then
                numDps = numDps + 1
                if unitHasLust then dpsLustCount = dpsLustCount + 1 end
                if unitHasBrez then dpsBrezCount = dpsBrezCount + 1 end
            end
        end
    end

    local pendingCount = 0
    local pendingLust = 0
    local pendingBrez = 0
    local pendingDpsLust = 0
    local pendingDpsBrez = 0
    pendingInvitedRoles = pendingInvitedRoles or {}
    for appID, pRoles in pairs(pendingInvitedRoles) do
        local aInfo = C_LFGList.GetApplicantInfo(appID)
        if aInfo and aInfo.applicationStatus == "invited" then
            numTanks = numTanks + (pRoles.tanks or 0)
            numHealers = numHealers + (pRoles.healers or 0)
            numDps = numDps + (pRoles.dps or 0)
            pendingCount = pendingCount + (aInfo.numMembers or 1)
            if pRoles.lust then pendingLust = pendingLust + pRoles.lust end
            if pRoles.brez then pendingBrez = pendingBrez + pRoles.brez end
            if pRoles.dpsLust then pendingDpsLust = pendingDpsLust + pRoles.dpsLust end
            if pRoles.dpsBrez then pendingDpsBrez = pendingDpsBrez + pRoles.dpsBrez end
        else
            pendingInvitedRoles[appID] = nil
        end
    end

    local totalInParty = (numMembers == 0) and 1 or numMembers
    local openSlots = math.max(0, 5 - totalInParty - pendingCount)

    return {
        total = totalInParty,
        pending = pendingCount,
        openSlots = openSlots,
        tanks = numTanks,
        healers = numHealers,
        dps = numDps,
        needTank = (numTanks < 1),
        needHealer = (numHealers < 1),
        needDps = (numDps < 3),
        lust = hasLustCount + pendingLust,
        brez = hasBrezCount + pendingBrez,
        dpsLust = dpsLustCount + pendingDpsLust,
        dpsBrez = dpsBrezCount + pendingDpsBrez,
    }
end

-- -------------------------------------------------------------
-- Сбор и сохранение истории последних 5 групп
-- -------------------------------------------------------------
function KAR.CaptureCurrentGroupSnapshot()
    local num = GetNumGroupMembers()
    local db = KeyAutoRecruitDB
    if not db then return end
    if not db.recentGroups then db.recentGroups = {} end

    if num <= 1 then
        for _, g in ipairs(db.recentGroups) do
            g.active = false
        end
        return
    end

    local isRaid = IsInRaid()
    local count = math.min(num, 5)

    local members = {}
    local namesKey = {}

    for i = 1, count do
        local unit = (i == 1 and "player") or ("party" .. (i - 1))
        if isRaid then unit = "raid" .. i end
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            if name and name ~= "" then
                local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
                local cleanName = string.match(fullName, "([^-]+)") or fullName
                local _, classToken = UnitClass(unit)
                local role = UnitGroupRolesAssigned(unit)
                if not role or role == "NONE" then
                    role = "DAMAGER"
                end

                local guid = UnitGUID(unit)
                local inspected = guid and KAR.InspectedMembers[guid]
                local cached = KAR.ApplicantDataCache[cleanName]

                local specName = (inspected and inspected.specName) or (cached and cached.specName) or ""
                local ilvl = (inspected and inspected.ilvl) or (cached and cached.ilvl) or 0
                local rio = (inspected and inspected.rio) or (cached and cached.rio) or 0

                table.insert(members, {
                    name = fullName,
                    cleanName = cleanName,
                    class = classToken or "WARRIOR",
                    role = role,
                    spec = specName,
                    ilvl = math.floor(ilvl or 0),
                    rio = math.floor(rio or 0),
                    isPlayer = UnitIsUnit(unit, "player"),
                })

                if not UnitIsUnit(unit, "player") then
                    table.insert(namesKey, cleanName:lower())
                end
            end
        end
    end

    if #namesKey == 0 then return end
    table.sort(namesKey)
    local groupSig = table.concat(namesKey, ":")

    local dungeonName = GetRealZoneText() or GetZoneText() or "Подземелье"
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local ok, val1, val2 = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if ok then
            local kLevel = nil
            if type(val1) == "number" and val1 > 0 then
                kLevel = val1
            elseif type(val2) == "number" and val2 > 0 then
                kLevel = val2
            elseif type(val1) == "table" then
                kLevel = tonumber(val1.activeKeystoneLevel or val1.level or val1.keystoneLevel)
            elseif type(val2) == "table" then
                kLevel = tonumber(val2.activeKeystoneLevel or val2.level or val2.keystoneLevel)
            end
            if kLevel and kLevel > 0 then
                dungeonName = string.format("%s (+%d)", dungeonName, kLevel)
            end
        end
    end

    local nowTime = (time and time()) or 0
    local nowDate = (date and date("%d.%m.%Y %H:%M")) or "сегодня"

    local topGroup = db.recentGroups[1]
    if topGroup and topGroup.sig == groupSig then
        topGroup.members = members
        topGroup.dungeon = dungeonName
        topGroup.lastSeen = nowTime
        topGroup.active = true
    else
        local isExpansion = false
        if topGroup and (nowTime - (topGroup.lastSeen or topGroup.timestamp or 0)) < 900 then
            local overlap = 0
            for _, nk in ipairs(namesKey) do
                if string.find(topGroup.sig or "", nk) then
                    overlap = overlap + 1
                end
            end
            if overlap >= math.min(#namesKey, topGroup.numOtherMembers or 1) then
                isExpansion = true
            end
        end

        if isExpansion and topGroup then
            topGroup.sig = groupSig
            topGroup.members = members
            topGroup.dungeon = dungeonName
            topGroup.numOtherMembers = #namesKey
            topGroup.lastSeen = nowTime
            topGroup.active = true
        else
            for _, g in ipairs(db.recentGroups) do
                g.active = false
            end
            local newEntry = {
                sig = groupSig,
                timestamp = nowTime,
                lastSeen = nowTime,
                date = nowDate,
                dungeon = dungeonName,
                numOtherMembers = #namesKey,
                members = members,
                active = true,
            }
            table.insert(db.recentGroups, 1, newEntry)
            while #db.recentGroups > 5 do
                table.remove(db.recentGroups)
            end
        end
    end

    if KAR.RefreshOpenGUIs then
        KAR.RefreshOpenGUIs()
    end
end

-- Оценка и выполнение замены 1v1 для более сильного соло-кандидата
-- Применяется когда группа 5/5, или когда группа 4/5 и слоты роли кандидата заняты
KAR.EvaluateSoloReplacement = function(applicantID, name, class, candRole, itemLevel, dungeonScore, candHasLust, candHasBrez, party, db)
    if not UnitIsGroupLeader("player") or not db.upgradeFullGroup then
        return false, "Замена отключена или не лидер"
    end

    local effectiveMinIlvl = KAR.GetEffectiveMinIlvl()
    if itemLevel < effectiveMinIlvl then
        return false, string.format("ilvl %d < %d (мин. порог)", math.floor(itemLevel), effectiveMinIlvl)
    end
    if dungeonScore < (db.minRio or 0) then
        return false, string.format("RIO %d < %d (мин. порог)", math.floor(dungeonScore), db.minRio or 0)
    end

    local protectedRio = db.protectedRio or 2500
    local weakestUnit = nil
    local weakestName = nil
    local weakestIlvl = 9999
    local weakestRio = 9999
    local weakestHasLust = false
    local weakestHasBrez = false

    local count = GetNumGroupMembers()
    for idx = 1, count do
        local u = (idx == 1) and "player" or ("party" .. (idx - 1))
        if UnitExists(u) and not UnitIsUnit(u, "player") then
            local uName = UnitName(u)
            local uGuid = UnitGUID(u)
            local cleanUName = uName and (string.match(uName, "([^-]+)") or uName)
            local insp = uGuid and KAR.InspectedMembers[uGuid]
            local cached = cleanUName and KAR.ApplicantDataCache and KAR.ApplicantDataCache[cleanUName]

            -- Защита друзей, согильдейцев и BNet друзей
            if not KAR.IsFriend(uName) then
                local uRole = UnitGroupRolesAssigned(u)
                if insp and insp.role then uRole = insp.role
                elseif cached and cached.role then uRole = cached.role end

                if uRole == candRole then
                    local uIlvl = (insp and insp.ilvl) or (cached and cached.ilvl) or 0
                    local uRio = (insp and insp.rio) or (cached and cached.rio) or 0
                    local isProtected = (protectedRio > 0 and uRio >= protectedRio)

                    if not isProtected then
                        if uRio < weakestRio or (uRio == weakestRio and uIlvl < weakestIlvl) then
                            weakestUnit = u
                            weakestName = uName
                            weakestIlvl = uIlvl
                            weakestRio = uRio
                            weakestHasLust = (insp and insp.lust) or (cached and cached.lust) or false
                            weakestHasBrez = (insp and insp.brez) or (cached and cached.brez) or false
                        end
                    end
                end
            end
        end
    end

    if weakestUnit and weakestName and weakestRio < 9999 then
        local minRioDiff = db.upgradeRioDiff or 250
        local rioGain = dungeonScore - weakestRio
        local ilvlGain = itemLevel - weakestIlvl

        -- Кандидат должен дать прирост RIO и не уступать по ilvl
        if rioGain >= minRioDiff and itemLevel >= (weakestIlvl - 2) then
            -- Проверка Героизма и БРа
            local lustAfter = party.lust - (weakestHasLust and 1 or 0) + (candHasLust and 1 or 0)
            local brezAfter = party.brez - (weakestHasBrez and 1 or 0) + (candHasBrez and 1 or 0)
            local weakestIsDpsBrez = (weakestRole == "DAMAGER" and weakestHasBrez)
            local candIsDpsBrez = (candRole == "DAMAGER" and candHasBrez)
            local dpsBrezAfter = party.dpsBrez - (weakestIsDpsBrez and 1 or 0) + (candIsDpsBrez and 1 or 0)

            local targetMinBrez = (db.options and db.options.requireBrez == false) and 0 or (db.minBrez or 1)
            local targetMinDpsBrez = (db.options and db.options.requireDpsBrez == false) and 0 or (db.minDpsBrez or 0)
            local targetMinLust = (db.options and db.options.requireLust == false) and 0 or (db.minLust or 1)

            if lustAfter >= targetMinLust and brezAfter >= targetMinBrez and dpsBrezAfter >= targetMinDpsBrez then
                KAR.Log(string.format("|cff00ffff[Авто-Замена 1v1]|r Кикаем %s (%d RIO, %d ilvl, %s) -> Принимаем топ %s (%d RIO, %d ilvl, +%d RIO)",
                    weakestName, weakestRio, weakestIlvl, candRole, name or "Кандидат", math.floor(dungeonScore), math.floor(itemLevel), math.floor(rioGain)
                ))
                KAR.EnqueueSecureAction(function()
                    UninviteUnit(weakestName)
                end)
                return true, "OK (Замена)", {
                    tanks = (candRole == "TANK") and 1 or 0,
                    healers = (candRole == "HEALER") and 1 or 0,
                    dps = (candRole == "DAMAGER") and 1 or 0,
                    lust = candHasLust and 1 or 0,
                    brez = candHasBrez and 1 or 0,
                    dpsLust = (candRole == "DAMAGER" and candHasLust) and 1 or 0,
                    dpsBrez = (candRole == "DAMAGER" and candHasBrez) and 1 or 0,
                }
            else
                return false, "Замена нарушит требование по Героизму/БРу"
            end
        else
            return false, string.format("Прирост недостаточен (+%d < +%d RIO)", math.floor(rioGain), minRioDiff)
        end
    end

    return false, "Нет заменяемых игроков этой роли"
end

-- Оценка пользы и выполнение замены для входящей группы из 2, 3 или 4 игроков
KAR.EvaluateGroupReplacement = function(applicantID, memberDataList, party, db)
    if not UnitIsGroupLeader("player") or (db.upgradeMultiGroup == false) or (db.upgradeFullGroup == false) then
        return false, "Групповая замена отключена или не лидер"
    end

    local numIncoming = #memberDataList
    if numIncoming < 2 or numIncoming > 4 then
        return false, "Неподходящий размер группы (только 2-4 чел)"
    end

    -- 1. Считаем роли и характеристики входящей группы
    local inTanks, inHealers, inDps = 0, 0, 0
    local inLust, inBrez = 0, 0
    local inTotalRio, inTotalIlvl = 0, 0
    for _, m in ipairs(memberDataList) do
        if m.role == "TANK" then inTanks = inTanks + 1
        elseif m.role == "HEALER" then inHealers = inHealers + 1
        elseif m.role == "DAMAGER" then inDps = inDps + 1 end
        if m.lust then inLust = inLust + 1 end
        if m.brez then inBrez = inBrez + 1 end
        inTotalRio = inTotalRio + (m.rio or 0)
        inTotalIlvl = inTotalIlvl + (m.ilvl or 0)
    end

    if inTanks > 1 or inHealers > 1 or inDps > 3 then
        return false, "Некорректный состав входящей группы"
    end

    local inAvgRio = inTotalRio / numIncoming
    local inAvgIlvl = inTotalIlvl / numIncoming

    -- 2. Сбор заменяемых пугов в текущей группе
    local protectedRio = db.protectedRio or 2500
    local replaceablePugs = {}
    local count = GetNumGroupMembers()
    for idx = 1, count do
        local u = (idx == 1) and "player" or ("party" .. (idx - 1))
        if UnitExists(u) and not UnitIsUnit(u, "player") then
            local uName = UnitName(u)
            local uGuid = UnitGUID(u)
            local cleanUName = uName and (string.match(uName, "([^-]+)") or uName)
            local insp = uGuid and KAR.InspectedMembers[uGuid]
            local cached = cleanUName and KAR.ApplicantDataCache and KAR.ApplicantDataCache[cleanUName]

            if not KAR.IsFriend(uName) then
                local uRole = UnitGroupRolesAssigned(u)
                if insp and insp.role then uRole = insp.role
                elseif cached and cached.role then uRole = cached.role end

                local uRio = (insp and insp.rio) or (cached and cached.rio) or 0
                local uIlvl = (insp and insp.ilvl) or (cached and cached.ilvl) or 0
                local uLust = (insp and insp.lust) or (cached and cached.lust) or false
                local uBrez = (insp and insp.brez) or (cached and cached.brez) or false

                local isProtected = (protectedRio > 0 and uRio >= protectedRio)
                if not isProtected then
                    table.insert(replaceablePugs, {
                        unit = u,
                        name = uName,
                        guid = uGuid,
                        role = uRole,
                        rio = uRio,
                        ilvl = uIlvl,
                        lust = uLust,
                        brez = uBrez
                    })
                end
            end
        end
    end

    -- 3. Вычисление необходимых слотов и ролевых переполнений
    local neededSlotsToFree = math.max(0, numIncoming - party.openSlots)
    local tanksOver = math.max(0, (party.tanks + inTanks) - 1)
    local healersOver = math.max(0, (party.healers + inHealers) - 1)
    local dpsOver = math.max(0, (party.dps + inDps) - 3)

    -- Проверка: если переполнение по танку/хилу, можно ли заменить текущего пуга
    if tanksOver > 0 then
        local foundTank = false
        for _, p in ipairs(replaceablePugs) do
            if p.role == "TANK" then foundTank = true break end
        end
        if not foundTank then return false, "Невозможно заменить танка (лидер или друг)" end
    end

    if healersOver > 0 then
        local foundHealer = false
        for _, p in ipairs(replaceablePugs) do
            if p.role == "HEALER" then foundHealer = true break end
        end
        if not foundHealer then return false, "Невозможно заменить хила (лидер или друг)" end
    end

    if dpsOver > 0 then
        local dpsCount = 0
        for _, p in ipairs(replaceablePugs) do
            if p.role == "DAMAGER" then dpsCount = dpsCount + 1 end
        end
        if dpsCount < dpsOver then return false, "Недостаточно заменяемых ДД" end
    end

    local minMandatoryKicks = tanksOver + healersOver + dpsOver
    local totalKicksNeeded = math.max(neededSlotsToFree, minMandatoryKicks)

    if totalKicksNeeded <= 0 then
        return false, "Места уже есть"
    end

    if #replaceablePugs < totalKicksNeeded then
        return false, string.format("Недостаточно заменяемых пугов (%d < %d)", #replaceablePugs, totalKicksNeeded)
    end

    -- 4. Выбор заменяемых игроков (слабейшие по RIO и ilvl)
    table.sort(replaceablePugs, function(a, b)
        if a.rio == b.rio then return (a.ilvl or 0) < (b.ilvl or 0) end
        return (a.rio or 0) < (b.rio or 0)
    end)

    local toReplace = {}
    local remainingPugs = {}
    local remTanks = tanksOver
    local remHealers = healersOver
    local remDps = dpsOver

    for _, p in ipairs(replaceablePugs) do
        local chosen = false
        if p.role == "TANK" and remTanks > 0 then
            table.insert(toReplace, p)
            remTanks = remTanks - 1
            chosen = true
        elseif p.role == "HEALER" and remHealers > 0 then
            table.insert(toReplace, p)
            remHealers = remHealers - 1
            chosen = true
        elseif p.role == "DAMAGER" and remDps > 0 then
            table.insert(toReplace, p)
            remDps = remDps - 1
            chosen = true
        end
        if not chosen then
            table.insert(remainingPugs, p)
        end
    end

    while #toReplace < totalKicksNeeded and #remainingPugs > 0 do
        local p = table.remove(remainingPugs, 1)
        table.insert(toReplace, p)
    end

    if #toReplace < totalKicksNeeded then
        return false, "Не удалось сформировать состав замены"
    end

    -- 5. Проверка Героизма и БРа
    local replacedLust = 0
    local replacedBrez = 0
    local replacedDpsBrez = 0
    local replacedTotalRio = 0
    local replacedTotalIlvl = 0
    local replacedNames = {}
    for _, p in ipairs(toReplace) do
        if p.lust then replacedLust = replacedLust + 1 end
        if p.brez then replacedBrez = replacedBrez + 1 end
        if p.role == "DAMAGER" and p.brez then replacedDpsBrez = replacedDpsBrez + 1 end
        replacedTotalRio = replacedTotalRio + (p.rio or 0)
        replacedTotalIlvl = replacedTotalIlvl + (p.ilvl or 0)
        table.insert(replacedNames, p.name or "Unknown")
    end

    local inDpsBrez = 0
    for _, m in ipairs(memberDataList) do
        if m.role == "DAMAGER" and m.brez then inDpsBrez = inDpsBrez + 1 end
    end

    local finalLust = party.lust - replacedLust + inLust
    local finalBrez = party.brez - replacedBrez + inBrez
    local finalDpsBrez = party.dpsBrez - replacedDpsBrez + inDpsBrez

    local targetMinBrez = (db.options and db.options.requireBrez == false) and 0 or (db.minBrez or 1)
    local targetMinDpsBrez = (db.options and db.options.requireDpsBrez == false) and 0 or (db.minDpsBrez or 0)
    local targetMinLust = (db.options and db.options.requireLust == false) and 0 or (db.minLust or 1)

    if finalLust < targetMinLust then
        return false, "После замены не будет хватать Героизма (Lust)"
    end
    if finalBrez < targetMinBrez then
        return false, "После замены не будет хватать БРа (BRez)"
    end
    if finalDpsBrez < targetMinDpsBrez then
        return false, "После замены не будет хватать БРа у ДД"
    end

    -- 6. Оценка пользы: RIO, ilvl и бонус сыгранности пати
    local replacedAvgRio = replacedTotalRio / #toReplace
    local replacedAvgIlvl = replacedTotalIlvl / #toReplace

    -- Бонус сыгранной пати (+координация, войс, контроль)
    local cohesionBonus = (numIncoming == 2 and 50) or (numIncoming == 3 and 150) or 250
    local rioGain = inAvgRio - replacedAvgRio
    local effectiveGain = rioGain + cohesionBonus

    local minRioGain = db.upgradeRioDiff or 250
    if effectiveGain < minRioGain then
        return false, string.format("Прирост группы недостаточен (+%d < +%d RIO)", math.floor(effectiveGain), minRioGain)
    end

    if inAvgIlvl < (replacedAvgIlvl - 3) then
        return false, string.format("Средний ilvl группы ниже заменяемых (%.1f < %.1f)", inAvgIlvl, replacedAvgIlvl)
    end

    -- 7. Успех! Очередь на кик
    KAR.Log(string.format("|cff00ffff[Групповая замена]|r Найдена топ-группа x%d (Ср.RIO: %d, +%d RIO). Заменяем %d пугов: %s",
        numIncoming, math.floor(inAvgRio), math.floor(effectiveGain), #toReplace, table.concat(replacedNames, ", ")
    ))

    for _, p in ipairs(toReplace) do
        local nameToKick = p.name
        KAR.EnqueueSecureAction(function()
            UninviteUnit(nameToKick)
        end)
    end

    return true, "OK (Групповая замена)", {
        tanks = inTanks,
        healers = inHealers,
        dps = inDps,
        lust = inLust,
        brez = inBrez,
        dpsLust = (inDps > 0 and inLust > 0) and inLust or 0,
        dpsBrez = (inDps > 0 and inBrez > 0) and inBrez or 0
    }
end

-- -------------------------------------------------------------
-- Эвристика опыта в целевой ключ (Dungeon Key Deficit Model)
-- -------------------------------------------------------------
function KAR.GetApplicantDungeonInfo(applicantID, memberIndex)
    memberIndex = memberIndex or 1
    local bestRunLevel = 0
    local finishedSuccess = false
    local mapScore = 0

    if C_LFGList and C_LFGList.GetApplicantDungeonScoreInfo then
        local ok, info = pcall(C_LFGList.GetApplicantDungeonScoreInfo, applicantID, memberIndex)
        if ok and info then
            bestRunLevel = tonumber(info.bestRunLevel or info.level or 0) or 0
            finishedSuccess = (info.finishedSuccess == true)
            mapScore = tonumber(info.mapScore or 0) or 0
        end
    end

    return bestRunLevel, finishedSuccess, mapScore
end

KAR.EvaluateApplicant = function(applicantID)
    local db = KeyAutoRecruitDB
    if not db.enabled then return false, "Аддон выключен" end
    if awaitingInspectGUID ~= nil then return false, "Ожидание инспекта..." end

    local appInfo = C_LFGList.GetApplicantInfo(applicantID)
    if not appInfo or appInfo.applicationStatus ~= "applied" then
        return false, "Не applied"
    end

    local numMembers = appInfo.numMembers or 1
    local party = KAR.GetGroupStatus()
    local isLeader = UnitIsGroupLeader("player")

    -- -------------------------------------------------------------
    -- ВЕТКА А: ОДИНОЧНЫЙ КАНДИДАТ (numMembers == 1)
    -- -------------------------------------------------------------
    if numMembers == 1 then
        local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, 1)
        dungeonScore = dungeonScore or 0
        itemLevel = itemLevel or 0

        -- 0. Проверка Черного списка (Blacklist)
        local isBL, blInfo = KAR.IsBlacklisted(name)
        if isBL then
            return false, string.format("В черном списке: %s", (blInfo and blInfo.reason) or "ЧС")
        end

        -- 1. Проверка минимального RIO и ilvl
        local effectiveMinIlvl = KAR.GetEffectiveMinIlvl()
        local effectiveMinRio  = tonumber(db.minRio) or 0
        if itemLevel < effectiveMinIlvl then
            return false, string.format("ilvl %d < %d (мин. порог)", math.floor(itemLevel), effectiveMinIlvl)
        end
        if dungeonScore < effectiveMinRio then
            return false, string.format("RIO %d < %d (мин. порог)", math.floor(dungeonScore), effectiveMinRio)
        end

        -- 1b. Проверка закрытого ключа в целевое подземелье (Dungeon Key Deficit Model)
        local dungeonCheckOn = (db.dungeonKeyCheckEnabled == true)
        if dungeonCheckOn then
            local targetInfo = KAR.GetTargetDungeonInfo and KAR.GetTargetDungeonInfo()
            local targetLevel = targetInfo and targetInfo.targetLevel or 0
            if targetLevel > 0 then
                local bestLvl, isTimed, mapScore = KAR.GetApplicantDungeonInfo(applicantID, 1)
                local maxDeficit = tonumber(db.maxDungeonKeyDeficit) or 2
                local minRequiredLevel = math.max(0, targetLevel - maxDeficit)

                if bestLvl < minRequiredLevel then
                    if bestLvl == 0 then
                        return false, string.format("Нет закрытого ключа в %s (0 < +%d, отст > %d)", (targetInfo.name or "данж"), minRequiredLevel, maxDeficit)
                    else
                        return false, string.format("Ключ в %s +%d < +%d (отставание %d > %d)", (targetInfo.name or "данж"), bestLvl, minRequiredLevel, targetLevel - bestLvl, maxDeficit)
                    end
                end

                if db.requireDungeonTimed and not isTimed then
                    return false, string.format("Ключ в %s (+%d) не вовремя (деплит)", (targetInfo.name or "данж"), bestLvl)
                end
            end
        end

        -- 2. Проверка разрешенных специализаций
        local classSpecs = KAR.CLASS_SPECS[class] or {}
        local hasAnyAllowedSpec = false
        for _, specID in ipairs(classSpecs) do
            local sInfo = KAR.SPECIALIZATIONS[specID]
            if sInfo and db.specs[specID] then
                if (tank and sInfo.role == "TANK") or (healer and sInfo.role == "HEALER") or (damage and sInfo.role == "DAMAGER") then
                    hasAnyAllowedSpec = true
                    break
                end
            end
        end
        if not hasAnyAllowedSpec then return false, "Спек отключен в настройках" end

        -- Определение роли кандидата
        local candRole = nil
        if assignedRole and assignedRole ~= "NONE" then
            candRole = assignedRole
        elseif tank and party.needTank and party.tanks < 1 then
            candRole = "TANK"
        elseif healer and party.needHealer and party.healers < 1 then
            candRole = "HEALER"
        elseif damage and party.needDps and party.dps < 3 then
            candRole = "DAMAGER"
        else
            candRole = (tank and "TANK") or (healer and "HEALER") or "DAMAGER"
        end

        local candHasLust = (class == "SHAMAN" or class == "MAGE" or class == "HUNTER" or class == "EVOKER")
        local candHasBrez = (class == "DRUID" or class == "DEATHKNIGHT" or class == "WARLOCK" or class == "PALADIN")

        -- Проверяем: влезает ли кандидат напрямую в открытый слот без превышения лимитов ролей?
        local fitsDirectly = false
        if party.openSlots > 0 then
            if candRole == "TANK" and party.needTank and party.tanks < 1 then fitsDirectly = true
            elseif candRole == "HEALER" and party.needHealer and party.healers < 1 then fitsDirectly = true
            elseif candRole == "DAMAGER" and party.needDps and party.dps < 3 then fitsDirectly = true end
        end

        if fitsDirectly then
            -- Проверка Героизма и БРа для прямого приема
            local lustAfter = party.lust + (candHasLust and 1 or 0)
            local brezAfter = party.brez + (candHasBrez and 1 or 0)
            local isCandDpsBrez = (candRole == "DAMAGER" and candHasBrez)
            local dpsBrezAfter = party.dpsBrez + (isCandDpsBrez and 1 or 0)
            local slotsLeftAfter = party.openSlots - 1
            local dpsSlotsLeftAfter = math.max(0, 3 - (party.dps + ((candRole == "DAMAGER") and 1 or 0)))

            local targetMinBrez = (db.options and db.options.requireBrez == false) and 0 or (db.minBrez or 1)
            local targetMinDpsBrez = (db.options and db.options.requireDpsBrez == false) and 0 or (db.minDpsBrez or 0)
            local targetMinLust = (db.options and db.options.requireLust == false) and 0 or (db.minLust or 1)

            local lustNeeded = math.max(0, targetMinLust - lustAfter)
            local brezNeeded = math.max(0, targetMinBrez - brezAfter)
            local dpsBrezNeeded = math.max(0, targetMinDpsBrez - dpsBrezAfter)

            if dpsSlotsLeftAfter < dpsBrezNeeded then
                return false, "Нужен ДД с БР (Battle Res)"
            end
            if slotsLeftAfter < (lustNeeded + brezNeeded) then
                return false, string.format("Нужен %s", (lustNeeded > 0 and brezNeeded > 0) and "Lust/BRez" or (lustNeeded > 0 and "Lust" or "BRez"))
            end
            if slotsLeftAfter == 0 and (lustNeeded > 0 or brezNeeded > 0 or dpsBrezNeeded > 0) then
                return false, "Не хватает Lust/BRez"
            end

            return true, "OK", {
                tanks = (candRole == "TANK") and 1 or 0,
                healers = (candRole == "HEALER") and 1 or 0,
                dps = (candRole == "DAMAGER") and 1 or 0,
                lust = candHasLust and 1 or 0,
                brez = candHasBrez and 1 or 0,
                dpsLust = (candRole == "DAMAGER" and candHasLust) and 1 or 0,
                dpsBrez = (candRole == "DAMAGER" and candHasBrez) and 1 or 0,
            }
        else
            -- Кандидат не влезает напрямую (роль уже занята, либо группа 4/5 или 5/5)
            -- Проверяем возможность АВТО-ЗАМЕНЫ более слабых пугов:
            if isLeader and db.upgradeFullGroup then
                local canReplace, repReason, repRoles = KAR.EvaluateSoloReplacement(
                    applicantID, name, class, candRole, itemLevel, dungeonScore, candHasLust, candHasBrez, party, db
                )
                if canReplace then
                    return true, repReason, repRoles
                else
                    return false, repReason or "Нет слота для роли"
                end
            else
                return false, (party.openSlots == 0 and "Группа полна") or "Нет слота для роли"
            end
        end

    -- -------------------------------------------------------------
    -- ВЕТКА Б: СЫГРАННАЯ ГРУППА ИЗ 2, 3 ИЛИ 4 ИГРОКОВ (numMembers >= 2)
    -- -------------------------------------------------------------
    else
        local appTanks, appHealers, appDps = 0, 0, 0
        local appLust, appBrez = 0, 0
        local memberDataList = {}

        for i = 1, numMembers do
            local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, i)
            dungeonScore = dungeonScore or 0
            itemLevel = itemLevel or 0

            -- Проверка Черного списка (Blacklist) для каждого участника группы
            local isBL, blInfo = KAR.IsBlacklisted(name)
            if isBL then
                return false, string.format("Участник %s в черном списке: %s", name or "Unknown", (blInfo and blInfo.reason) or "ЧС")
            end

            local classSpecs = KAR.CLASS_SPECS[class] or {}
            local hasAnyAllowedSpec = false
            for _, specID in ipairs(classSpecs) do
                local sInfo = KAR.SPECIALIZATIONS[specID]
                if sInfo and db.specs[specID] then
                    if (tank and sInfo.role == "TANK") or (healer and sInfo.role == "HEALER") or (damage and sInfo.role == "DAMAGER") then
                        hasAnyAllowedSpec = true
                        break
                    end
                end
            end
            if not hasAnyAllowedSpec then return false, "У участника группы отключен спек" end

            local memberRole = nil
            if tank and not healer and not damage then memberRole = "TANK"
            elseif healer and not tank and not damage then memberRole = "HEALER"
            elseif damage and not tank and not healer then memberRole = "DAMAGER"
            else
                if assignedRole and assignedRole ~= "NONE" then memberRole = assignedRole
                elseif tank and (party.tanks + appTanks < 1) then memberRole = "TANK"
                elseif healer and (party.healers + appHealers < 1) then memberRole = "HEALER"
                else memberRole = "DAMAGER" end
            end

            if memberRole == "TANK" then appTanks = appTanks + 1
            elseif memberRole == "HEALER" then appHealers = appHealers + 1
            else appDps = appDps + 1 end

            local hasL = (class == "SHAMAN" or class == "MAGE" or class == "HUNTER" or class == "EVOKER")
            local hasB = (class == "DRUID" or class == "DEATHKNIGHT" or class == "WARLOCK" or class == "PALADIN")
            if hasL then appLust = appLust + 1 end
            if hasB then appBrez = appBrez + 1 end

            local mBestKey, mIsTimed, mMapScore = KAR.GetApplicantDungeonInfo(applicantID, i)
            table.insert(memberDataList, {
                name = name,
                class = class,
                role = memberRole,
                ilvl = itemLevel,
                rio = dungeonScore,
                lust = hasL,
                brez = hasB,
                bestKey = mBestKey,
                isTimed = mIsTimed,
                mapScore = mMapScore,
            })
        end

        -- Валидация состава входящей группы
        if appTanks > 1 or appHealers > 1 or appDps > 3 then
            return false, "Некорректный состав группы (танков>1, хилов>1 или дд>3)"
        end

        -- Оценка группы по вагонам и общему RIO/ilvl
        local effectiveMinIlvl = KAR.GetEffectiveMinIlvl()
        local sMinIlvl = math.min(tonumber(db.seasonMinIlvl) or 200, effectiveMinIlvl)
        local sMaxIlvl = db.seasonMaxIlvl or 730
        local sMinRio  = db.seasonMinRio  or 0
        local sMaxRio  = db.seasonMaxRio  or 3000
        local effectiveMinRio  = tonumber(db.minRio) or 0

        local totalIlvl, totalRio = 0, 0
        local maxMemberIlvl, minMemberIlvl = 0, 9999
        local vagonCount = 0
        local vagonHasLust = false

        for _, m in ipairs(memberDataList) do
            totalIlvl = totalIlvl + m.ilvl
            totalRio = totalRio + m.rio
            if m.ilvl > maxMemberIlvl then maxMemberIlvl = m.ilvl end
            if m.ilvl < minMemberIlvl then minMemberIlvl = m.ilvl end

            if m.ilvl < effectiveMinIlvl or m.rio < effectiveMinRio then
                vagonCount = vagonCount + 1
                if m.lust then vagonHasLust = true end
            end
        end

        local vagonAbsoluteFloor = math.max(sMinIlvl, effectiveMinIlvl - (db.vagonMaxIlvlDiff or 35))
        for _, m in ipairs(memberDataList) do
            if m.ilvl < vagonAbsoluteFloor then
                return false, string.format("Игрок %s: ilvl %d < %d (дно группы)", m.name or "Unknown", math.floor(m.ilvl), vagonAbsoluteFloor)
            end
        end

        -- Проверка закрытых ключей группы в целевое подземелье (Dungeon Key Deficit Model)
        local dungeonCheckOn = (db.dungeonKeyCheckEnabled == true)
        if dungeonCheckOn then
            local targetInfo = KAR.GetTargetDungeonInfo and KAR.GetTargetDungeonInfo()
            local targetLevel = targetInfo and targetInfo.targetLevel or 0
            if targetLevel > 0 then
                local maxDeficit = tonumber(db.maxDungeonKeyDeficit) or 2
                local minRequiredLevel = math.max(0, targetLevel - maxDeficit)
                local deficitFailCount = 0
                local failedMemberName = nil
                local failedMemberKey = 0

                for _, m in ipairs(memberDataList) do
                    local failKey = (m.bestKey < minRequiredLevel)
                    local failTimed = (db.requireDungeonTimed and not m.isTimed)
                    if failKey or failTimed then
                        deficitFailCount = deficitFailCount + 1
                        failedMemberName = m.name
                        failedMemberKey = m.bestKey
                    end
                end

                if deficitFailCount > 0 then
                    local allowVagon = db.allowOneVagon
                    local maxAllowed = (allowVagon and 1) or 0
                    if deficitFailCount > maxAllowed then
                        if failedMemberKey == 0 then
                            return false, string.format("Участник %s: нет закрытого ключа в данный данж (0 < +%d, отст > %d)", failedMemberName or "Игрок", minRequiredLevel, maxDeficit)
                        else
                            return false, string.format("Участник %s: ключ в данный данж +%d < +%d (отставание %d > %d)", failedMemberName or "Игрок", failedMemberKey, minRequiredLevel, targetLevel - failedMemberKey, maxDeficit)
                        end
                    end
                end
            end
        end

        local avgIlvl = totalIlvl / numMembers
        local avgRio  = totalRio / numMembers
        local ilvlRange = math.max(1, sMaxIlvl - sMinIlvl)
        local rioRange  = math.max(1, sMaxRio - sMinRio)
        local ilvlPower = math.min(100, math.max(0, ((avgIlvl - sMinIlvl) / ilvlRange) * 100))
        local rioPower  = math.min(100, math.max(0, ((avgRio - sMinRio) / rioRange) * 100))
        local groupPower = math.floor((ilvlPower * 0.5) + (rioPower * 0.5))

        if vagonCount > 0 then
            if not db.allowOneVagon then return false, "Вагон запрещен" end
            local maxAllowedVagons = (numMembers == 4 and groupPower >= 65) and 2 or 1
            if vagonCount > maxAllowedVagons then
                return false, string.format("Много вагонов (%d > %d)", vagonCount, maxAllowedVagons)
            end
            local ilvlDiff = maxMemberIlvl - minMemberIlvl
            local maxAllowedDiff = (db.vagonMaxIlvlDiff or 35) + (vagonHasLust and 15 or 0)
            if ilvlDiff > maxAllowedDiff then
                return false, string.format("Большой разрыв ilvl (%d > %d)", math.floor(ilvlDiff), maxAllowedDiff)
            end
        end

        -- Проверяем: помещается ли группа напрямую в открытые слоты?
        local fitsDirectly = (party.openSlots >= numMembers) and
                             (party.tanks + appTanks <= 1) and
                             (party.healers + appHealers <= 1) and
                             (party.dps + appDps <= 3)

        if fitsDirectly then
            local lustAfter = party.lust + appLust
            local brezAfter = party.brez + appBrez
            local appDpsBrez = (appDps > 0 and appBrez > 0) and appBrez or 0
            local dpsBrezAfter = party.dpsBrez + appDpsBrez
            local slotsLeftAfter = party.openSlots - numMembers
            local dpsSlotsLeftAfter = math.max(0, 3 - (party.dps + appDps))

            local targetMinBrez = (db.options and db.options.requireBrez == false) and 0 or (db.minBrez or 1)
            local targetMinDpsBrez = (db.options and db.options.requireDpsBrez == false) and 0 or (db.minDpsBrez or 0)
            local targetMinLust = (db.options and db.options.requireLust == false) and 0 or (db.minLust or 1)

            local lustNeeded = math.max(0, targetMinLust - lustAfter)
            local brezNeeded = math.max(0, targetMinBrez - brezAfter)
            local dpsBrezNeeded = math.max(0, targetMinDpsBrez - dpsBrezAfter)

            if dpsSlotsLeftAfter < dpsBrezNeeded then
                return false, "Нужен ДД с БР (Battle Res)"
            end
            if slotsLeftAfter < (lustNeeded + brezNeeded) then
                return false, "Не хватает Lust/BRez"
            end
            if slotsLeftAfter == 0 and (lustNeeded > 0 or brezNeeded > 0 or dpsBrezNeeded > 0) then
                return false, "Не хватает Lust/BRez"
            end

            return true, "OK", {
                tanks = appTanks, healers = appHealers, dps = appDps,
                lust = appLust, brez = appBrez,
                dpsLust = (appDps > 0 and appLust > 0) and appLust or 0,
                dpsBrez = (appDps > 0 and appBrez > 0) and appBrez or 0
            }
        else
            -- Группа не помещается напрямую (не хватает слотов или роли пересекаются)
            -- Проверяем групповую авто-замену пугов:
            if isLeader and (db.upgradeMultiGroup ~= false) and (db.upgradeFullGroup ~= false) then
                local canGrpRep, grpReason, grpRoles = KAR.EvaluateGroupReplacement(applicantID, memberDataList, party, db)
                if canGrpRep then
                    return true, grpReason, grpRoles
                else
                    return false, grpReason or "Недостаточно слотов для группы"
                end
            else
                return false, "Недостаточно слотов для группы"
            end
        end
    end
end

KAR.AnnounceCandidateFound = function(role, memberName, specName, ilvl, rio, hasLust, hasBrez)
    local roleRu = (role == "TANK" or role == "ТАНК") and "ТАНК" or ((role == "HEALER" or role == "ХИЛ") and "ХИЛ" or "ДД")
    local color = (roleRu == "ТАНК") and "|cff3399ff" or ((roleRu == "ХИЛ") and "|cff00ff7f" or "|cffff9900")

    local lustBrezStr = ""
    if hasLust and hasBrez then lustBrezStr = " [БЛ+БР]"
    elseif hasLust then lustBrezStr = " [БЛ]"
    elseif hasBrez then lustBrezStr = " [БР]" end

    -- 1. Визуальный баннер по центру экрана
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame,
            string.format("%s[KAR] НАЙДЕН %s: %s (%s, %d ilvl, %d RIO)%s|r",
                color, roleRu, memberName or "Игрок", specName or "", ilvl or 0, rio or 0, lustBrezStr
            ),
            ChatTypeInfo["RAID_WARNING"]
        )
    end

    -- 2. Звуковой сигнал в игре
    pcall(function()
        if SOUNDKIT and SOUNDKIT.READY_CHECK then
            PlaySound(SOUNDKIT.READY_CHECK, "Master")
        else
            PlaySound(8960, "Master")
        end
    end)

    -- 3. Мигание иконки в панели задач Windows
    FlashClientIcon()

    -- 4. Текстовое сообщение в чат
    KAR.Log(string.format("%s[НАЙДЕН %s]|r %s (%s, %d ilvl, %d RIO)%s",
        color, roleRu, memberName or "Игрок", specName or "", ilvl or 0, rio or 0, lustBrezStr
    ))

    -- 5. Сигнал для Python-кликера (голос в наушники)
    SendDaemonSyncMessage(string.format("KAR_FOUND:%s:%s", roleRu, memberName or "Unknown"))
end

KAR.AnnounceGroupFull = function()
    if hasAnnouncedFull then return end
    hasAnnouncedFull = true

    -- 1. Звуковой сигнал победы/сбора
    pcall(function()
        if SOUNDKIT and SOUNDKIT.RAID_WARNING then
            PlaySound(SOUNDKIT.RAID_WARNING, "Master")
        else
            PlaySound(8959, "Master")
        end
    end)

    -- 2. Мигание иконки окна игры
    FlashClientIcon()

    -- 3. Большой баннер по центру экрана
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, "|cff00ff00[KAR] ВНИМАНИЕ! ГРУППА ПОЛНОСТЬЮ СОБРАНА (5/5)!|r", ChatTypeInfo["RAID_WARNING"])
    end

    local party = KAR.GetGroupStatus()
    KAR.Log(string.format("|cff00ff00[5/5 СОБРАНО]|r Танк:%d Хил:%d ДД:%d | БЛ:%d БР:%d - Набор завершен!",
        party.tanks, party.healers, party.dps, party.lust, party.brez
    ))

    -- 4. Оптический сигнал для внешнего кликера (Пурпурный / Маджента)
    if KAR.ShowGroupFullPixel then
        KAR.ShowGroupFullPixel(2.5)
    end

    -- 5. Сигнал для Python-кликера (голос в наушники)
    SendDaemonSyncMessage("KAR_GROUP_FULL")
end

local function InspectUnit(unit)
    if not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    local name = UnitName(unit)

    awaitingInspectGUID = guid
    awaitingInspectUnit = unit

    if CanInspect(unit) then NotifyInspect(unit) end

    if inspectTimeoutTimer then inspectTimeoutTimer:Cancel() end
    inspectTimeoutTimer = C_Timer.NewTimer(3.5, function()
        if awaitingInspectGUID == guid then
            awaitingInspectGUID = nil
            awaitingInspectUnit = nil
            KAR.ProcessApplicants()
        end
    end)
end

local isProcessing = false
KAR.ProcessApplicants = function()
    local db = KeyAutoRecruitDB
    if not db or (not db.enabled and not db.active) then return end
    if isProcessing or awaitingInspectGUID ~= nil then return end

    local party = KAR.GetGroupStatus()
    local isLeader = (not IsInGroup()) or (GetNumGroupMembers() <= 1) or UnitIsGroupLeader("player")

    -- 1. СТРОГАЯ ПРОВЕРКА НА ЛИДЕРА ГРУППЫ:
    -- Если пользователь НЕ лидер группы:
    -- Категорический запрет на набор, инвайты и реакцию оптического пикселя (остается IDLE)!
    -- Но продолжаем сканировать входящие заявки на наличие игроков из ЧС и предупреждать лидера
    if not isLeader then
        if C_LFGList and C_LFGList.GetApplicants then
            local applicants = C_LFGList.GetApplicants()
            if applicants and #applicants > 0 then
                KAR.CheckApplicantsForBlacklist(applicants)
            end
        end
        return
    end

    local canUpgrade = isLeader and (db.upgradeFullGroup ~= false or db.upgradeMultiGroup ~= false)

    if party.total >= 5 and party.openSlots == 0 and party.pending == 0 then
        KAR.AnnounceGroupFull()
        if not canUpgrade then
            return
        end
    else
        hasAnnouncedFull = false
    end

    if party.openSlots <= 0 and not canUpgrade then return end

    if not C_LFGList or not C_LFGList.GetApplicants then return end
    local applicants = C_LFGList.GetApplicants()
    if not applicants or #applicants == 0 then return end

    -- Оповещение о кандидатах из черного списка
    KAR.CheckApplicantsForBlacklist(applicants)

    for _, applicantID in ipairs(applicants) do
        -- Если заявка уже ожидает таймера человеческой задержки - пропускаем дублирующий прогон
        if pendingHumanInvites[applicantID] then
            break
        end

        local ok, reason, roles = KAR.EvaluateApplicant(applicantID)
        local appInfo = C_LFGList.GetApplicantInfo(applicantID)
        local memberName = "Unknown"
        if appInfo and appInfo.numMembers and appInfo.numMembers > 0 then
            memberName = tostring(C_LFGList.GetApplicantMemberInfo(applicantID, 1))
        end

        if ok then
            -- Определение роли кандидата
            local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, 1)
            local roleTitle = "ДД"
            local roleCode = "DPS"
            if tank or (roles and roles.tanks and roles.tanks > 0) then
                roleTitle = "ТАНК"
                roleCode = "TANK"
            elseif healer or (roles and roles.healers and roles.healers > 0) then
                roleTitle = "ХИЛ"
                roleCode = "HEALER"
            end

            -- Вычисление человеческой задержки перед инвайтом (4-7 сек по умолчанию)
            local delay = 0
            if db.humanDelayEnabled ~= false then
                local minD = tonumber(db.inviteDelayMin) or 4
                local maxD = tonumber(db.inviteDelayMax) or 7
                if minD > maxD then minD, maxD = maxD, minD end
                delay = math.random(math.floor(minD * 10), math.floor(maxD * 10)) / 10.0
            end

            if delay > 0 then
                pendingHumanInvites[applicantID] = true
                KAR.Log(string.format("|cff00ccff[Эмуляция человека]|r Кандидат |cffffff00%s|r (%s) одобрен! Ожидание %.1f сек перед инвайтом...", memberName, roleTitle, delay))

                C_Timer.After(delay, function()
                    pendingHumanInvites[applicantID] = nil

                    -- Перепроверяем, активна ли еще заявка
                    local curAppInfo = C_LFGList.GetApplicantInfo(applicantID)
                    if not curAppInfo or curAppInfo.applicationStatus ~= "applied" then
                        KAR.Log(string.format("|cffaaaaaa[Отмена инвайта]|r %s отменил заявку или принят кем-то другим.", memberName))
                        KAR.ProcessApplicants()
                        return
                    end

                    -- Перепроверяем статус группы
                    local curParty = KAR.GetGroupStatus()
                    if curParty.openSlots <= 0 and not canUpgrade then
                        KAR.Log(string.format("|cffaaaaaa[Отмена инвайта]|r Группа уже заполнена (5/5)."))
                        return
                    end

                    KAR.Log(string.format("|cff00ff00[ИНВАЙТ]|r %s", memberName))
                    isProcessing = true
                    if roles then pendingInvitedRoles[applicantID] = roles end

                    if KAR.AnnounceCandidateFound then
                        KAR.AnnounceCandidateFound(roleTitle, memberName, localizedClass or class, itemLevel or 0, dungeonScore or 0, roles and roles.lust, roles and roles.brez)
                    end

                    -- Сохраняем характеристики в ApplicantDataCache
                    local numApp = curAppInfo and curAppInfo.numMembers or 1
                    for mi = 1, numApp do
                        local mName, mClass, _, _, mIlvl, _, mTank, mHeal, mDps, _, _, mScore = C_LFGList.GetApplicantMemberInfo(applicantID, mi)
                        if mName then
                            local cName = string.match(mName, "([^-]+)") or mName
                            local mRole = mTank and "TANK" or (mHeal and "HEALER" or "DAMAGER")
                            local mLust = (mClass == "SHAMAN" or mClass == "MAGE" or mClass == "HUNTER" or mClass == "EVOKER")
                            local mBrez = (mClass == "DRUID" or mClass == "DEATHKNIGHT" or mClass == "WARLOCK" or mClass == "PALADIN")
                            KAR.ApplicantDataCache[cName] = {
                                name = mName, class = mClass,
                                ilvl = math.floor(mIlvl or 0), rio = math.floor(mScore or 0),
                                role = mRole, lust = mLust, brez = mBrez, time = GetTime()
                            }
                            soloJoinedMembers[mName] = true
                            soloJoinedMembers[cName] = true
                        end
                    end

                    KAR.EnqueueSecureAction(function()
                        if C_LFGList and C_LFGList.InviteApplicant then
                            C_LFGList.InviteApplicant(applicantID)
                        end
                        isProcessing = false
                    end, roleCode)
                end)
                break
            else
                -- Мгновенный инвайт при отключенной эмуляции
                KAR.Log(string.format("|cff00ff00[ИНВАЙТ]|r %s", memberName))
                isProcessing = true
                if roles then pendingInvitedRoles[applicantID] = roles end

                if KAR.AnnounceCandidateFound then
                    KAR.AnnounceCandidateFound(roleTitle, memberName, localizedClass or class, itemLevel or 0, dungeonScore or 0, roles and roles.lust, roles and roles.brez)
                end

                local numApp = appInfo and appInfo.numMembers or 1
                for mi = 1, numApp do
                    local mName, mClass, _, _, mIlvl, _, mTank, mHeal, mDps, _, _, mScore = C_LFGList.GetApplicantMemberInfo(applicantID, mi)
                    if mName then
                        local cName = string.match(mName, "([^-]+)") or mName
                        local mRole = mTank and "TANK" or (mHeal and "HEALER" or "DAMAGER")
                        local mLust = (mClass == "SHAMAN" or mClass == "MAGE" or mClass == "HUNTER" or mClass == "EVOKER")
                        local mBrez = (mClass == "DRUID" or mClass == "DEATHKNIGHT" or mClass == "WARLOCK" or mClass == "PALADIN")
                        KAR.ApplicantDataCache[cName] = {
                            name = mName, class = mClass,
                            ilvl = math.floor(mIlvl or 0), rio = math.floor(mScore or 0),
                            role = mRole, lust = mLust, brez = mBrez, time = GetTime()
                        }
                        soloJoinedMembers[mName] = true
                        soloJoinedMembers[cName] = true
                    end
                end

                KAR.EnqueueSecureAction(function()
                    if C_LFGList and C_LFGList.InviteApplicant then
                        C_LFGList.InviteApplicant(applicantID)
                    end
                    isProcessing = false
                end, roleCode)
                break
            end
        else
            if db.autoDecline and appInfo and appInfo.applicationStatus == "applied" then
                KAR.Log(string.format("|cffff3333[ОТМЕНА]|r %s: %s", memberName, reason))
                KAR.EnqueueSecureAction(function()
                    if C_LFGList and C_LFGList.DeclineApplicant then
                        C_LFGList.DeclineApplicant(applicantID)
                    end
                end, "DECLINE")
            end
        end
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "KeyAutoRecruit" then
            InitDB()
            InitSecureHardwareBridge()
            InitBlacklistContextMenu()
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                C_ChatInfo.RegisterAddonMessagePrefix("KAR_SYNC")
            elseif RegisterAddonMessagePrefix then
                RegisterAddonMessagePrefix("KAR_SYNC")
            end
            if KAR.CaptureCurrentGroupSnapshot then KAR.CaptureCurrentGroupSnapshot() end
            KAR.Log("Загружен (/kar для настроек)")
            C_Timer.After(2.0, function()
                if KAR.RunAPIProbe then KAR.RunAPIProbe() end
            end)
            C_Timer.NewTicker(4.0, function()
                if KAR.CheckAndSyncFriendUnit then
                    if UnitExists("target") then KAR.CheckAndSyncFriendUnit("target") end
                    if UnitExists("mouseover") then KAR.CheckAndSyncFriendUnit("mouseover") end
                end
            end)
            C_Timer.NewTicker(30.0, function()
                local now = GetTime()
                if KAR.FriendSyncCooldowns then
                    for k, t in pairs(KAR.FriendSyncCooldowns) do
                        if (now - t) > 600 then KAR.FriendSyncCooldowns[k] = nil end
                    end
                end
                if KAR.Comm and KAR.Comm.blockedPartners then
                    for k, t in pairs(KAR.Comm.blockedPartners) do
                        if now >= t then KAR.Comm.blockedPartners[k] = nil end
                    end
                end
            end)
        end

    elseif event == "CHALLENGE_MODE_START" or event == "ZONE_CHANGED_NEW_AREA" then
        if KAR.CaptureCurrentGroupSnapshot then KAR.CaptureCurrentGroupSnapshot() end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if KAR.CaptureCurrentGroupSnapshot then KAR.CaptureCurrentGroupSnapshot() end
        local num = GetNumGroupMembers()
        local count = num > 0 and num or 1
        for i = 1, count do
            local unit = (num == 0) and "player" or (i == 1 and "player" or ("party" .. (i - 1)))
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local guid = UnitGUID(unit)
                if guid and not KAR.InspectedMembers[guid] then
                    InspectUnit(unit)
                    return
                end
            end
        end

        local currentParty = KAR.GetGroupStatus()
        if currentParty.total >= 5 and currentParty.openSlots == 0 then
            KAR.AnnounceGroupFull()
        else
            hasAnnouncedFull = false
        end

    elseif event == "INSPECT_READY" then
        local guid = ...
        if awaitingInspectGUID and awaitingInspectGUID == guid then
            if inspectTimeoutTimer then inspectTimeoutTimer:Cancel() end

            local inspectUnit = awaitingInspectUnit or "party1"
            for i = 1, 4 do
                if UnitGUID("party" .. i) == guid then
                    inspectUnit = "party" .. i
                    break
                end
            end

            local specID = GetInspectSpecialization(inspectUnit)
            if (not specID or specID == 0) then specID = GetInspectSpecialization("target") end

            local sInfo = KAR.SPECIALIZATIONS[specID]
            local _, classTag = UnitClass(inspectUnit)
            local specName = sInfo and sInfo.name or ("#" .. tostring(specID or 0))
            local role = sInfo and sInfo.role or "DAMAGER"
            local hasLust = (classTag == "HUNTER" or classTag == "MAGE" or classTag == "SHAMAN" or classTag == "EVOKER") or (sInfo and sInfo.lust) or false
            local hasBrez = (classTag == "DRUID" or classTag == "DEATHKNIGHT" or classTag == "WARLOCK" or classTag == "PALADIN") or (sInfo and sInfo.brez) or false
            local unitName = UnitName(inspectUnit) or "Игрок"

            -- Запоминаем данные очков и ilvl при осмотре для эвристики замены
            local itemLevel = select(2, GetAverageItemLevel()) or 0
            if inspectUnit and C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
                -- RIO рейтинг игрока
            end

            KAR.InspectedMembers[guid] = {
                name = unitName, specID = specID, specName = specName,
                role = role, lust = hasLust, brez = hasBrez,
                ilvl = math.floor(itemLevel),
                rio = (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary(inspectUnit) and C_PlayerInfo.GetPlayerMythicPlusRatingSummary(inspectUnit).currentSeasonScore) or 0
            }

            KAR.Log(string.format("|cff00ff00[ОСМОТР]|r %s: |cffffff00%s|r (%s) [БЛ:%s БР:%s]",
                unitName, specName, role, hasLust and "+" or "-", hasBrez and "+" or "-"
            ))

            if specID and specID > 0 and KeyAutoRecruitDB.specs[specID] == false then
                KAR.Log(string.format("|cffff0000[КИК]|r %s (%s) запрещен!", unitName, specName))
                KAR.InspectedMembers[guid] = nil
                KAR.EnqueueSecureAction(function() UninviteUnit(unitName) end)
            end

            awaitingInspectGUID = nil
            awaitingInspectUnit = nil
            ClearInspectPlayer()

            if KAR.CaptureCurrentGroupSnapshot then KAR.CaptureCurrentGroupSnapshot() end

            local finalParty = KAR.GetGroupStatus()
            if finalParty.total >= 5 and finalParty.openSlots == 0 then
                KAR.AnnounceGroupFull()
            else
                C_Timer.After(0.4, KAR.ProcessApplicants)
            end
        end

    elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED" or event == "LFG_LIST_APPLICANT_UPDATED" then
        KAR.ProcessApplicants()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix == "KAR_SYNC" and KAR.OnCommMessage then
            KAR.OnCommMessage(msg, channel, sender)
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if KAR.CheckAndSyncFriendUnit then
            KAR.CheckAndSyncFriendUnit(unit)
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if KAR.CheckAndSyncFriendUnit then
            KAR.CheckAndSyncFriendUnit("target")
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if KAR.CheckAndSyncFriendUnit then
            KAR.CheckAndSyncFriendUnit("mouseover")
        end
    end
end)
