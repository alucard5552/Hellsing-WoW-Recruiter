--[[
    LFGHeuristics (Эвристика LFG и Монитор Сетевого Трафика)
    - Мгновенный перехват отправки запросов (TX) и ответов сервера Blizzard (RX)
    - Полная математика и скоринг групп в поиске подземелий Mythic+ (TWW 11.2.5)
    - Вывод в чат и интерактивное графическое окно (/lh или /heur)
]]

local ADDON_NAME, ns = ...
_G.LH = _G.LH or {}
local LH = _G.LH

-- -------------------------------------------------------------
-- Конфигурация по умолчанию
-- -------------------------------------------------------------
local DEFAULT_CONFIG = {
    enabled = true,
    role = "AUTO",            -- "AUTO", "TANK", "HEALER", "DAMAGER"
    minKey = 2,               -- От +2
    maxKey = 20,              -- До +20
    minLeaderRio = 1000,
    minMembers = 1,
    fastStartOnly = false,
    antiWts = true,
    chatEcho = true,          -- Мгновенно выводить все в игровой чат
}

-- Стоп-слова рекламы и коммерческих бустов
local WTS_BLACKLIST = {
    "wts", "boost", "carry", "sale", "sell", "голд", "руб", "twitch", "funpay",
    "free loot", "cheap", "fast run", "rub", "gold only", "pay", "loot trade",
    "акция", "гарант", "скидк"
}

-- Классы синергий
local LUST_CLASSES = { ["MAGE"]=true, ["SHAMAN"]=true, ["EVOKER"]=true, ["HUNTER"]=true }
local BREZ_CLASSES = { ["DEATHKNIGHT"]=true, ["DRUID"]=true, ["WARLOCK"]=true, ["PALADIN"]=true }

-- Состояние
LH.trafficLogs = {}
LH.lastEvaluated = {}
LH.bestGroup = nil

-- -------------------------------------------------------------
-- Логгер сетевого трафика и эвристики
-- -------------------------------------------------------------
function LH.Log(tag, title, details, colorHex)
    colorHex = colorHex or "00e5ff"
    local timestamp = date("%H:%M:%S")
    local entry = {
        time = timestamp,
        tag = tag,         -- "TX" (Отправка), "RX" (Прием), "HEUR" (Эвристика), "EVENT" (Событие)
        title = title,
        details = details or "",
        color = colorHex
    }

    table.insert(LH.trafficLogs, 1, entry)
    if #LH.trafficLogs > 400 then
        table.remove(LH.trafficLogs)
    end

    -- Мгновенный вывод в окно чата
    local cfg = LFGHeuristicsDB and LFGHeuristicsDB.config
    local echo = (cfg == nil) or (cfg.chatEcho ~= false)
    if echo then
        local tagBadge = ""
        if tag == "TX" then
            tagBadge = "|cff00e5ff[TX ➔ ОТПРАВКА]|r"
        elseif tag == "RX" then
            tagBadge = "|cff00ffaa[RX 🠔 ПОЛУЧЕНО]|r"
        elseif tag == "HEUR" then
            tagBadge = "|cffffff00[⚖️ ЭВРИСТИКА]|r"
        elseif tag == "ALERT" then
            tagBadge = "|cffff00ff[🔔 ИНВАЙТ]|r"
        else
            tagBadge = "|cff8c92a4[LFG-H]|r"
        end

        local line = string.format("%s |cff%s%s|r", tagBadge, colorHex, title)
        if details and details ~= "" then
            line = line .. " |cffcccccc" .. details .. "|r"
        end
        DEFAULT_CHAT_FRAME:AddMessage(line)
    end

    -- Обновление UI если открыто
    if LH.UpdateUI then
        LH.UpdateUI()
    end
end

-- -------------------------------------------------------------
-- Определение роли игрока
-- -------------------------------------------------------------
function LH.GetEffectiveRole()
    local cfg = LFGHeuristicsDB and LFGHeuristicsDB.config
    local cfgRole = cfg and cfg.role
    if cfgRole and cfgRole ~= "AUTO" then
        return cfgRole
    end

    local specIdx = GetSpecialization()
    if specIdx then
        local role = GetSpecializationRole(specIdx)
        if role and role ~= "NONE" then
            return role
        end
    end
    return "DAMAGER"
end

function LH.GetRoleBooleans()
    local role = LH.GetEffectiveRole()
    return (role == "TANK"), (role == "HEALER"), (role == "DAMAGER")
end

-- Словарь сопоставления подземелий TWW Season 1
local DUNGEON_KEYWORDS = {
    ["ara"] = "Ара-Кара",
    ["кара"] = "Ара-Кара",
    ["echoes"] = "Ара-Кара",
    ["stone"] = "Каменные Своды",
    ["vault"] = "Каменные Своды",
    ["свод"] = "Каменные Своды",
    ["dawn"] = "Рассвет",
    ["breaker"] = "Рассвет",
    ["рассвет"] = "Рассвет",
    ["thread"] = "Город Нитей",
    ["нитей"] = "Город Нитей",
    ["нити"] = "Город Нитей",
    ["mist"] = "Туманы Тирна Скитта",
    ["туман"] = "Туманы Тирна Скитта",
    ["скитт"] = "Туманы Тирна Скитта",
    ["tirna"] = "Туманы Тирна Скитта",
    ["necro"] = "Смертельная Тризна",
    ["тризн"] = "Смертельная Тризна",
    ["wake"] = "Смертельная Тризна",
    ["nw"] = "Смертельная Тризна",
    ["siege"] = "Осада Боралуса",
    ["осад"] = "Осада Боралуса",
    ["борал"] = "Осада Боралуса",
    ["boralus"] = "Осада Боралуса",
    ["grim"] = "Грим Батол",
    ["батол"] = "Грим Батол",
    ["batol"] = "Грим Батол",
    ["гб"] = "Грим Батол",
}

-- -------------------------------------------------------------
-- ДЕКОДЕР ТЕКСТА И ОЧИСТКА K-STRING
-- -------------------------------------------------------------
local resolverFrame = CreateFrame("Frame", "LH_TextResolverFrame")
local resolverFS = resolverFrame:CreateFontString(nil, "BACKGROUND")

-- Создаем скрытый чат-фрейм
local chatDecoderFrame = CreateFrame("ScrollingMessageFrame", "LH_KStringChatDecoder")
chatDecoderFrame:SetMaxLines(200)
chatDecoderFrame:SetFading(false)
chatDecoderFrame:Hide()

local lastDecodedFromChat = nil

local origAddMsg = chatDecoderFrame.AddMessage
chatDecoderFrame.AddMessage = function(self, text, r, g, b, id)
    lastDecodedFromChat = text
    if origAddMsg then
        origAddMsg(self, text, r, g, b, id)
    end
end

function LH.DecodeThroughChat(rawText)
    if not rawText or rawText == "" then return "" end

    -- Если в тексте есть ссылки K-String (|K...|k или Kq...k)
    if rawText:find("|K") or rawText:find("[Kk]q%d+[kK]") then
        lastDecodedFromChat = nil
        pcall(function()
            if chatDecoderFrame then
                chatDecoderFrame:AddMessage(rawText)
            end
        end)

        if lastDecodedFromChat and lastDecodedFromChat ~= "" and not lastDecodedFromChat:find("|K") and not lastDecodedFromChat:find("[Kk]q%d+[kK]") then
            return lastDecodedFromChat
        end

        if resolverFS then
            local ok, res = pcall(function()
                resolverFS:SetText(rawText)
                return resolverFS:GetText()
            end)
            if ok and res and res ~= "" and not res:find("|K") and not res:find("[Kk]q%d+[kK]") then
                return res
            end
        end

        return ""
    end

    return rawText
end

function LH.CleanText(str)
    if not str then return "" end
    -- Удаляем внутренние ссылки Blizzard |K...|k и токены Kq...k
    local s = str:gsub("|K.-|k", " "):gsub("|k", " "):gsub("[Kk]q%d+[kK]?", " ")
    -- Удаляем цветовые коды |cff... и |r
    s = s:gsub("|c%x%x%x%x%x%x%x%x", " "):gsub("|c%x%x%x%x%x%x", " "):gsub("|r", " ")
    -- Удаляем ссылки предметов |H...|h
    s = s:gsub("|H.-|h", " ")
    -- Удаляем текстуры |T...|t
    s = s:gsub("|T.-|t", " ")
    -- Удаляем атласы |A.-|a
    s = s:gsub("|A.-|a", " ")
    -- Удаляем дроби состава группы (1/5, 2/5, 3/5, 4/5), чтобы они не путались с уровнем ключа
    s = s:gsub("%f[%d][1-5]%s*/%s*[1-5]%f[%D]", " ")
    s = s:gsub("%f[%d][1-5]%s*из%s*[1-5]%f[%D]", " ")
    return s
end

-- -------------------------------------------------------------
-- Извлечение номера ключа (100% распознавание всех форматов M+)
-- -------------------------------------------------------------
function LH.ExtractKeyLevel(name, comment)
    local raw = (name or "") .. " " .. (comment or "")
    local text = LH.CleanText(raw)
    local lower = text:lower()

    -- 0. Эпохальный 0 (M0, m0, mythic 0, мифик 0)
    if lower:match("%f[%a]m%s*0%f[%D]") or lower:match("%f[%a]m0%f[%A]")
        or lower:match("mythic%s*0") or lower:match("мифик%s*0")
        or lower:match("%f[%a]м%s*0%f[%D]") or lower:match("%f[%a]м0%f[%A]") then
        return 0
    end

    -- 1. Явный плюс или минус: +10, + 10, 10+, -14, - 14, 14-
    local lvl = text:match("[+-]%s*(%d+)") or text:match("(%d+)%s*[+-]")
    if lvl then
        local n = tonumber(lvl)
        if n and n >= 2 and n <= 30 then return n end
    end

    -- 2. В скобках: [10], (10), [+10], (-14), {10}
    lvl = text:match("%[%s*[+-]?(%d+)%s*%]") or text:match("%(%s*[+-]?(%d+)%s*%)")
    if lvl then
        local n = tonumber(lvl)
        if n and n >= 2 and n <= 30 then return n end
    end

    -- 3. Ключевые слова: key 10, ключ 10, кл 10, 10 key, 10 ключ
    lvl = text:match("[Kk][Ee][Yy]%s*(%d+)") or text:match("ключ%s*(%d+)") or text:match("кл%.?%s*(%d+)")
        or text:match("(%d+)%s*[Kk][Ee][Yy]") or text:match("(%d+)%s*ключ")
    if lvl then
        local n = tonumber(lvl)
        if n and n >= 2 and n <= 30 then return n end
    end

    -- 4. Суффикс/префикс k: k9, 9k, k10, 10k
    lvl = text:match("%f[%a][Kk](%d+)%f[%A]") or text:match("%f[%d](%d+)[Kk]%f[%A]")
    if lvl then
        local n = tonumber(lvl)
        if n and n >= 2 and n <= 30 then return n end
    end

    -- 5. Число В НАЧАЛЕ строки (например: "+6", "14", "-14", "3 bm up", "15 bl", "10 fast", "4")
    lvl = text:match("^[+-]?(%d+)%f[%D]")
    if lvl then
        local n = tonumber(lvl)
        if n and n >= 2 and n <= 30 then return n end
    end

    -- 6. Число В КОНЦЕ строки (например: "Операция Шлюз 14", "Город Нитей 6", "Шлюз 10")
    lvl = text:match("%f[%d](%d+)%s*$")
    if lvl then
        local n = tonumber(lvl)
        if n and n >= 2 and n <= 30 then return n end
    end

    -- 7. Любое изолированное число от 2 до 30 (исключая уровни персонажа 70, 80 и ilvl)
    for num in text:gmatch("%f[%d](%d+)%f[%D]") do
        local n = tonumber(num)
        if n and n >= 2 and n <= 30 and n ~= 80 and n ~= 70 then
            return n
        end
    end

    return nil
end

function LH.FormatKeyBadge(keyLvl)
    if keyLvl == 0 then
        return "M0"
    elseif keyLvl and keyLvl > 0 then
        return string.format("+%d", keyLvl)
    else
        return "Н/Д"
    end
end

-- Таблица соответствия кодов активности Blizzard (Activity ID)
local ACTIVITY_ID_MAP = {
    [1168] = "Рассвет (The Dawnbreaker)",
    [1169] = "Рассвет (The Dawnbreaker)",
    [1160] = "Ара-Кара (Ara-Kara)",
    [1161] = "Ара-Кара (Ara-Kara)",
    [1162] = "Каменные Своды (The Stonevault)",
    [1163] = "Каменные Своды (The Stonevault)",
    [1164] = "Город Нитей (City of Threads)",
    [1165] = "Город Нитей (City of Threads)",
    [703]  = "Туманы Тирна Скитта (Mists of Tirna Scithe)",
    [704]  = "Туманы Тирна Скитта (Mists of Tirna Scithe)",
    [705]  = "Смертельная Тризна (The Necrotic Wake)",
    [706]  = "Смертельная Тризна (The Necrotic Wake)",
    [514]  = "Осада Боралуса (Siege of Boralus)",
    [515]  = "Осада Боралуса (Siege of Boralus)",
    [1170] = "Грим Батол (Grim Batol)",
    [1171] = "Грим Батол (Grim Batol)",
    [1282] = "Гнездовье (The Rookery)",
    [1283] = "Каменные Своды (The Stonevault)",
    [1284] = "Приорат Священного Пламени (Priory)",
    [1285] = "Город Нитей (City of Threads)",
    [1286] = "Расселина Темного Пламени (Darkflame)",
    [1288] = "Истязальня Медоваров (Cinderbrew)",
    [1512] = "Вылазки / Дельвы TWW",
}

function LH.GetDungeonAndKeyInfo(resultID, name, comment)
    local cachedTitle = LH.cachedEntryTitles and LH.cachedEntryTitles[resultID]
    local effectiveName = (cachedTitle and cachedTitle ~= "" and not cachedTitle:find("|K")) and cachedTitle or name
    local keyLvl = LH.ExtractKeyLevel(effectiveName, comment)
    local dungName = "TWW Подземелье"

    local info = C_LFGList.GetSearchResultInfo(resultID)
    local actID = info and (info.activityID or (info.activityIDs and info.activityIDs[1]))

    if actID then
        if ACTIVITY_ID_MAP[actID] then
            dungName = ACTIVITY_ID_MAP[actID]
        else
            local act = C_LFGList.GetActivityInfoTable(actID)
            if act and act.fullName then
                local clean = act.fullName:gsub(" %(Mythic Keystone%)", ""):gsub(" %(Эпохальный ключ%)", "")
                if clean and clean ~= "" then dungName = clean end
            end
        end
    end

    if (dungName == "TWW Подземелье" or not dungName) and name then
        local low = name:lower()
        for kw, realName in pairs(DUNGEON_KEYWORDS) do
            if low:find(kw) then
                dungName = realName
                break
            end
        end
    end

    return dungName, keyLvl
end

function LH.GetPlayerOwnedKeystone()
    if not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneLevel then return nil, nil end
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID and keyLevel and keyLevel > 0 then
        local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) and C_ChallengeMode.GetMapUIInfo(mapID) or "Ключ"
        return mapName, keyLevel
    end
    return nil, nil
end

-- -------------------------------------------------------------
-- Проверка синергии (Lust / Brez)
-- -------------------------------------------------------------
function LH.CheckSynergy(resultID)
    local hasLust = false
    local hasBrez = false
    local numMembers = 0

    pcall(function()
        local info = C_LFGList.GetSearchResultInfo(resultID)
        numMembers = info and info.numMembers or 0
    end)

    for i = 1, numMembers do
        local role, classFile = C_LFGList.GetSearchResultMemberInfo(resultID, i)
        if classFile then
            if LUST_CLASSES[classFile] then hasLust = true end
            if BREZ_CLASSES[classFile] then hasBrez = true end
        end
    end

    local bonus = 0
    local reasons = {}
    local myClass = select(2, UnitClass("player"))

    if not hasLust and LUST_CLASSES[myClass] then
        bonus = bonus + 20
        table.insert(reasons, "+20 (Вы даете БЛ в группу без БЛа)")
    end

    if not hasBrez and BREZ_CLASSES[myClass] then
        bonus = bonus + 15
        table.insert(reasons, "+15 (Вы даете БР в группу без БРа)")
    end

    return bonus, reasons
end

-- -------------------------------------------------------------
-- ЭВРИСТИЧЕСКАЯ ОЦЕНКА ГРУППЫ
-- -------------------------------------------------------------
function LH.EvaluateGroup(resultID)
    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info then
        return 0, "[SKIP: Нет данных]", {}, false
    end

    local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID)
    local cachedTitle = LH.cachedEntryTitles and LH.cachedEntryTitles[resultID]
    local name = (cachedTitle and cachedTitle ~= "" and not cachedTitle:find("|K")) and cachedTitle or (info.name or "Unknown")
    local comment = info.comment or ""
    local leaderName = info.leaderName or "Unknown"
    local leaderRio = info.leaderOverallDungeonScore or 0
    local numMembers = info.numMembers or 1
    local reqIlvl = info.requiredItemLevel or 0

    local cfg = LFGHeuristicsDB.config
    local myRole = LH.GetEffectiveRole()
    local breakdown = {}

    -- 1. ЖЕСТКИЙ ФИЛЬТР: Роль
    if myRole == "TANK" and memberCounts.TANK >= 1 then
        return 0, "[ОТКЛОНЕНО: Танк уже есть (1/1)]", { "Танк занят" }, false
    elseif myRole == "HEALER" and memberCounts.HEALER >= 1 then
        return 0, "[ОТКЛОНЕНО: Хил уже есть (1/1)]", { "Хил занят" }, false
    elseif myRole == "DAMAGER" and memberCounts.DAMAGER >= 3 then
        return 0, "[ОТКЛОНЕНО: Слоты ДД заполнены (3/3)]", { "Все 3 ДД слота заняты" }, false
    end

    -- 2. ЖЕСТКИЙ ФИЛЬТР: Anti-WTS
    if cfg.antiWts then
        local lowerText = string.lower(name .. " " .. comment)
        for _, badWord in ipairs(WTS_BLACKLIST) do
            if string.find(lowerText, badWord) then
                return 0, string.format("[ОТКЛОНЕНО: Реклама WTS ('%s')]", badWord), { "WTS Blacklist" }, false
            end
        end
    end

    -- 3. ЖЕСТКИЙ ФИЛЬТР: Уровень ключа
    local keyLvl = LH.ExtractKeyLevel(name, comment)
    if keyLvl == 0 then
        if cfg.minKey > 0 then
            return 0, string.format("[ОТКЛОНЕНО: Ключ M0 ниже минимума [%d..%d]]", cfg.minKey, cfg.maxKey), { "Уровень ключа M0" }, false
        end
        table.insert(breakdown, "Ключ: M0 (Mythic 0)")
    elseif keyLvl then
        if keyLvl < cfg.minKey or keyLvl > cfg.maxKey then
            return 0, string.format("[ОТКЛОНЕНО: Ключ +%d вне [%d..%d]]", keyLvl, cfg.minKey, cfg.maxKey), { "Ключ не подходит" }, false
        end
        table.insert(breakdown, string.format("Ключ: +%d", keyLvl))
    else
        table.insert(breakdown, "Ключ: Не распознан (допущен)")
    end

    -- 4. ЖЕСТКИЙ ФИЛЬТР: Минимальный состав
    if cfg.fastStartOnly and numMembers < 3 then
        return 0, string.format("[ОТКЛОНЕНО: Fast-Start (нужно 3/5+, сейчас %d/5)]", numMembers), { "Мало людей" }, false
    elseif numMembers < cfg.minMembers then
        return 0, string.format("[ОТКЛОНЕНО: Мало людей (%d/5, мин: %d)]", numMembers, cfg.minMembers), { "Мало людей" }, false
    end

    -- 5. Требование ilvl
    local myIlvl = select(2, GetAverageItemLevel()) or 0
    if reqIlvl > 0 and myIlvl < reqIlvl then
        return 0, string.format("[ОТКЛОНЕНО: Требуется ilvl %d (у вас %d)]", reqIlvl, math.floor(myIlvl)), { "Низкий ilvl" }, false
    end

    -- ---------------------------------------------------------
    -- МЯГКИЙ СКОРИНГ (Soft Scoring)
    -- ---------------------------------------------------------
    local score = 50
    table.insert(breakdown, "Базовый балл: +50")

    -- Заполненность группы
    if numMembers == 4 then
        score = score + 45
        table.insert(breakdown, "+45 (Группа 4/5 - моментальный старт!)")
    elseif numMembers == 3 then
        score = score + 30
        table.insert(breakdown, "+30 (Группа 3/5)")
    elseif numMembers == 2 then
        score = score + 15
        table.insert(breakdown, "+15 (Группа 2/5)")
    end

    -- Дефицит роли
    if numMembers >= 3 then
        if myRole == "TANK" and memberCounts.TANK == 0 then
            score = score + 25
            table.insert(breakdown, "+25 (Группа ждет именно ТАНКА)")
        elseif myRole == "HEALER" and memberCounts.HEALER == 0 then
            score = score + 20
            table.insert(breakdown, "+20 (Группа ждет именно ХИЛА)")
        end
    end

    -- Рейтинг лидера
    if leaderRio >= 2600 then
        score = score + 30
        table.insert(breakdown, string.format("+30 (Топовый лидер: %d RIO)", leaderRio))
    elseif leaderRio >= 2400 then
        score = score + 20
        table.insert(breakdown, string.format("+20 (Опытный лидер: %d RIO)", leaderRio))
    elseif leaderRio >= 2000 then
        score = score + 10
        table.insert(breakdown, string.format("+10 (Надежный лидер: %d RIO)", leaderRio))
    elseif leaderRio < cfg.minLeaderRio then
        score = score - 20
        table.insert(breakdown, string.format("-20 (Лидер ниже планки: %d < %d)", leaderRio, cfg.minLeaderRio))
    end

    -- Свежесть группы
    local age = info.age or 0
    if age <= 45 then
        score = score + 15
        table.insert(breakdown, string.format("+15 (Свежая группа: %d сек)", age))
    elseif age > 600 then
        score = score - 15
        table.insert(breakdown, string.format("-15 (Старая группа: %d сек)", age))
    end

    -- Синергия (Lust / Brez)
    local synBonus, synReasons = LH.CheckSynergy(resultID)
    if synBonus > 0 then
        score = score + synBonus
        for _, r in ipairs(synReasons) do
            table.insert(breakdown, r)
        end
    end

    local verdict = string.format("[РЕКОМЕНДОВАНО: %d б.] %s | Лидер: %s (%d RIO) | %d/5", score, name, leaderName, leaderRio, numMembers)
    return score, verdict, breakdown, true
end

-- -------------------------------------------------------------
-- Хуки системных событий WoW (Перехват LFG)
-- -------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "LFGHeuristicsEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
eventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "LFGHeuristics" or name == "KeyGroupDumper" then
            LFGHeuristicsDB = LFGHeuristicsDB or {}
            LFGHeuristicsDB.config = LFGHeuristicsDB.config or {}
            for k, v in pairs(DEFAULT_CONFIG) do
                if LFGHeuristicsDB.config[k] == nil then
                    LFGHeuristicsDB.config[k] = v
                end
            end
            LH.Log("INFO", "LFGHeuristics 1.0 ГОТОВ", "Используйте /lh для окна монитора или /lh scan для сканирования", "00e5ff")
        end

    elseif event == "PLAYER_LOGIN" then
        LH.Log("INFO", "ИГРОК В МИРЕ", string.format("Роль: %s | ilvl: %.1f", LH.GetEffectiveRole(), select(2, GetAverageItemLevel()) or 0), "ffffff")

    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
        local total, results = C_LFGList.GetSearchResults()
        local count = results and #results or 0
        LH.Log("RX", "ПОЛУЧЕНЫ РЕЗУЛЬТАТЫ LFG", string.format("Принято %d групп от сервера (всего в категории: %d)", count, total or count), "00ffaa")

        if not results or count == 0 then return end

        -- Сканируем видимый UI (ScrollBox) перед оценкой
        LH.ScanUIFrames()

        local approved = {}
        LH.lastEvaluated = {}

        for _, resID in ipairs(results) do
            local info = C_LFGList.GetSearchResultInfo(resID)
            local rawName = info and info.name or tostring(resID)
            local uiTitle = LH.cachedEntryTitles and LH.cachedEntryTitles[resID]
            local decodedName = (uiTitle and uiTitle ~= "" and not uiTitle:find("|K")) and uiTitle or LH.DecodeThroughChat(rawName)
            local rawComment = info and info.comment or ""
            local searchName = (decodedName and decodedName ~= "" and not decodedName:find("|K")) and decodedName or rawName
            local dungName, keyLvl = LH.GetDungeonAndKeyInfo(resID, searchName, rawComment)
            local keyBadge = LH.FormatKeyBadge(keyLvl)

            local score, verdict, breakdown, isEligible = LH.EvaluateGroup(resID)

            local displayName = (uiTitle and uiTitle ~= "" and not uiTitle:find("|K")) and uiTitle
                or ((decodedName and decodedName ~= "" and not decodedName:find("|K")) and decodedName or dungName)

            local entry = {
                resultID = resID,
                score = score,
                verdict = verdict,
                breakdown = breakdown,
                isEligible = isEligible,
                name = displayName,
                rawName = rawName,
                dungeon = dungName,
                keyLevel = keyLvl,
                keyBadge = keyBadge,
                info = info
            }
            table.insert(LH.lastEvaluated, entry)

            if isEligible and score > 0 then
                table.insert(approved, entry)
                local bText = table.concat(breakdown, " | ")
                LH.Log("HEUR", string.format("✓ [КЛЮЧ %s] %s | '%s' (%d б.)", keyBadge, dungName, displayName, score), bText, "00ff00")
            else
                LH.Log("HEUR", string.format("✖ [КЛЮЧ %s] %s | '%s'", keyBadge, dungName, displayName), verdict, "ff5555")
            end
        end

        table.sort(approved, function(a, b) return a.score > b.score end)

        -- Сохраняем в БД для выгрузки на диск
        LFGHeuristicsDB.lastEvaluated = LH.lastEvaluated
        LFGHeuristicsDB.approvedKeys = approved

        if #approved > 0 then
            LH.bestGroup = approved[1]
            local targetKey = LH.bestGroup.keyBadge
            local targetDung = LH.bestGroup.dungeon
            LH.Log("TX", "🎯 РЕГАЕМ КЛЮЧ #" .. targetKey, string.format("Подземелье: %s | Название: '%s' | Рейтинг: %d б. | Вызов C_LFGList.ApplyToGroup(%d)", targetDung, LH.bestGroup.name, LH.bestGroup.score, LH.bestGroup.resultID), "ffff00")
        else
            LH.bestGroup = nil
            LH.Log("INFO", "НЕТ ПОДХОДЯЩИХ КЛЮЧЕЙ", "Ни один ключ из поиска не попал в диапазон или слоты заняты", "888888")
        end

        -- Отложенное повторное сканирование визуального UI через 0.08 и 0.2 сек
        if C_Timer and C_Timer.After then
            C_Timer.After(0.08, function()
                local newCount = LH.ScanUIFrames()
                if newCount > 0 and LH.lastEvaluated then
                    local updatedAny = false
                    for _, entry in ipairs(LH.lastEvaluated) do
                        local resID = entry.resultID
                        local uiT = LH.cachedEntryTitles and LH.cachedEntryTitles[resID]
                        if uiT and uiT ~= "" and not uiT:find("|K") then
                            local k = LH.ExtractKeyLevel(uiT, "")
                            if k ~= entry.keyLevel or entry.keyBadge == "Н/Д" then
                                entry.keyLevel = k
                                entry.keyBadge = LH.FormatKeyBadge(k)
                                entry.name = uiT
                                updatedAny = true
                            end
                        end
                    end
                    if updatedAny then
                        if LH.bestGroup and (LH.bestGroup.keyBadge == "Н/Д" or not LH.bestGroup.keyLevel) then
                            local uiT = LH.cachedEntryTitles and LH.cachedEntryTitles[LH.bestGroup.resultID]
                            if uiT and uiT ~= "" and not uiT:find("|K") then
                                local k = LH.ExtractKeyLevel(uiT, "")
                                LH.bestGroup.name = uiT
                                LH.bestGroup.keyLevel = k
                                LH.bestGroup.keyBadge = LH.FormatKeyBadge(k)
                            end
                        end
                        if LFGHeuristicsDB then
                            LFGHeuristicsDB.lastEvaluated = LH.lastEvaluated
                        end
                    end
                end
            end)
        end

    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local appID, newStatus, oldStatus, groupName = ...
        groupName = groupName or tostring(appID)

        if newStatus == "invited" then
            LH.Log("ALERT", "🎉 ВАС ПРИНЯЛИ В ГРУППУ!", string.format("Группа: '%s' | Статус: INVITED", groupName), "00ff00")
            FlashClientIcon()
        elseif newStatus == "applied" then
            LH.Log("RX", "ЗАЯВКА ЗАРЕГИСТРИРОВАНА СЕРВЕРОМ", string.format("Группа: '%s' (на рассмотрении)", groupName), "00e5ff")
        elseif newStatus == "declined" then
            LH.Log("RX", "ОТКЛОНЕНО ЛИДЕРОМ ГРУППЫ", string.format("Группа: '%s' (declined)", groupName), "ff4444")
        elseif newStatus == "cancelled" then
            LH.Log("STATUS", "ЗАЯВКА ОТМЕНЕНА", string.format("Группа: '%s'", groupName), "ffaa00")
        else
            LH.Log("RX", "ОБНОВЛЕНИЕ СТАТУСА", string.format("Группа: '%s' -> %s (было: %s)", groupName, tostring(newStatus), tostring(oldStatus)), "c0c0c0")
        end
    end
end)

-- Хук функции отправки заявки C_LFGList.ApplyToGroup
if C_LFGList and C_LFGList.ApplyToGroup then
    hooksecurefunc(C_LFGList, "ApplyToGroup", function(resultID, isTank, isHeal, isDps)
        local info = C_LFGList.GetSearchResultInfo(resultID)
        local name = info and info.name or tostring(resultID)
        local rStr = isTank and "TANK" or (isHeal and "HEALER" or "DAMAGER")
        LH.Log("TX", "ВЫЗОВ API: ApplyToGroup", string.format("Группа [ID:%d] '%s' | Роль: %s | Tank=%s Heal=%s Dps=%s", resultID, name, rStr, tostring(isTank), tostring(isHeal), tostring(isDps)), "00e5ff")
    end)
end

-- Хук функции поиска C_LFGList.Search
if C_LFGList and C_LFGList.Search then
    hooksecurefunc(C_LFGList, "Search", function(categoryID, filterString)
        LH.Log("TX", "ВЫЗОВ API: Search", string.format("Категория: %s | Фильтр: '%s'", tostring(categoryID), tostring(filterString or "")), "00e5ff")
    end)
end

-- -------------------------------------------------------------
-- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС (/lh или /heur)
-- -------------------------------------------------------------
local uiFrame = nil

function LH.ToggleUI()
    if not uiFrame then
        LH.CreateUI()
    end
    if uiFrame:IsShown() then
        uiFrame:Hide()
    else
        LH.UpdateUI()
        uiFrame:Show()
    end
end

function LH.CreateUI()
    if uiFrame then return end

    uiFrame = CreateFrame("Frame", "LFGHeuristicsFrame", UIParent, "BackdropTemplate")
    uiFrame:SetSize(660, 460)
    uiFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    uiFrame:SetMovable(true)
    uiFrame:EnableMouse(true)
    uiFrame:RegisterForDrag("LeftButton")
    uiFrame:SetScript("OnDragStart", uiFrame.StartMoving)
    uiFrame:SetScript("OnDragStop", uiFrame.StopMovingOrSizing)
    uiFrame:SetFrameStrata("DIALOG")
    uiFrame:SetClampedToScreen(true)

    -- Киберпанк тема
    uiFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    uiFrame:SetBackdropColor(0.06, 0.07, 0.09, 0.96)
    uiFrame:SetBackdropBorderColor(0.0, 0.9, 1.0, 0.9)

    -- Заголовок
    local title = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 14, -12)
    title:SetText("|cff00e5ff📡 LFG Heuristics|r |cffffffff(Монитор трафика и эвристики)|r")

    local subTitle = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subTitle:SetText("|cff8c92a4Мгновенный перехват отправки [TX], ответов [RX] и скоринга групп [⚖️]|r")

    local closeBtn = CreateFrame("Button", nil, uiFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", uiFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() uiFrame:Hide() end)

    -- Панель кнопок управления
    local btnScan = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    btnScan:SetSize(160, 26)
    btnScan:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 14, -46)
    btnScan:SetText("🔍 Сканировать LFG")
    btnScan:SetScript("OnClick", function()
        LH.Log("TX", "РУЧНОЙ ЗАПРОС LFG", "C_LFGList.Search(2) отправлен", "00e5ff")
        pcall(C_LFGList.Search, 2)
    end)

    local btnRole = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    btnRole:SetSize(140, 26)
    btnRole:SetPoint("LEFT", btnScan, "RIGHT", 8, 0)
    uiFrame.btnRole = btnRole

    local roles = { "AUTO", "TANK", "HEALER", "DAMAGER" }
    local roleNames = {
        ["AUTO"] = "Роль: Авто",
        ["TANK"] = "Роль: 🛡️ Танк",
        ["HEALER"] = "Роль: 💚 Хил",
        ["DAMAGER"] = "Роль: ⚔️ ДД"
    }

    local function RefreshRoleBtn()
        local r = LFGHeuristicsDB.config.role or "AUTO"
        btnRole:SetText(roleNames[r] or r)
    end
    RefreshRoleBtn()

    btnRole:SetScript("OnClick", function()
        local cur = LFGHeuristicsDB.config.role or "AUTO"
        local nextIdx = 1
        for i, val in ipairs(roles) do
            if val == cur then
                nextIdx = (i % #roles) + 1
                break
            end
        end
        LFGHeuristicsDB.config.role = roles[nextIdx]
        RefreshRoleBtn()
        LH.Log("INFO", "СМЕНА РОЛИ ЭВРИСТИКИ", "Текущая роль: " .. roles[nextIdx], "00e5ff")
    end)

    local btnClear = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    btnClear:SetSize(110, 26)
    btnClear:SetPoint("LEFT", btnRole, "RIGHT", 8, 0)
    btnClear:SetText("Очистить")
    btnClear:SetScript("OnClick", function()
        LH.trafficLogs = {}
        LH.UpdateUI()
    end)

    -- Чекбокс вывода в чат
    local cbEcho = CreateFrame("CheckButton", nil, uiFrame, "UICheckButtonTemplate")
    cbEcho:SetPoint("LEFT", btnClear, "RIGHT", 12, 0)
    cbEcho.text = cbEcho:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbEcho.text:SetPoint("LEFT", cbEcho, "RIGHT", 4, 1)
    cbEcho.text:SetText("Вывод в чат")
    cbEcho:SetChecked(LFGHeuristicsDB.config.chatEcho ~= false)
    cbEcho:SetScript("OnClick", function(self)
        LFGHeuristicsDB.config.chatEcho = self:GetChecked()
    end)

    -- Область сообщений лога (ScrollingMessageFrame)
    local msgBox = CreateFrame("Frame", nil, uiFrame, "BackdropTemplate")
    msgBox:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 14, -80)
    msgBox:SetPoint("BOTTOMRIGHT", uiFrame, "BOTTOMRIGHT", -14, 14)
    msgBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    msgBox:SetBackdropColor(0.03, 0.04, 0.05, 0.98)
    msgBox:SetBackdropBorderColor(0.2, 0.25, 0.35, 0.8)

    local msgFrame = CreateFrame("ScrollingMessageFrame", "LFGHeuristicsMsgFrame", msgBox)
    msgFrame:SetPoint("TOPLEFT", msgBox, "TOPLEFT", 8, -8)
    msgFrame:SetPoint("BOTTOMRIGHT", msgBox, "BOTTOMRIGHT", -8, 8)
    msgFrame:SetFontObject(ChatFontNormal)
    msgFrame:SetJustifyH("LEFT")
    msgFrame:SetFading(false)
    msgFrame:SetMaxLines(800)
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)
    uiFrame.msgFrame = msgFrame
end

function LH.UpdateUI()
    if not uiFrame or not uiFrame:IsShown() then return end
    local mf = uiFrame.msgFrame
    if not mf then return end

    mf:Clear()
    for i = #LH.trafficLogs, 1, -1 do
        local e = LH.trafficLogs[i]
        local badge = ""
        if e.tag == "TX" then
            badge = "|cff00e5ff[TX ➔]|r"
        elseif e.tag == "RX" then
            badge = "|cff00ffaa[RX 🠔]|r"
        elseif e.tag == "HEUR" then
            badge = "|cffffff00[⚖️ ЭВР]|r"
        elseif e.tag == "ALERT" then
            badge = "|cffff00ff[🔔 ИНВ]|r"
        else
            badge = "|cff8c92a4[INFO]|r"
        end

        local line = string.format("|cff888888%s|r %s |cff%s%s|r", e.time, badge, e.color, e.title)
        if e.details and e.details ~= "" then
            line = line .. " |cffcccccc" .. e.details .. "|r"
        end
        mf:AddMessage(line)
    end
end

-- -------------------------------------------------------------
-- АНАЛИЗАТОР ГРУППЫ ПОД КУРСОРОМ МЫШИ (Mouse-over Heuristic)
-- -------------------------------------------------------------
LH.currentHoveredResultID = nil

function LH.GetResultIDFromMouse()
    if LH.currentHoveredResultID then
        return LH.currentHoveredResultID
    end

    local focus = (GetMouseFoci and GetMouseFoci()[1]) or (GetMouseFocus and GetMouseFocus())
    local curr = focus
    while curr do
        if curr.resultID then
            return curr.resultID
        end
        if curr.GetParent then
            curr = curr:GetParent()
        else
            break
        end
    end

    return nil
end

function LH.InspectMouseFocus()
    local resID = LH.GetResultIDFromMouse()
    if not resID then
        if GameTooltip:IsShown() then
            local lines = {}
            for i = 1, GameTooltip:NumLines() do
                local left = _G["GameTooltipTextLeft" .. i]
                local right = _G["GameTooltipTextRight" .. i]
                local lText = left and left:GetText() or ""
                local rText = right and right:GetText() or ""
                if lText ~= "" or rText ~= "" then
                    table.insert(lines, lText .. (rText ~= "" and (" | " .. rText) or ""))
                end
            end
            if #lines > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00e5ff[LFGHeuristics]|r Данные из тултипа под мышкой:")
                for _, line in ipairs(lines) do
                    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00" .. line .. "|r")
                end
                return
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00e5ff[LFGHeuristics]|r Наведите курсор мыши на строку группы в списке поиска подземелий!")
        return
    end

    local score, verdict, breakdown, isEligible = LH.EvaluateGroup(resID)
    local info = C_LFGList.GetSearchResultInfo(resID)
    local rawName = info and info.name or tostring(resID)
    local decodedName = LH.DecodeThroughChat(rawName)
    local rawComment = info and info.comment or ""
    local dungName, keyLvl = LH.GetDungeonAndKeyInfo(resID, decodedName, rawComment)
    local keyBadge = keyLvl and string.format("+%d", keyLvl) or "Н/Д"

    local leaderName = info and info.leaderName or "Н/Д"
    local leaderRio = (info and info.leaderOverallDungeonScore) or 0
    local numMembers = info and info.numMembers or 1

    local col = isEligible and "|cff00ff00" or "|cffff4444"
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[LFGHeuristics]|r === ГРУППА ПОД МЫШКОЙ (#%d) ===", resID))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  Подземелье: |cffffff00%s|r | Ключ: |cff00ffaa%s|r", dungName, keyBadge))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  Лидер: |cffffff00%s|r (%d RIO) | Состав: |cff00e5ff%d/5|r", leaderName, leaderRio, numMembers))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  Оценка эвристики: %s%d б.|r - %s", col, score, verdict))
    for _, b in ipairs(breakdown) do
        DEFAULT_CHAT_FRAME:AddMessage("    |cff8c92a4• " .. b .. "|r")
    end

    LFGHeuristicsDB.mouseHoveredGroup = {
        resultID = resID,
        name = decodedName ~= "" and decodedName or dungName,
        rawName = rawName,
        dungeon = dungName,
        keyLevel = keyLvl,
        keyBadge = keyBadge,
        leaderName = leaderName,
        leaderRio = leaderRio,
        numMembers = numMembers,
        score = score,
        verdict = verdict,
        breakdown = breakdown,
        isEligible = isEligible,
        info = info,
        timestamp = time()
    }
end

LH.cachedEntryTitles = LH.cachedEntryTitles or {}
LH.cachedEntryActivities = LH.cachedEntryActivities or {}

local function GetBtnResID(btn)
    if not btn then return nil end
    if btn.resultID then return btn.resultID end
    if btn.resID then return btn.resID end
    if btn.GetElementData then
        local d = btn:GetElementData()
        if type(d) == "number" then return d end
        if type(d) == "table" then return d.resultID or d.searchResultID or d.id or d.res or d.resID end
    end
    if btn.elementData then
        local d = btn.elementData
        if type(d) == "number" then return d end
        if type(d) == "table" then return d.resultID or d.searchResultID or d.id or d.res or d.resID end
    end
    return nil
end

function LH.ScanUIFrames()
    LH.cachedEntryTitles = LH.cachedEntryTitles or {}
    LH.cachedEntryActivities = LH.cachedEntryActivities or {}
    local count = 0

    local scrollBox = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.ScrollBox
    if scrollBox then
        if scrollBox.ForEachFrame then
            scrollBox:ForEachFrame(function(btn)
                local resID = GetBtnResID(btn)
                if resID then
                    local t = btn.Name and btn.Name:GetText()
                    local a = btn.ActivityName and btn.ActivityName:GetText()
                    if t and t ~= "" and not t:find("|K") and not t:find("[Kk]q%d+[kK]") then
                        LH.cachedEntryTitles[resID] = t
                        count = count + 1
                    end
                    if a and a ~= "" then
                        LH.cachedEntryActivities[resID] = a
                    end
                end
            end)
        end

        if count == 0 and scrollBox.GetFrames then
            local frames = scrollBox:GetFrames() or {}
            for _, btn in ipairs(frames) do
                local resID = GetBtnResID(btn)
                if resID then
                    local t = btn.Name and btn.Name:GetText()
                    local a = btn.ActivityName and btn.ActivityName:GetText()
                    if t and t ~= "" and not t:find("|K") and not t:find("[Kk]q%d+[kK]") then
                        LH.cachedEntryTitles[resID] = t
                        count = count + 1
                    end
                    if a and a ~= "" then
                        LH.cachedEntryActivities[resID] = a
                    end
                end
            end
        end
    end

    local scrollFrame = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.ScrollFrame
    if count == 0 and scrollFrame and scrollFrame.buttons then
        for _, btn in ipairs(scrollFrame.buttons) do
            local resID = GetBtnResID(btn)
            if resID then
                local t = btn.Name and btn.Name:GetText()
                local a = btn.ActivityName and btn.ActivityName:GetText()
                if t and t ~= "" and not t:find("|K") and not t:find("[Kk]q%d+[kK]") then
                    LH.cachedEntryTitles[resID] = t
                    count = count + 1
                end
                if a and a ~= "" then
                    LH.cachedEntryActivities[resID] = a
                end
            end
        end
    end

    -- Сохраняем в SavedVariables
    if LFGHeuristicsDB then
        LFGHeuristicsDB.cachedTitles = LH.cachedEntryTitles
    end

    -- Синхронизируем с lastEvaluated
    if LH.lastEvaluated and count > 0 then
        for _, item in ipairs(LH.lastEvaluated) do
            local resID = item.resultID
            local t = LH.cachedEntryTitles[resID]
            if t and t ~= "" and not t:find("|K") then
                local k = LH.ExtractKeyLevel(t, "")
                if k ~= nil then
                    item.keyLevel = k
                    item.keyBadge = LH.FormatKeyBadge(k)
                    item.name = t
                end
            end
        end
        if LFGHeuristicsDB then
            LFGHeuristicsDB.lastEvaluated = LH.lastEvaluated
        end
    end

    return count
end

-- Хуки тултипа и списка LFG
local function HookLFGBrowsing()
    if LH.isTooltipHooked then return end

    if LFGListSearchPanel_UpdateResultList then
        hooksecurefunc("LFGListSearchPanel_UpdateResultList", function(panel)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, LH.ScanUIFrames)
            else
                LH.ScanUIFrames()
            end
        end)
    end

    if LFGListSearchEntry_Update then
        hooksecurefunc("LFGListSearchEntry_Update", function(entry)
            if not entry then return end
            local resID = entry.resultID
            if resID then
                local t = entry.Name and entry.Name:GetText()
                local a = entry.ActivityName and entry.ActivityName:GetText()
                if t and t ~= "" and not t:find("|K") and not t:find("[Kk]q%d+[kK]") then
                    LH.cachedEntryTitles[resID] = t
                    if LH.lastEvaluated then
                        for _, item in ipairs(LH.lastEvaluated) do
                            if item.resultID == resID then
                                local k = LH.ExtractKeyLevel(t, "")
                                if k then
                                    item.keyLevel = k
                                    item.keyBadge = string.format("+%d", k)
                                    item.name = t
                                end
                                break
                            end
                        end
                    end
                end
                if a and a ~= "" then
                    LH.cachedEntryActivities[resID] = a
                end
            end
        end)
    end

    if LFGListUtil_SetSearchEntryTooltip then
        hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", function(tooltip, resultID)
            if not tooltip or not resultID then return end
            LH.currentHoveredResultID = resultID

            -- Захватываем заголовок из GameTooltipTextLeft1
            local tipTitle = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
            if tipTitle and tipTitle ~= "" and not tipTitle:find("|K") and not tipTitle:find("[Kk]q%d+[kK]") then
                LH.cachedEntryTitles[resultID] = tipTitle
            end

            local score, verdict, breakdown, isEligible = LH.EvaluateGroup(resultID)
            local info = C_LFGList.GetSearchResultInfo(resultID)
            local rawName = info and info.name or ""
            local decodedName = LH.DecodeThroughChat(rawName)
            local rawComment = info and info.comment or ""
            local dungName, keyLvl = LH.GetDungeonAndKeyInfo(resultID, decodedName, rawComment)
            local keyBadge = keyLvl and string.format("+%d", keyLvl) or "Н/Д"

            tooltip:AddLine(" ")
            tooltip:AddLine("|cff00e5ff════════ [LFGHeuristics] ════════|r")
            local scoreCol = isEligible and "|cff00ff00" or "|cffff4444"
            tooltip:AddDoubleLine(string.format("Эвристика: %s%d баллов|r", scoreCol, score), isEligible and "|cff00ff00[РЕКОМЕНДОВАНО]|r" or "|cffff4444[ОТКЛОНЕНО]|r")
            tooltip:AddLine(verdict)
            for _, b in ipairs(breakdown) do
                tooltip:AddLine("  |cff8c92a4• " .. b .. "|r")
            end
            tooltip:AddLine("|cff888888Нажмите /lh mouse для отчета в чат|r")
            tooltip:Show()
        end)
        LH.isTooltipHooked = true
    end

    if LFGListSearchEntry_OnEnter then
        hooksecurefunc("LFGListSearchEntry_OnEnter", function(self)
            if self and self.resultID then
                LH.currentHoveredResultID = self.resultID
            end
        end)
    end
end

-- -------------------------------------------------------------
-- Слеш-команды (/lh, /heur, /эвр)
-- -------------------------------------------------------------
local function SlashHandler(msg)
    local cmd = string.lower(msg or "")

    if cmd == "scan" then
        LH.Log("TX", "РУЧНОЕ СКАНИРОВАНИЕ LFG", "Отправка C_LFGList.Search(2)...", "00e5ff")
        pcall(C_LFGList.Search, 2)

    elseif cmd == "mouse" or cmd == "hover" or cmd == "мышь" then
        LH.InspectMouseFocus()

    elseif cmd == "chat" or cmd == "echo" then
        LFGHeuristicsDB.config.chatEcho = not LFGHeuristicsDB.config.chatEcho
        local state = LFGHeuristicsDB.config.chatEcho and "|cff00ff00ВКЛЮЧЕН|r" or "|cffff4444ВЫКЛЮЧЕН|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00e5ff[LFGHeuristics]|r Вывод в чат: " .. state)

    elseif cmd:match("^role%s+(%w+)") then
        local r = cmd:match("^role%s+(%w+)"):upper()
        if r == "TANK" or r == "HEALER" or r == "DAMAGER" or r == "AUTO" then
            LFGHeuristicsDB.config.role = r
            LH.Log("INFO", "СМЕНА РОЛИ", "Роль установлена: " .. r, "00e5ff")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00e5ff[LFGHeuristics]|r Доступные роли: tank, heal, dps, auto")
        end

    elseif cmd:match("^min%s+(%d+)") then
        local m = tonumber(cmd:match("^min%s+(%d+)"))
        if m then
            LFGHeuristicsDB.config.minKey = m
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[LFGHeuristics]|r Минимальный ключ установлен: |cff00ff00+%d|r", m))
        end

    elseif cmd:match("^max%s+(%d+)") then
        local m = tonumber(cmd:match("^max%s+(%d+)"))
        if m then
            LFGHeuristicsDB.config.maxKey = m
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[LFGHeuristics]|r Максимальный ключ установлен: |cff00ff00+%d|r", m))
        end

    elseif cmd:match("^range%s+(%d+)%s+(%d+)") then
        local k1, k2 = cmd:match("^range%s+(%d+)%s+(%d+)")
        k1, k2 = tonumber(k1), tonumber(k2)
        if k1 and k2 then
            LFGHeuristicsDB.config.minKey = math.min(k1, k2)
            LFGHeuristicsDB.config.maxKey = math.max(k1, k2)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[LFGHeuristics]|r Диапазон ключей установлен: |cff00ff00[+%d .. +%d]|r", LFGHeuristicsDB.config.minKey, LFGHeuristicsDB.config.maxKey))
        end

    elseif cmd == "keys" then
        LH.ScanUIFrames()

        local liveList = {}
        local scrollBox = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.ScrollBox
        if scrollBox and scrollBox.ForEachFrame then
            scrollBox:ForEachFrame(function(btn)
                local resID = GetBtnResID(btn)
                local title = btn.Name and btn.Name:GetText() or ""
                local act = btn.ActivityName and btn.ActivityName:GetText() or ""
                if resID and title ~= "" and not title:find("|K") and not title:find("[Kk]q%d+[kK]") then
                    LH.cachedEntryTitles[resID] = title
                end
                if resID and act ~= "" then
                    LH.cachedEntryActivities[resID] = act
                end
                if title ~= "" or act ~= "" or resID then
                    local effTitle = (title ~= "" and not title:find("|K")) and title or (resID and LH.cachedEntryTitles[resID]) or ""
                    local dungName, k = LH.GetDungeonAndKeyInfo(resID or 0, effTitle, "")
                    if (dungName == "TWW Подземелье" or not dungName) and act ~= "" then
                        dungName = act:gsub(" %(эпохальный ключ%)", ""):gsub(" %(эпохальный режим%)", ""):gsub(" %(Mythic Keystone%)", "")
                    end
                    local score, verdict, breakdown, isEligible = 0, "", {}, true
                    if resID then
                        score, verdict, breakdown, isEligible = LH.EvaluateGroup(resID)
                    end
                    table.insert(liveList, {
                        resultID = resID or 0,
                        score = score,
                        verdict = verdict,
                        breakdown = breakdown,
                        isEligible = isEligible,
                        name = (effTitle ~= "") and effTitle or dungName,
                        dungeon = dungName,
                        keyLevel = k,
                        keyBadge = LH.FormatKeyBadge(k)
                    })
                end
            end)
        end

        local displayList = (#liveList > 0) and liveList or (LH.lastEvaluated or {})

        local myMap, myLvl = LH.GetPlayerOwnedKeystone()
        if myLvl then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[LFGHeuristics]|r |cff00ffaaВаш ключ в сумке:|r %s (+%d)", myMap, myLvl))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00e5ff[LFGHeuristics]|r В сумке нет эпохального ключа (ищем чужие группы).")
        end

        local count = #displayList
        local cfg = LFGHeuristicsDB.config
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[LFGHeuristics]|r Список ключей на экране LFG (всего %d, фильтр: +%d..+%d):", count, cfg.minKey or 2, cfg.maxKey or 20))
        for idx, item in ipairs(displayList) do
            if idx <= 10 then
                local col = item.isEligible and "|cff00ff00" or "|cffff6666"
                local status = item.isEligible and "✓" or "✖"
                local targetMarker = (idx == 1 and item.isEligible and item.score > 0) and " |cffffff00◀ РЕГАЕМ!|r" or ""
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  #%d %s |cffffff00[КЛЮЧ %s]|r %s %s(%d б.)|r - '%s'%s", idx, status, item.keyBadge or "Н/Д", item.dungeon or "", col, item.score, item.name, targetMarker))
            end
        end

    elseif cmd == "probe" then
        local scrollBox = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.ScrollBox
        if not scrollBox then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PROBE] ScrollBox не найден!|r")
            return
        end

        local sampleBtn = nil
        local allBtns = {}
        if scrollBox.ForEachFrame then
            scrollBox:ForEachFrame(function(btn)
                table.insert(allBtns, btn)
                if not sampleBtn then sampleBtn = btn end
            end)
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[PROBE]|r Найдено кнопок в ScrollBox: %d", #allBtns))
        if sampleBtn then
            local resID = GetBtnResID(sampleBtn)
            local nameText = sampleBtn.Name and sampleBtn.Name:GetText() or "nil"
            local actText = sampleBtn.ActivityName and sampleBtn.ActivityName:GetText() or "nil"
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  sampleBtn: resID=%s", tostring(resID)))
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  sampleBtn.Name:GetText() = '%s'", tostring(nameText)))
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  sampleBtn.ActivityName:GetText() = '%s'", tostring(actText)))

            -- Все текстовые регионы на кнопке
            if sampleBtn.GetRegions then
                local regions = { sampleBtn:GetRegions() }
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  Всего регионов на кнопке: %d", #regions))
                for i, r in ipairs(regions) do
                    if r.GetText then
                        local txt = r:GetText()
                        if txt and txt ~= "" then
                            DEFAULT_CHAT_FRAME:AddMessage(string.format("    Region[%d] (FontString): '%s'", i, tostring(txt)))
                        end
                    end
                end
            end

            -- 1. Байты nameText в Lua (доказательство K-String)
            local hexDump = ""
            for b = 1, math.min(#nameText, 24) do
                local byteVal = string.byte(nameText, b)
                local charVal = (byteVal >= 32 and byteVal <= 126) and string.char(byteVal) or "."
                hexDump = hexDump .. string.format("%02X[%s] ", byteVal, charVal)
            end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  nameText len=%d bytes: %s", #nameText, hexDump))

            -- 2. ScrollingMessageFrame:GetMessageInfo(1)
            local smf = CreateFrame("ScrollingMessageFrame", nil, UIParent)
            smf:SetMaxLines(5)
            smf:AddMessage(nameText)
            local smfMsg = smf:GetMessageInfo(1)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  SMF:GetMessageInfo(1) = '%s'", tostring(smfMsg)))

            -- 3. EditBox:GetText()
            local eb = CreateFrame("EditBox", nil, UIParent)
            eb:SetText(nameText)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  EditBox:GetText() = '%s'", tostring(eb:GetText())))

            -- 4. C_LFGList SearchResultInfo поля
            if resID and C_LFGList and C_LFGList.GetSearchResultInfo then
                local sInfo = C_LFGList.GetSearchResultInfo(resID)
                if sInfo then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("  sInfo: comment='%s', voice='%s', leader='%s'", tostring(sInfo.comment), tostring(sInfo.voiceChat), tostring(sInfo.leaderName)))
                end
            end

            -- 5. BattleNet тест если это K-String
            local kid = tostring(nameText):match("|K[a-z](%d+)|k")
            if kid then
                local nid = tonumber(kid)
                local bnAcc = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(nid)
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  BattleNet.GetAccountInfoByID(%d) = %s", nid, tostring(bnAcc)))
            end
        end

        if GameTooltip:IsShown() and GameTooltipTextLeft1 then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  GameTooltipTextLeft1 = '%s'", tostring(GameTooltipTextLeft1:GetText())))
            if GameTooltipTextLeft2 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  GameTooltipTextLeft2 = '%s'", tostring(GameTooltipTextLeft2:GetText())))
            end
        end

    elseif cmd == "debug" then
        local scrollBox = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.ScrollBox
        local framesCount = 0
        local sampleBtn = nil
        if scrollBox and scrollBox.ForEachFrame then
            scrollBox:ForEachFrame(function(btn)
                framesCount = framesCount + 1
                if not sampleBtn then sampleBtn = btn end
            end)
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00e5ff[LFGHeuristics]|r DEBUG: Всего фреймов в ScrollBox=%d", framesCount))
        if sampleBtn then
            local rID = sampleBtn.resultID
            local elData = sampleBtn.GetElementData and sampleBtn:GetElementData()
            local elType = type(elData)
            local elStr = (elType == "number" and tostring(elData)) or (elType == "table" and ("table(res=" .. tostring(elData.resultID or elData.id or elData.searchResultID) .. ")")) or elType
            local t = sampleBtn.Name and sampleBtn.Name:GetText()
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  Sample: resultID=%s, elementData=%s, Name:GetText()='%s'", tostring(rID), elStr, tostring(t)))
        end

        -- Тест chatDecoderFrame:GetMessageInfo
        local testMsg = "|Kq93|k"
        chatDecoderFrame:Clear()
        chatDecoderFrame:AddMessage(testMsg)
        local nMsgs = chatDecoderFrame.GetNumMessages and chatDecoderFrame:GetNumMessages() or 0
        local readBack = (nMsgs > 0 and chatDecoderFrame.GetMessageInfo) and chatDecoderFrame:GetMessageInfo(nMsgs) or "nil"
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Decoder: NumMsgs=%d, GetMessageInfo='%s'", nMsgs, tostring(readBack)))

        -- Тест ChatFrame1:GetMessageInfo
        local cfNum = DEFAULT_CHAT_FRAME.GetNumMessages and DEFAULT_CHAT_FRAME:GetNumMessages() or 0
        local cfLast = (cfNum > 0 and DEFAULT_CHAT_FRAME.GetMessageInfo) and DEFAULT_CHAT_FRAME:GetMessageInfo(cfNum) or "nil"
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  ChatFrame1: NumMsgs=%d, LastMsg='%s'", cfNum, tostring(cfLast):sub(1, 60)))

        LFGHeuristicsDB.debugTest = {
            framesCount = framesCount,
            decoderMsgs = nMsgs,
            decoderRead = tostring(readBack),
            cfLast = tostring(cfLast),
            time = time()
        }

    elseif cmd == "dump" or cmd == "log" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00e5ff[LFGHeuristics]|r === ПОСЛЕДНИЙ ДАМП ЭВРИСТИКИ === (Всего: " .. #LH.lastEvaluated .. ")")
        for i, item in ipairs(LH.lastEvaluated) do
            if i <= 10 then
                local col = item.isEligible and "|cff00ff00" or "|cffff4444"
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%s#%d [%d б.]|r %s", col, i, item.score, item.verdict))
                for _, b in ipairs(item.breakdown) do
                    DEFAULT_CHAT_FRAME:AddMessage("   |cff8c92a4• " .. b .. "|r")
                end
            end
        end

    else
        LH.ToggleUI()
    end
end

SLASH_LFGHEURISTICS1 = "/lh"
SLASH_LFGHEURISTICS2 = "/heur"
SLASH_LFGHEURISTICS3 = "/эвр"
SlashCmdList["LFGHEURISTICS"] = SlashHandler

pcall(HookLFGBrowsing)
