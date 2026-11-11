-- =============================================================
-- HELLSING P2P HEURISTIC TESTER v2.2
-- Автономный модуль тестирования и эвристики сопряжения клиентов WoW
-- Совместимость: WoW 12.0.7 Midnight / The War Within
-- Префикс протокола: "KAR_SYNC"
-- =============================================================

local ADDON_NAME = "KAR_P2P_Tester"
local COMM_PREFIX = "KAR_SYNC"
local PROTOCOL_VER = "2.2"

KAR_P2P = {
    state = "IDLE", -- "IDLE", "WAIT_ACK", "PAIRED", "TRANSFERRING"
    partner = nil,
    sessionID = nil,
    hsStartTime = 0,
    txCount = 0,
    rxCount = 0,
    logHistory = {},
    autoAccept = false,
    blockedPartners = {},
}

-- Глобальная база настроек
KAR_P2P_TesterDB = KAR_P2P_TesterDB or {
    autoAccept = false,
    lastPartner = "",
    mutedPlayers = {},
}

-- -------------------------------------------------------------
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- -------------------------------------------------------------
local function GetFormattedTime()
    local s = date("%H:%M:%S")
    local ms = math.floor((GetTime() % 1) * 1000)
    return string.format("%s.%03d", s, ms)
end

local function CleanName(name)
    if not name then return "" end
    local clean = string.match(name, "([^-]+)") or name
    clean = clean:gsub("%s+", "")
    return clean
end

-- -------------------------------------------------------------
-- СЕТЕВОЙ МОДУЛЬ (TRANSMIT & RECEIVE)
-- -------------------------------------------------------------
local function GetSendAddonFunc()
    if C_ChatInfo then
        if C_ChatInfo.SendAddonMessage then return C_ChatInfo.SendAddonMessage end
        if C_ChatInfo.SendAddOnMessage then return C_ChatInfo.SendAddOnMessage end
    end
    if SendAddonMessage then return SendAddonMessage end
    if SendAddOnMessage then return SendAddOnMessage end
    return nil
end

local function SendCommPacket(msg, target)
    if not target or target == "" then
        KAR_P2P.AddLog("ERROR", "Цель отправки не указана!", 0)
        return false
    end

    local cleanTarget = CleanName(target)
    local byteLen = #msg
    local mtuStatus = (byteLen <= 255) and string.format("|cff00ff00[MTU OK: %db/255b]|r", byteLen) or string.format("|cffff0000[MTU DROP: %db > 255b]|r", byteLen)

    local sendFunc = GetSendAddonFunc()
    if not sendFunc then
        KAR_P2P.AddLog("ERROR", "API SendAddonMessage не найдено в клиенте WoW!", byteLen)
        return false
    end

    local ok, res = pcall(sendFunc, COMM_PREFIX, msg, "WHISPER", cleanTarget)
    local resCode = tonumber(res)
    local isSuccess = ok and (resCode == nil or resCode == 0 or res == true)

    if isSuccess then
        KAR_P2P.txCount = KAR_P2P.txCount + 1
        KAR_P2P.AddLog("TX", string.format("-> %s | %s | %s", cleanTarget, msg, mtuStatus), byteLen)
        KAR_P2P.UpdateHUD()
        return true
    else
        local errDetail = not ok and tostring(res) or string.format("Код Blizzard: %s", tostring(res))
        KAR_P2P.AddLog("ERROR", string.format("Сбой отправки на %s! (%s)", cleanTarget, errDetail), byteLen)
        return false
    end
end

-- -------------------------------------------------------------
-- ДИАГНОСТИЧЕСКИЙ ЛОГ ТЕЛЕМЕТРИИ
-- -------------------------------------------------------------
function KAR_P2P.AddLog(dir, text, bytes)
    local tStamp = GetFormattedTime()
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
    table.insert(KAR_P2P.logHistory, entry)
    if #KAR_P2P.logHistory > 200 then
        table.remove(KAR_P2P.logHistory, 1)
    end

    if KAR_P2P.logBox then
        local fullText = table.concat(KAR_P2P.logHistory, "\n")
        KAR_P2P.logBox:SetText(fullText)
        KAR_P2P.logBox:SetCursorPosition(#fullText)
    end
end

-- -------------------------------------------------------------
-- КОМАНДЫ СОПРЯЖЕНИЯ (P2P WORKFLOW)
-- -------------------------------------------------------------
function KAR_P2P.RequestHandshake(targetName)
    local target = CleanName(targetName)
    if target == "" then
        KAR_P2P.AddLog("ERROR", "Введите ник напарника для сопряжения!", 0)
        return
    end

    local myName = CleanName(UnitName("player"))
    if target:lower() == myName:lower() then
        KAR_P2P.AddLog("ERROR", "Нельзя сопрягаться с самим собой!", 0)
        return
    end

    local sessID = tostring(math.random(100000, 999999))
    KAR_P2P.state = "WAIT_ACK"
    KAR_P2P.partner = target
    KAR_P2P.sessionID = sessID
    KAR_P2P.hsStartTime = GetTime()

    if KAR_P2P_TesterDB then KAR_P2P_TesterDB.lastPartner = target end

    local reqFlag = "MANUAL"
    local pkt = string.format("HS_REQ:%s:%s:%s:%s", sessID, PROTOCOL_VER, myName, reqFlag)
    KAR_P2P.AddLog("STATE", string.format("Инициализация рукопожатия с |cffffff00%s|r [Флаг: %s] (Сессия: #%s)...", target, reqFlag, sessID), #pkt)
    SendCommPacket(pkt, target)
    KAR_P2P.UpdateHUD()

    C_Timer.After(20, function()
        if KAR_P2P.state == "WAIT_ACK" and KAR_P2P.partner == target then
            KAR_P2P.state = "IDLE"
            KAR_P2P.partner = nil
            KAR_P2P.AddLog("ERROR", string.format("Таймаут (20с): напарник %s не ответил на рукопожатие.", target), 0)
            KAR_P2P.UpdateHUD()
        end
    end)
end

function KAR_P2P.AcceptHandshake(senderName, sessID)
    local target = CleanName(senderName)
    local myName = CleanName(UnitName("player"))

    KAR_P2P.state = "PAIRED"
    KAR_P2P.partner = target
    KAR_P2P.sessionID = sessID
    if KAR_P2P_TesterDB then KAR_P2P_TesterDB.lastPartner = target end

    local pkt = string.format("HS_ACK:%s:%s:%s", sessID, PROTOCOL_VER, myName)
    SendCommPacket(pkt, target)

    KAR_P2P.AddLog("HEUR", string.format("Рукопожатие ПРИНЯТО! Успешное сопряжение с |cffffff00%s|r.", target), #pkt)
    PlaySound(888) -- Quest complete sound
    KAR_P2P.UpdateHUD()
end

function KAR_P2P.DeclineHandshake(senderName, sessID, reason)
    local target = CleanName(senderName)
    reason = reason or "DECLINED_MANUAL"
    local pkt = string.format("HS_REJ:%s:%s", sessID or "0", reason)
    SendCommPacket(pkt, target)
    KAR_P2P.AddLog("HEUR", string.format("Рукопожатие с %s отклонено (Причина: %s).", target, reason), #pkt)
end

function KAR_P2P.MuteAndDecline(senderName, sessID)
    local target = CleanName(senderName)
    if KAR_P2P_TesterDB then
        if not KAR_P2P_TesterDB.mutedPlayers then KAR_P2P_TesterDB.mutedPlayers = {} end
        KAR_P2P_TesterDB.mutedPlayers[target:lower()] = true
    end
    local pkt = string.format("HS_REJ:%s:MUTED", sessID or "0")
    SendCommPacket(pkt, target)
    KAR_P2P.AddLog("HEUR", string.format("Игрок %s заблокирован ('Не уведомлять'). Отправлен HS_REJ:MUTED.", target), #pkt)
end

function KAR_P2P.Disconnect()
    if KAR_P2P.partner then
        local pkt = string.format("DISC:%s", KAR_P2P.sessionID or "0")
        SendCommPacket(pkt, KAR_P2P.partner)
        KAR_P2P.AddLog("STATE", string.format("Сопряжение с %s разорвано.", KAR_P2P.partner), #pkt)
    end
    KAR_P2P.state = "IDLE"
    KAR_P2P.partner = nil
    KAR_P2P.sessionID = nil
    KAR_P2P.UpdateHUD()
end

function KAR_P2P.SendPing()
    if not KAR_P2P.partner or KAR_P2P.state ~= "PAIRED" then
        KAR_P2P.AddLog("ERROR", "Пинг невозможен: сначала выполните сопряжение (PAIRED)!", 0)
        return
    end

    local nowMs = math.floor(GetTime() * 1000)
    local pkt = string.format("PING:%s:%d", KAR_P2P.sessionID or "0", nowMs)
    KAR_P2P.AddLog("TX", string.format("Отправлен PING напарнику %s...", KAR_P2P.partner), #pkt)
    SendCommPacket(pkt, KAR_P2P.partner)
end

function KAR_P2P.SendTestDatabase()
    if not KAR_P2P.partner or KAR_P2P.state ~= "PAIRED" then
        KAR_P2P.AddLog("ERROR", "Отправка невозможна: сначала выполните сопряжение (PAIRED)!", 0)
        return
    end

    local dummyItems = {
        { "Артас", "Слив ключа 10+", "11.11.2026", 1794340000 },
        { "Иллидан", "Ливнул после 1 вайпа", "11.11.2026", 1794340010 },
        { "Сильвана", "АФК на треше", "11.11.2026", 1794340020 },
        { "Гулдан", "Оскорбления группы", "11.11.2026", 1794340030 },
        { "Джайна", "Пуллит без танка", "11.11.2026", 1794340040 },
        { "Тралл", "Не жмет БР", "11.11.2026", 1794340050 },
        { "Гаррош", "Токсик в чате", "11.11.2026", 1794340060 },
        { "Андуин", "Дно по ДПС", "11.11.2026", 1794340070 },
        { "Кадгар", "Не знает механику", "11.11.2026", 1794340080 },
        { "Медив", "Ливнул перед ластом", "11.11.2026", 1794340090 }
    }

    local itemsStr = ""
    for i, it in ipairs(dummyItems) do
        local entry = string.format("[\"%s\",\"%s\",\"%s\",%d]", it[1], it[2], it[3], it[4])
        itemsStr = itemsStr .. (i > 1 and "," or "") .. entry
    end
    local jsonStr = string.format("{\"type\":\"KAR_BL_SYNC\",\"v\":1,\"count\":10,\"items\":[%s]}", itemsStr)

    local chunkSize = 160
    local len = #jsonStr
    local totalChunks = math.ceil(len / chunkSize)
    local sessID = KAR_P2P.sessionID or "0"
    local partner = KAR_P2P.partner

    KAR_P2P.state = "TRANSFERRING"
    KAR_P2P.UpdateHUD()

    local startPkt = string.format("DATA_START:%s:%d:%d", sessID, totalChunks, len)
    KAR_P2P.AddLog("HEUR", string.format("Старт передачи тестовой базы ЧС (10 записей, %d байт, %d пакетов)...", len, totalChunks), #startPkt)
    SendCommPacket(startPkt, partner)

    for i = 1, totalChunks do
        local startIdx = (i - 1) * chunkSize + 1
        local endIdx = math.min(i * chunkSize, len)
        local chunkData = jsonStr:sub(startIdx, endIdx)

        C_Timer.After((i - 1) * 0.04, function()
            local chunkPkt = string.format("DATA_CHUNK:%s:%d:%d:%s", sessID, i, totalChunks, chunkData)
            SendCommPacket(chunkPkt, partner)

            if i == totalChunks then
                C_Timer.After(0.05, function()
                    local endPkt = string.format("DATA_END:%s:%d", sessID, totalChunks)
                    SendCommPacket(endPkt, partner)
                    KAR_P2P.state = "PAIRED"
                    KAR_P2P.AddLog("HEUR", string.format("Все %d чанков успешно переданы! Ожидание SYNC_ACK...", totalChunks), #endPkt)
                    KAR_P2P.UpdateHUD()
                end)
            end
        end)
    end
end

-- -------------------------------------------------------------
-- ОБРАБОТЧИК ВХОДЯЩИХ ПАКЕТОВ (RX)
-- -------------------------------------------------------------
local function OnCommReceived(prefix, msg, channel, sender)
    if prefix ~= COMM_PREFIX or not msg or msg == "" then return end

    local cleanSender = CleanName(sender)
    local myName = CleanName(UnitName("player"))
    if cleanSender:lower() == myName:lower() then return end

    local byteLen = #msg
    KAR_P2P.rxCount = KAR_P2P.rxCount + 1
    KAR_P2P.AddLog("RX", string.format("<- %s | %s (%db)", cleanSender, msg, byteLen), byteLen)
    KAR_P2P.UpdateHUD()

    local cmd, rest = msg:match("^([^:]+):?(.*)$")
    if not cmd then return end

    if cmd == "HS_REQ" then
        local sessID, ver, senderName, reqFlag = rest:match("^([^:]+):([^:]+):([^:]*):?(.*)$")
        sessID = sessID or "0"
        reqFlag = (reqFlag and reqFlag ~= "") and reqFlag or "MANUAL"
        local displayName = (senderName and senderName ~= "") and senderName or cleanSender

        KAR_P2P.AddLog("HEUR", string.format("Входящий запрос рукопожатия от |cffffff00%s|r [Флаг: %s] (v%s, Сессия #%s)", displayName, reqFlag, ver or "2.2", sessID), byteLen)

        -- Проверка списка "Не уведомлять"
        if KAR_P2P_TesterDB and KAR_P2P_TesterDB.mutedPlayers and KAR_P2P_TesterDB.mutedPlayers[cleanSender:lower()] then
            local pkt = string.format("HS_REJ:%s:MUTED", sessID)
            SendCommPacket(pkt, cleanSender)
            KAR_P2P.AddLog("HEUR", string.format("Запрос от %s проигнорирован (в списке 'Не уведомлять'). Отправлен MUTED.", cleanSender), byteLen)
            return
        end

        if KAR_P2P.autoAccept then
            KAR_P2P.AddLog("STATE", string.format("АВТО-ПРИЕМ рукопожатия активирован: мгновенный ответ напарнику %s...", displayName), 0)
            C_Timer.After(0.1, function()
                KAR_P2P.AcceptHandshake(cleanSender, sessID)
            end)
        else
            StaticPopupDialogs["KAR_P2P_PROMPT_DIALOG"] = {
                text = string.format("Игрок |cffffff00%s|r запрашивает P2P сопряжение [Флаг: %s, v%s].\nПринять рукопожатие?", displayName, reqFlag, ver or "2.2"),
                button1 = "Принять",
                button2 = "Отклонить",
                button3 = "Не уведомлять",
                OnAccept = function()
                    KAR_P2P.AcceptHandshake(cleanSender, sessID)
                end,
                OnCancel = function()
                    KAR_P2P.DeclineHandshake(cleanSender, sessID, "DECLINED_MANUAL")
                end,
                OnAlt = function()
                    KAR_P2P.MuteAndDecline(cleanSender, sessID)
                end,
                timeout = 20,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("KAR_P2P_PROMPT_DIALOG")
            PlaySound(8959) -- Raid warning
        end

    elseif cmd == "HS_ACK" then
        local sessID, ver, partnerName = rest:match("^([^:]+):([^:]+):?(.*)$")
        local rtt = (KAR_P2P.hsStartTime > 0) and math.floor((GetTime() - KAR_P2P.hsStartTime) * 1000) or 0

        KAR_P2P.state = "PAIRED"
        KAR_P2P.partner = cleanSender
        KAR_P2P.sessionID = sessID
        if KAR_P2P_TesterDB then KAR_P2P_TesterDB.lastPartner = cleanSender end

        KAR_P2P.AddLog("HEUR", string.format("РУКОПОЖАТИЕ УСПЕШНО! Сопряжено с: |cffffff00%s|r (RTT рукопожатия: %d мс, v%s)", cleanSender, rtt, ver or "2.2"), byteLen)
        PlaySound(888) -- Quest complete sound
        KAR_P2P.UpdateHUD()

    elseif cmd == "HS_REJ" then
        local sessID, reason = rest:match("^([^:]+):?(.*)$")
        reason = (reason and reason ~= "") and reason or "DECLINED"
        KAR_P2P.state = "IDLE"
        KAR_P2P.partner = nil
        KAR_P2P.AddLog("ERROR", string.format("Рукопожатие ОТКЛОНЕНО напарником %s (Причина: %s).", cleanSender, reason), byteLen)
        KAR_P2P.UpdateHUD()

    elseif cmd == "DISC" then
        KAR_P2P.state = "IDLE"
        KAR_P2P.partner = nil
        KAR_P2P.sessionID = nil
        KAR_P2P.AddLog("STATE", string.format("Напарник %s разорвал сопряжение.", cleanSender), byteLen)
        KAR_P2P.UpdateHUD()

    elseif cmd == "PING" then
        local sessID, clientMs = rest:match("^([^:]+):([^:]+)$")
        local pkt = string.format("PONG:%s:%s", sessID or "0", clientMs or "0")
        SendCommPacket(pkt, cleanSender)
        KAR_P2P.AddLog("HEUR", string.format("Получен PING от %s. Отправлен ответ PONG.", cleanSender), byteLen)

    elseif cmd == "PONG" then
        local sessID, clientMs = rest:match("^([^:]+):([^:]+)$")
        local nowMs = math.floor(GetTime() * 1000)
        local startMs = tonumber(clientMs) or nowMs
        local rtt = math.max(0, nowMs - startMs)
        KAR_P2P.AddLog("HEUR", string.format("PONG от %s получен! Круговая задержка (RTT): |cff00ff00%d мс|r", cleanSender, rtt), byteLen)
        PlaySound(84)

    elseif cmd == "DATA_START" then
        local sessID, totalChunks, totalBytes = rest:match("^([^:]+):([^:]+):([^:]+)$")
        KAR_P2P.incoming = {
            sessID = sessID,
            totalChunks = tonumber(totalChunks) or 1,
            totalBytes = tonumber(totalBytes) or 0,
            chunks = {},
            receivedCount = 0,
            sender = cleanSender,
            startTime = GetTime()
        }
        KAR_P2P.state = "TRANSFERRING"
        KAR_P2P.AddLog("HEUR", string.format("Прием базы данных от %s (%s байт, %s чанков)...", cleanSender, totalBytes or "?", totalChunks or "?"), byteLen)
        KAR_P2P.UpdateHUD()

    elseif cmd == "DATA_CHUNK" then
        local sessID, idx, total, chunkData = rest:match("^([^:]+):([^:]+):([^:]+):(.*)$")
        if KAR_P2P.incoming and KAR_P2P.incoming.chunks then
            local nIdx = tonumber(idx) or 1
            KAR_P2P.incoming.chunks[nIdx] = chunkData
            KAR_P2P.incoming.receivedCount = KAR_P2P.incoming.receivedCount + 1
            KAR_P2P.AddLog("HEUR", string.format("Принят чанк %s/%s (%d байт) от %s", idx or "?", total or "?", #chunkData, cleanSender), byteLen)
        end

    elseif cmd == "DATA_END" then
        if KAR_P2P.incoming and KAR_P2P.incoming.chunks then
            local fullPayload = table.concat(KAR_P2P.incoming.chunks, "")
            local duration = math.floor((GetTime() - KAR_P2P.incoming.startTime) * 1000)
            KAR_P2P.AddLog("HEUR", string.format("СБОРКА ПАКЕТОВ ЗАВЕРШЕНА! Получено %d байт за %d мс. Целостность: 100%%", #fullPayload, duration), byteLen)

            -- Отправляем подтверждение
            local ackPkt = string.format("SYNC_ACK:%s:%d", KAR_P2P.incoming.sessID or "0", KAR_P2P.incoming.totalChunks or 1)
            SendCommPacket(ackPkt, cleanSender)
            KAR_P2P.incoming = nil
            KAR_P2P.state = "PAIRED"
            PlaySound(888)
            KAR_P2P.UpdateHUD()
        end

    elseif cmd == "SYNC_ACK" then
        KAR_P2P.AddLog("HEUR", string.format("ПОЛУЧЕНО ПОДТВЕРЖДЕНИЕ SYNC_ACK от %s! База успешно принята напарником.", cleanSender), byteLen)
    end
end

-- -------------------------------------------------------------
-- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ТЕЛЕМЕТРИИ (HELLSING GOTHIC HUD)
-- -------------------------------------------------------------
local mainFrame = nil

function KAR_P2P.UpdateHUD()
    if not mainFrame then return end

    -- Статус-лампочка
    if KAR_P2P.state == "PAIRED" then
        mainFrame.statusDot:SetTextColor(0, 1, 0, 1)
        mainFrame.statusText:SetText(string.format("|cff00ff00СОПРЯЖЕНО С: %s|r (Сессия: #%s)", KAR_P2P.partner or "?", KAR_P2P.sessionID or "0"))
        mainFrame.pairBtn:SetText("Сопряжено (OK)")
        mainFrame.pairBtn:Disable()
        mainFrame.discBtn:Enable()
        mainFrame.pingBtn:Enable()
        mainFrame.testDbBtn:Enable()
    elseif KAR_P2P.state == "WAIT_ACK" then
        mainFrame.statusDot:SetTextColor(1, 1, 0, 1)
        mainFrame.statusText:SetText(string.format("|cffffff00ОЖИДАНИЕ РУКОПОЖАТИЯ ОТ: %s...|r", KAR_P2P.partner or "?"))
        mainFrame.pairBtn:SetText("Ожидание...")
        mainFrame.pairBtn:Disable()
        mainFrame.discBtn:Enable()
        mainFrame.pingBtn:Disable()
        mainFrame.testDbBtn:Disable()
    elseif KAR_P2P.state == "TRANSFERRING" then
        mainFrame.statusDot:SetTextColor(0, 0.8, 1, 1)
        mainFrame.statusText:SetText(string.format("|cff00ccffПЕРЕДАЧА ДАННЫХ: %s...|r", KAR_P2P.partner or "?"))
        mainFrame.pairBtn:Disable()
        mainFrame.discBtn:Enable()
        mainFrame.pingBtn:Disable()
        mainFrame.testDbBtn:Disable()
    else
        mainFrame.statusDot:SetTextColor(0.85, 0.2, 0.2, 1)
        mainFrame.statusText:SetText("|cffaaaaaaНЕ СОПРЯЖЕНО (IDLE)|r")
        mainFrame.pairBtn:SetText("🔗 Запрос сопряжения")
        mainFrame.pairBtn:Enable()
        mainFrame.discBtn:Disable()
        mainFrame.pingBtn:Disable()
        mainFrame.testDbBtn:Disable()
    end

    mainFrame.counterText:SetText(string.format("TX: |cff00ccff%d|r  |  RX: |cff00ff7f%d|r", KAR_P2P.txCount, KAR_P2P.rxCount))
end

function KAR_P2P.CreateGUI()
    if mainFrame then return mainFrame end

    local f = CreateFrame("Frame", "KAR_P2P_TesterFrame", UIParent, "BackdropTemplate")
    f:SetSize(740, 560)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    f:SetBackdropColor(0.06, 0.04, 0.05, 0.96)
    f:SetBackdropBorderColor(0.85, 0.15, 0.25, 0.95)

    -- Шапка
    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    header:SetHeight(40)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    header:SetBackdropColor(0.12, 0.05, 0.06, 0.98)
    header:SetBackdropBorderColor(0.95, 0.20, 0.20, 0.8)

    local titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
    titleFS:SetPoint("LEFT", header, "LEFT", 14, 0)
    titleFS:SetText("|cffff2222HELLSING|r |cffffffffP2P HEURISTIC TESTER|r |cff888888v2.2|r")

    local closeBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    closeBtn:SetSize(28, 24)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    closeBtn:SetText("✕")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Панель статуса сопряжения
    local statusCard = CreateFrame("Frame", nil, f, "BackdropTemplate")
    statusCard:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    statusCard:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -8)
    statusCard:SetHeight(38)
    statusCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    statusCard:SetBackdropColor(0.08, 0.06, 0.07, 0.95)
    statusCard:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)

    local statusDot = statusCard:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    statusDot:SetPoint("LEFT", statusCard, "LEFT", 12, 0)
    statusDot:SetText("●")
    f.statusDot = statusDot

    local statusText = statusCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusText:SetPoint("LEFT", statusDot, "RIGHT", 8, 0)
    statusText:SetText("|cffaaaaaaНЕ СОПРЯЖЕНО (IDLE)|r")
    f.statusText = statusText

    local counterText = statusCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    counterText:SetPoint("RIGHT", statusCard, "RIGHT", -14, 0)
    counterText:SetText("TX: 0  |  RX: 0")
    f.counterText = counterText

    -- Панель ввода и управления
    local ctrlCard = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ctrlCard:SetPoint("TOPLEFT", statusCard, "BOTTOMLEFT", 0, -8)
    ctrlCard:SetPoint("TOPRIGHT", statusCard, "BOTTOMRIGHT", 0, -8)
    ctrlCard:SetHeight(76)
    ctrlCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    ctrlCard:SetBackdropColor(0.08, 0.06, 0.07, 0.95)
    ctrlCard:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)

    -- Поле ввода ника
    local targetLabel = ctrlCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetLabel:SetPoint("TOPLEFT", ctrlCard, "TOPLEFT", 12, -10)
    targetLabel:SetText("|cffffcc00Ник напарника для сопряжения:|r")

    local targetInput = CreateFrame("EditBox", nil, ctrlCard, "InputBoxTemplate")
    targetInput:SetSize(170, 24)
    targetInput:SetPoint("TOPLEFT", ctrlCard, "TOPLEFT", 16, -28)
    targetInput:SetAutoFocus(false)
    targetInput:SetMaxLetters(32)
    local savedPartner = (KAR_P2P_TesterDB and KAR_P2P_TesterDB.lastPartner) or ""
    targetInput:SetText(savedPartner)
    f.targetInput = targetInput

    -- Кнопка "Вставить цель"
    local fillTargetBtn = CreateFrame("Button", nil, ctrlCard, "UIPanelButtonTemplate")
    fillTargetBtn:SetSize(70, 24)
    fillTargetBtn:SetPoint("LEFT", targetInput, "RIGHT", 6, 0)
    fillTargetBtn:SetText("Цель")
    fillTargetBtn:SetScript("OnClick", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            local tName = UnitName("target")
            if tName then targetInput:SetText(tName) end
        else
            KAR_P2P.AddLog("INFO", "Выберите другого игрока в цель!", 0)
        end
    end)

    -- Кнопка "Сопряжение (HS_REQ)"
    local pairBtn = CreateFrame("Button", nil, ctrlCard, "UIPanelButtonTemplate")
    pairBtn:SetSize(155, 26)
    pairBtn:SetPoint("LEFT", fillTargetBtn, "RIGHT", 14, 0)
    pairBtn:SetText("🔗 Запрос сопряжения")
    pairBtn:SetScript("OnClick", function()
        local name = targetInput:GetText()
        KAR_P2P.RequestHandshake(name)
    end)
    f.pairBtn = pairBtn

    -- Кнопка "Пинг"
    local pingBtn = CreateFrame("Button", nil, ctrlCard, "UIPanelButtonTemplate")
    pingBtn:SetSize(90, 26)
    pingBtn:SetPoint("LEFT", pairBtn, "RIGHT", 8, 0)
    pingBtn:SetText("⚡ Пинг")
    pingBtn:SetScript("OnClick", function()
        KAR_P2P.SendPing()
    end)
    f.pingBtn = pingBtn

    -- Кнопка "Тест базы ЧС"
    local testDbBtn = CreateFrame("Button", nil, ctrlCard, "UIPanelButtonTemplate")
    testDbBtn:SetSize(110, 26)
    testDbBtn:SetPoint("LEFT", pingBtn, "RIGHT", 8, 0)
    testDbBtn:SetText("📦 Тест базы")
    testDbBtn:SetScript("OnClick", function()
        KAR_P2P.SendTestDatabase()
    end)
    f.testDbBtn = testDbBtn

    -- Кнопка "Разорвать"
    local discBtn = CreateFrame("Button", nil, ctrlCard, "UIPanelButtonTemplate")
    discBtn:SetSize(75, 26)
    discBtn:SetPoint("LEFT", testDbBtn, "RIGHT", 8, 0)
    discBtn:SetText("✕ Сброс")
    discBtn:SetScript("OnClick", function()
        KAR_P2P.Disconnect()
    end)
    f.discBtn = discBtn

    -- Чекбокс авто-приема
    local autoCb = CreateFrame("CheckButton", nil, ctrlCard, "UICheckButtonTemplate")
    autoCb:SetPoint("TOPLEFT", targetLabel, "TOPRIGHT", 60, 4)
    autoCb:SetSize(22, 22)
    autoCb:SetChecked(KAR_P2P.autoAccept)
    autoCb:SetScript("OnClick", function(self)
        KAR_P2P.autoAccept = self:GetChecked()
        if KAR_P2P_TesterDB then KAR_P2P_TesterDB.autoAccept = KAR_P2P.autoAccept end
        KAR_P2P.AddLog("INFO", string.format("Авто-прием рукопожатия: %s", KAR_P2P.autoAccept and "|cff00ff00ВКЛ|r" or "|cffff3333ВЫКЛ|r"), 0)
    end)

    local autoCbLabel = ctrlCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoCbLabel:SetPoint("LEFT", autoCb, "RIGHT", 4, 0)
    autoCbLabel:SetText("|cff00ff7fАвто-прием рукопожатия (Auto-Accept)|r")

    -- Окно телеметрии и логов
    local logCard = CreateFrame("Frame", nil, f, "BackdropTemplate")
    logCard:SetPoint("TOPLEFT", ctrlCard, "BOTTOMLEFT", 0, -8)
    logCard:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 42)
    logCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    logCard:SetBackdropColor(0.04, 0.03, 0.04, 0.98)
    logCard:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)

    local logScroll = CreateFrame("ScrollFrame", "KAR_P2P_LogScroll", logCard, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT", logCard, "TOPLEFT", 8, -8)
    logScroll:SetPoint("BOTTOMRIGHT", logCard, "BOTTOMRIGHT", -28, 8)

    local logBox = CreateFrame("EditBox", nil, logScroll)
    logBox:SetMultiLine(true)
    logBox:SetMaxLetters(99999)
    logBox:EnableMouse(true)
    logBox:SetAutoFocus(false)
    logBox:SetFontObject("GameFontHighlightSmall")
    logBox:SetWidth(680)
    logBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    logScroll:SetScrollChild(logBox)
    f.logBox = logBox
    KAR_P2P.logBox = logBox

    -- Нижние кнопки управления
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(110, 24)
    clearBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    clearBtn:SetText("Очистить лог")
    clearBtn:SetScript("OnClick", function()
        KAR_P2P.logHistory = {}
        logBox:SetText("")
    end)

    local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copyBtn:SetSize(120, 24)
    copyBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    copyBtn:SetText("Выделить всё")
    copyBtn:SetScript("OnClick", function()
        logBox:SetFocus()
        logBox:HighlightText()
    end)

    local helpFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpFS:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    helpFS:SetText("|cff888888Команда: /p2p или /kartest | Канал: WHISPER (KAR_SYNC)|r")

    table.insert(UISpecialFrames, "KAR_P2P_TesterFrame")
    mainFrame = f
    KAR_P2P.UpdateHUD()

    -- Стартовое сообщение
    KAR_P2P.AddLog("INFO", "Модуль P2P эвристики запущен. Префикс: KAR_SYNC. MTU: 255b.", 0)
    KAR_P2P.AddLog("INFO", "Для теста введите ник напарника (например, Hitgun) и нажмите 'Запрос сопряжения'.", 0)

    return f
end

function KAR_P2P.ToggleGUI()
    local f = KAR_P2P.CreateGUI()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        KAR_P2P.UpdateHUD()
    end
end

-- -------------------------------------------------------------
-- СЛЭШ-КОМАНДЫ И РЕГИСТРАЦИЯ СОБЫТИЙ
-- -------------------------------------------------------------
SLASH_KARP2P1 = "/p2p"
SLASH_KARP2P2 = "/kartest"
SLASH_KARP2P3 = "/karpair"
SlashCmdList["KARP2P"] = function()
    KAR_P2P.ToggleGUI()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
            elseif RegisterAddonMessagePrefix then
                RegisterAddonMessagePrefix(COMM_PREFIX)
            end
            if KAR_P2P_TesterDB then
                KAR_P2P.autoAccept = (KAR_P2P_TesterDB.autoAccept == true)
                if not KAR_P2P_TesterDB.mutedPlayers then KAR_P2P_TesterDB.mutedPlayers = {} end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
        end
        print("|cffff3333[KAR P2P Heuristic Tester]|r Модуль загружен! Открыть окно: |cffffff00/p2p|r или |cffffff00/kartest|r")
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix == COMM_PREFIX then
            OnCommReceived(prefix, msg, channel, sender)
        end
    end
end)
