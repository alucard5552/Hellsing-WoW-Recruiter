# KeyAutoRecruit (KAR) — Документация и Архитектурная карта кода

> **Клиент**: World of Warcraft: The War Within / Midnight 12.0.7 (Build 68974, TOC Interface: 120001, 120007)  
> **Директория**: `C:\Firestorm\The War Within\_midnight_\Interface\AddOns\KeyAutoRecruit\`  
> **Файлы**: `KeyAutoRecruit.lua` (1400 строк), `KeyAutoRecruit_GUI.lua` (317 строк), `KeyAutoRecruit.toc`  
> **Инструмент проверки**: `python c:\soft\6\check_lua_syntax.py`

---

## 1. Карта строк кода: `KeyAutoRecruit.lua` (1400 строк)

| Диапазон строк | Модуль / Компонент | Назначение и Архитектурное описание |
| :--- | :--- | :--- |
| **L1 – L27** | **Инициализация и Chat-Bus** | Объявление таблицы `KeyAutoRecruit = {}`, константа `SYNC_CHANNEL_NAME = "KAR_SYNC_BUS"`, функция `SendDaemonSyncMessage(msg)` для трансляции событий во внешний Python-демон через скрытый чат-канал. |
| **L28 – L63** | **Аппаратный мост и SecureFrame** | Функция `InitSecureHardwareBridge()`, создание полноэкранного невидимого фрейма `KAR_SecureEventFrame` (перехват кликов мыши, скролла, геймпада и клавиш), функция `RunNextSecureAction()` для исполнения защищенных действий без taint. |
| **L64 – L96** | **Оптический пиксельный триггер** | Создание фрейма `KAR_PixelTrigger` (32×32 px в верхнем левом углу, `TOOLTIP` strata), черная рамка 32×32, внутренний активный пиксель 28×28. Используется для аппаратного считывания состояния через Python OpenCV. |
| **L97 – L154** | **Цветовые профили триггера** | `KAR.SetTriggerColor(colorType)`: Танк `RGB(0, 180, 255)`, Хил `RGB(0, 255, 120)`, ДД `RGB(255, 140, 0)`, Отказ `RGB(255, 0, 0)`, Группа 5/5 `RGB(0, 255, 0)`. Функция `KAR.ShowGroupFullPixel(duration)` с таймером авто-скрытия. |
| **L155 – L177** | **Тестовый режим пикселя** | `KAR.ToggleTestPixel(state)`: переключение тестового отображения пикселя, вывод подсказок в чат. |
| **L178 – L188** | **Защищенная очередь действий** | `KAR.EnqueueSecureAction(fn, roleCode)`: добавление функции (инвайт/кик) в `secureActionQueue`, смена цвета пикселя и отправка сигнала `KAR_TRIGGER_F12` в Python-демон. |
| **L189 – L198** | **Тестовое оповещение роли** | `KAR.TestRoleAnnouncement(role)`: эмуляция срабатывания найденного кандидата для отладки звука и макроса F12. |
| **L199 – L254** | **Таблица специализаций** | `KAR.SPECIALIZATIONS = {}` — 40 специализаций WoW Midnight 12.0 / TWW: <br>• L201–203: Воин (71 Arms, 72 Fury, 73 Prot)<br>• L205–207: Паладин (65 Holy, 66 Prot, 70 Ret)<br>• L209–211: Охотник (253 BM, 254 MM, 255 Surv)<br>• L213–215: Разбойник (259 Assa, 260 Outlaw, 261 Sub)<br>• L217–219: Жрец (256 Disc, 257 Holy, 258 Shadow)<br>• L221–223: Рыцарь смерти (250 Blood, 251 Frost, 252 Unholy)<br>• L225–227: Шаман (262 Ele, 263 Enh, 264 Resto)<br>• L229–231: Маг (62 Arcane, 63 Fire, 64 Frost)<br>• L233–235: Чернокнижник (265 Affli, 266 Demo, 267 Destro)<br>• L237–239: Монах (268 Brew, 269 Mist, 270 WW)<br>• L241–244: Друид (102 Boomkin, 103 Feral, 104 Bear, 105 Tree)<br>• **L246–248: ДХ (577 Havoc, 581 Veng, 1480 Devourer / Пожиратель)**<br>• L249–252: Пробудитель (1467 Devast, 1468 Preserv, 1473 Augment). |
| **L255 – L266** | **Классовые списки** | `KAR.ORDERED_CLASSES` (13 классов) и автоматическая группировка `KAR.CLASS_SPECS[class]`. |
| **L267 – L281** | **Цвета классов** | `KAR.CLASS_COLORS` (HEX коды цветов классов Blizzard для оформления UI и логов). |
| **L282 – L311** | **Схема базы данных `defaultDB`** | Дефолтные настройки: `minRio = 0`, `minIlvl = 600`, `minLust = 1`, `minBrez = 1`, `autoDecline = true`, `kickWrongSpec = true`, `groupMinScore = 40`, `allowOneVagon = true`, `vagonMaxIlvlDiff = 35`, `upgradeFullGroup = true`, `upgradeMultiGroup = true`, `upgradeIlvlDiff = 15`, `upgradeRioDiff = 250`, `protectedRio = 2500`, инициализация всех 40 спеков `specs[specID] = true`. |
| **L312 – L318** | **Логирование** | `KAR.Log(msg)` — системный вывод сообщений с префиксом `|cff00ff00[KAR]|r`. |
| **L319 – L358** | **Защита друзей (`IsFriend`)** | `KAR.IsFriend(playerName)` — трехуровневая проверка: <br>1. Игровые друзья (`C_FriendList.GetFriendInfoByIndex`)<br>2. Battle.net друзья (`C_BattleNet.GetFriendGameAccountInfo`)<br>3. Согильдейцы (`GetGuildRosterInfo`). Защищает друзей от кика/замены. |
| **L359 – L377** | **Кэш и структуры данных** | `KAR.InspectedMembers = {}`, `soloJoinedMembers = {}`, `pendingInvitedRoles = {}`, `KAR.ApplicantDataCache = {}` (хранит точные данные заявителей), создание `eventFrame`. |
| **L378 – L399** | **Инициализация БД `InitDB`** | `InitDB()`: слияние сохраненных настроек `KeyAutoRecruitDB` с `defaultDB`, инициализация новых спеков (включая 1480). |
| **L400 – L422** | **Эффективный ilvl** | `KAR.GetEffectiveMinIlvl()`: вычисление минимального порога ilvl с учетом требований активного подземелья в `C_LFGList.GetActiveEntryInfo()`. |
| **L423 – L536** | **Состояние группы `GetGroupStatus`** | `KAR.GetGroupStatus()`: перебор участников группы (`player`, `party1..4`), определение ролей (Танк, Хил, ДД), проверка утилит (Lust, BRez), учет уже отправленных приглашений (`pendingInvitedRoles`), расчет свободных слотов `openSlots`. |
| **L537 – L632** | **Авто-замена 1v1 (`EvaluateSoloReplacement`)** | Оценка и замена слабейшего пуга текущей группы на сильного одиночного кандидата: проверка иммунитета лидера, друзей и `protectedRio >= 2500`, нахождение слабейшего пуга соответствующей роли, проверка прироста `rioGain >= upgradeRioDiff` (250) и `candIlvl >= weakestIlvl - 2`, сохранение Lust/BRez, постановка в очередь `UninviteUnit(weakestName)`. |
| **L633 – L851** | **Групповая замена (`EvaluateGroupReplacement`)** | Оценка пользы и замена пугов при заявке сыгранной группы 2–4 человек: расчет состава входящих, сбор пугов под замену, ролевые квоты (макс. 1 танк, 1 хил, 3 дд), вычисление прироста RIO с бонусом сыгранности пати (+50/+150/+250 RIO), проверка `effectiveGain >= 250`, постановка на кик слабых пугов. |
| **L852 – L1119** | **Оценка кандидата `EvaluateApplicant`** | Главная точка входа оценки заявителя по `applicantID`: <br>• Ветка А (L865–960): одиночный кандидат (проверка прямого слота -> при отказе запуск `EvaluateSoloReplacement`)<br>• Ветка Б (L961–1119): группа 2–4 чел (проверка спеков, вагонов, разрыва ilvl -> при нехватке слотов запуск `EvaluateGroupReplacement`). |
| **L1120 – L1159** | **Оповещение о кандидате** | `KAR.AnnounceCandidateFound(...)`: RaidWarning на экране, системный звук `SOUNDKIT.READY_CHECK`, мигание окна Windows `FlashClientIcon()`, лог в чат и сокет-сообщение `KAR_FOUND:Роль:Имя`. |
| **L1160 – L1194** | **Оповещение о сборе 5/5** | `KAR.AnnounceGroupFull()`: RaidWarning `Группа полностью собрана (5/5)`, звук рейд-варнинга, зеленый пиксель 2.5 сек, отправка `KAR_GROUP_FULL`. |
| **L1195 – L1209** | **Инспектор игроков `InspectUnit`** | `InspectUnit(unit)`: запуск `NotifyInspect` с таймаутом 3.5 сек для защиты от зависания очереди. |
| **L1210 – L1289** | **Очередь обработки `ProcessApplicants`** | Цикл по заявителям `C_LFGList.GetApplicants()`: оценка, кэширование параметров в `ApplicantDataCache`, постановка инвайта в очередь, авто-отклонение неподходящих при `autoDecline = true`. Разрешает проверку кандидатов при 4/5 и 5/5, если включена авто-замена. |
| **L1290 – L1400** | **Слушатели событий WoW** | `ADDON_LOADED`, `GROUP_ROSTER_UPDATE`, `INSPECT_READY` (считывание спека, расчет ilvl и Mythic+ Score), `LFG_LIST_APPLICANT_*`. |

---

## 2. Карта строк кода: `KeyAutoRecruit_GUI.lua` (317 строк)

| Диапазон строк | Модуль / Компонент | Назначение и Архитектурное описание |
| :--- | :--- | :--- |
| **L1 – L22** | **Локализация классов** | Таблица `CLASS_LOCALIZED` для 13 классов WoW (включая DH и Evoker). |
| **L23 – L35** | **Компонент: Чекбокс** | Функция `CreateCheckbox(parent, x, y, label, onClick, initialChecked)`. |
| **L36 – L62** | **Компонент: Числовой EditBox** | Функция `CreateNumericEditBox(parent, x, y, labelText, defaultValue, onEnter)`. |
| **L63 – L89** | **Главное окно GUI** | Функция `KAR.OpenGUI()`: создание перемещаемого фрейма `KeyAutoRecruitMainFrame` (720×680 px), заголовок. |
| **L90 – L104** | **Верхние переключатели** | Чекбоксы: «Включить авто-рекрут», «Авто-отклонение», «Кикать за чужой спек». |
| **L105 – L125** | **Строка 1 настроек** | Поля ввода: Мин. RIO ключа, Мин. ilvl, Мин. Lust, Мин. BRez, кнопки «Выбрать все» и «Снять все». |
| **L126 – L143** | **Строка 2 настроек** | Поля ввода: Мин/Макс ilvl сезона, Макс RIO сезона, Мин. сила группы (%), чекбокс «1 вагон разрешен». |
| **L144 – L160** | **Строка 3: Авто-замена** | Чекбокс «Авто-замена 1v1 (соло 4/5 и 5/5)», чекбокс «Авто-замена групп (2-4 чел)», поле «Защита своих RIO >=», поле «Мин. RIO прирост (+)». |
| **L161 – L225** | **Скролл специализаций** | `ScrollFrame` со списком всех 40 специализаций в 2 колонки с цветовой индикацией ролей ([Танк], [Хил], [ДД], [Героизм], [БР]). |
| **L226 – L267** | **Индикатор статуса** | Функция `UpdateLiveStatus()`: отображение состава группы, свободных слотов, потребности ролей, наличия Lust/BRez. |
| **L268 – L297** | **Кнопки управления** | Кнопка «Проверить сейчас» (принудительный запуск), кнопка «Тест пикселя (F11)». |
| **L298 – L317** | **Слэш-команды** | Регистрация `/kar`, `/keyrecruit`, `/autorecruit` и подкоманд (`test tank`, `test heal`, `test dps`, `test full`, `pixel`). |

---

## 3. Математическая модель алгоритма замены

### Одиночная замена (1v1):
$$\Delta RIO = RIO_{cand} - RIO_{weakest} \ge \text{upgradeRioDiff} \quad (\text{default } 250)$$
$$\Delta ilvl = ilvl_{cand} - ilvl_{weakest} \ge -2$$
$$\text{Lust}_{after} \ge \text{minLust}, \quad \text{Brez}_{after} \ge \text{minBrez}$$

### Групповая замена (2–4 игрока):
$$\text{CohesionBonus} = \begin{cases} +50, & \text{если } N = 2 \\ +150, & \text{если } N = 3 \\ +250, & \text{если } N = 4 \end{cases}$$
$$\text{EffectiveGain} = (\overline{RIO}_{incoming} - \overline{RIO}_{replaced}) + \text{CohesionBonus} \ge \text{upgradeRioDiff}$$
$$\overline{ilvl}_{incoming} \ge \overline{ilvl}_{replaced} - 3$$
