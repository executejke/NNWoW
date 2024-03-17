local nn = ...

local Targets = {}  -- Таблица с целями

local Points = {x = -5752, y = -1542, z = 374}

local safePoint = {x = -5634, y = -348, z = 390}

local blackSpot = {}

local Rotation = {
    {name = "Crusader Strike", id = 407676},
    {name = "Judgement", id = 20271},
    {name = "Hammer of Justice"},
    -- {name = "Purify"}
}

local Auras = {
    {name = "Seal of Righteousness", isActive = false},
    {name = "Blessing of Might", isActive = false}
}

local Food = {
    water = "Refreshing Spring Water",
    food = "Tough Hunk of Bread"
}

local foodVendor = {name = "Kazan Mogosh", x = -5666, y = -1568, z = 384}

local vendor = {name = "Frast Dokner", x = -5711, y = -1593, z = 384}

local Quality = {Common = nil, Uncommon = nil, Rare = nil, Epic = nil}

local auraFrame = CreateFrame("Frame") -- Фрейм Аур 

local bagFrame = CreateFrame("Frame") -- Фрейм сумки

local deadFrame = CreateFrame("Frame") -- Фрейм смерти

local respawnFrame = CreateFrame("Frame") -- Фрейм возрождения

local combatFrame = CreateFrame("Frame")

local MpAndHpFrame = CreateFrame("Frame")

local target -- Основная цель

local ticker -- Тикер

local stuckTimer

local auraTicker

local stuck = 0

local powerTicker

local timer

local mana = nil

local health = nil

function StopMoving()
    local isStopped = false
    CancelActiveTicker()
    ticker = C_Timer.NewTicker(0.1, function ()
        ClickToMove(ObjectPosition("player"))
        if not IsPlayerMoving() then
            CancelActiveTicker()
            isStopped = true
        end
    end)
    return isStopped
end

function CancelActiveTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
        print(ticker)
        else
            return
    end
end

local function checkBuffs(buffs)
    local allBuffsActive = true
    for _, buff in ipairs(buffs) do
        -- переменная для отслеживания наличия баффа на персонаже.
        local buffFound = false
        for i = 1, 10 do
            local name = UnitBuff("player", i)
            if name == buff.name then
                buffFound = true
                break
            end
        end
        -- Проверка, был ли найден бафф в предыдущем цикле.
        if not buffFound then
            CastSpellByName(buff.name, "player")
            -- Устанавливаем статус баффа в Auras как активный.
            buff.isActive = true
            allBuffsActive = false
        end
    end
    if allBuffsActive and auraTicker then
        auraTicker:Cancel()
        auraTicker = nil
        print(auraTicker)
        print("auraTicker Остановлен")
    end
end

function GetEquippedBagCount()
 local numBags = 0
    for bagId = 0, 4 do
        if C_Container.GetBagName(bagId) ~= nil then
            numBags = numBags + 1
        end
    end
return numBags
end

local function setBuffTicker()
    if not auraTicker then
        auraTicker = C_Timer.NewTicker(0.3, function ()
            checkBuffs(Auras)
        end)
    end
end
-- Mana.default / percentage or Health.default / percentage
local function getPower()
    local power = {

     percentage = { health = math.ceil((UnitHealth("player") / UnitHealthMax("player")) * 100),
                    mana = math.ceil((UnitPower("player") / UnitPowerMax("player")) * 100)},
      default = { health = UnitHealth("player"), mana = UnitPower("player")}
    }
    return power
end

function LootUnit(target)
    if UnitExists(target) then
        if UnitIsDead(target) and CanLootUnit(target) then
            ObjectInteract(target)
        end
    end
end

local function checkBagSpace()
    local totalFreeSlots = 0
    local totalSlots = 0
    for bagId = 0, 4 do
        local freeSlots, bagType = C_Container.GetContainerNumFreeSlots(bagId)
        local bagSlots = C_Container.GetContainerNumSlots(bagId)
        totalFreeSlots = totalFreeSlots + freeSlots
        totalSlots = totalSlots + bagSlots
    end
    return totalFreeSlots
end

function moveTowardsTarget(target, stopDistance)
        local map = select(8, GetInstanceInfo())
        local px, py, pz = ObjectPosition("player")
        local tx, ty, tz
        
        
        if type(target) == "number" then
            tx, ty, tz = ObjectPosition(target)
        elseif type(target) == "table" then
            tx, ty, tz = target.x, target.y, target.z
        else return
        end

        local path = GenerateLocalPath(map, px, py, pz, tx, ty, tz)
        
        local distance = Distance("player", target)
        if distance <= stopDistance then
            return true
        elseif math.abs(math.ceil(px) - tx) <= stopDistance and math.abs(math.ceil(py) - ty) <= stopDistance and math.abs(math.ceil(pz) - tz) <= stopDistance then
            return true
        end

        if path and #path > 1 then
            
            local targetPointIndex = #path > 2 and 3 or 2
            if path[targetPointIndex] then 
                ClickToMove(tonumber(path[targetPointIndex].x), tonumber(path[targetPointIndex].y), tonumber(path[targetPointIndex].z))
            else
                ClickToMove(tonumber(path[#path].x), tonumber(path[#path].y), tonumber(path[#path].z))
            end
        else
            print("PATH OR TARGET NOT EXISTS")
        end
end

local function onLootUnit(self, event, ...)
    if event == "LOOT_CLOSED" then
        setTargets()
    end
end

function IsFullHpAndMp()
    return getPower().percentage.mana == 100 and getPower().percentage.health == 100
end

function RestoreHpAndMp()
        auraFrame:UnregisterEvent("UNIT_AURA")
        CancelActiveTicker()
            ticker = C_Timer.NewTicker(1, function ()
                local food = false
                local water = false
      
                  for i = 1, 10 do
                      local name = UnitBuff("player", i)
                      if name == "Food" then
                          food = true
                      elseif name == "Drink" then
                          water = true
                      end
                  end
      
                  if not food then
                      nn.Unlock("UseAction", 7)
                  elseif not water then
                      nn.Unlock("UseAction", 8)
                  end
      
                  if IsFullHpAndMp() or UnitAffectingCombat("player") then
                      CancelActiveTicker()
                      auraFrame:RegisterEvent("UNIT_AURA")
                      Start()
                  end
              end)
end

function GetItemName(bagId, slot)
    local itemId = C_Container.GetContainerItemID(bagId, slot)
    if itemId == nil then return end
    local itemName = select(1, GetItemInfo(itemId))
    return itemName
end

function GetManaCost(spell)
    local getSpellInfo = GetSpellPowerCost(spell)
    return getSpellInfo[1].cost
end

local function mainRotation()
    for _, v in pairs(Rotation) do
        start, duration, enabled, modRate = GetSpellCooldown(v.name)
        StartAttack()
        CastSpellByName(v.name)
        if getPower().percentage.health <= 50 then
            StartAttack()
            CastSpellByName("Holy Light")
        end
    end
end

-- Загружаем lua скрипт
function require(path)
    local script = nn.ReadFile(path)
    local f, err = loadstring(script)
            if err then error(err) end
            return f()
end

local gapa = require("/scripts/Gapa.lua")
local UID = require("/scripts/CheckUID.lua")

-- Основной фрейм с кнопками
local function createMainFrame()
    local frame = CreateFrame("Frame", "MyFrame", UIParent)
    frame:SetSize(200, 75)
    frame:SetPoint("RIGHT")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(true)
    background:SetColorTexture(238 / 255, 130 / 255, 238 / 255, 0.5)
    
    return frame
end

-- Создаем линии вокруг фрейма
local function createBorderLine(parent)
    local points = {{"BOTTOMLEFT", "TOPLEFT"},
    {"TOPLEFT", "TOPRIGHT"},
    {"TOPRIGHT", "BOTTOMRIGHT"},
    {"BOTTOMRIGHT", "BOTTOMLEFT"}}
local lines = {}
for i, pointPair in ipairs(points) do
    local line = parent:CreateLine()
    line:SetColorTexture(238 / 255, 130 / 255, 238 / 255, 1)
    line:SetThickness(2)
    line:SetStartPoint(pointPair[1])
line:SetEndPoint(pointPair[2])
lines[#lines+1] = line
end
return lines
end

local function antiafk()
    LastHardwareAction(GetTime()*1000)
    C_Timer.After(0.1, antiafk)
  end
  timer = C_Timer.NewTicker(2, function()
      antiafk()
  end)

local frame = createMainFrame() -- Создаем фрейм
local buttonsHeight = 22; -- Высота кнопки
local allLines = createBorderLine(frame) -- Создаем все линии вокруг фрейма
local centerFrame = (math.ceil(frame:GetHeight()) - buttonsHeight) / 2 -- Рассчитываем центр основного фрейма

function moveToPoint()
    CancelActiveTicker()
    ticker = C_Timer.NewTicker(0.3, function ()
        moveTowardsTarget(Points, 0)
        local x, y, z = ObjectPosition("player")
        if math.abs(math.ceil(x) - Points.x) <= 3 and math.abs(math.ceil(y) - Points.y) <= 3 and math.abs(math.ceil(z) - Points.z) <= 3 then
            CancelActiveTicker()
            print("da da")
            Start()
        end
    end)
end

function setTargets()
    local objects = ObjectManager("Unit") or {} -- Получаем таблицу с объектами
    local targetsWithDistances = {}

    for _, v in ipairs(objects) do
        if nn.UnitName(v) == "Rockjaw Skullthumper" or nn.UnitName(v) == "Rockjaw Bonesnapper" then -- Фильтруем таблицу по нужным нам юнитам.
            if not UnitIsDead(v) and not (UnitIsTapDenied(v)) then -- Если юнит жив и не тапнутый, то добавляем его в таблицу
                local distance = Distance("player", v) -- Получаем расстояние до юнита
                table.insert(targetsWithDistances, {unit = v, distance = distance}) -- Вставляем юнита и расстояние в таблицу
            end
        end
    end

    -- Сортируем таблицу по расстоянию
    table.sort(targetsWithDistances, function(a, b)
        return a.distance < b.distance
    end)

    -- Теперь создаем таблицу Targets, которая будет содержать только юниты, отсортированные по расстоянию
    local Targets = {}
    for i = 1, #targetsWithDistances do
        Targets[i] = targetsWithDistances[i].unit
    end

    -- Выбираем ближайшего юнита
    if #Targets > 0 then
        target = Targets[1] -- Ближайший юнит теперь первый в отсортированной таблице
    else
        moveToPoint()
    end
end

-- Кусок гавна нада переделать
function Start()
    setTargets()
    checkBuffs(Auras)
    if target then
        CancelActiveTicker()
        ticker = C_Timer.NewTicker(0.3, function ()
            if getPower().percentage.health <= 50 and not (UnitAffectingCombat("player"))
                or
               getPower().percentage.mana <= 50 and not (UnitAffectingCombat("player"))
            then
                RestoreHpAndMp()
                return
            end
            if not (UnitIsTapDenied(target)) then
            TargetUnit(target)
            local distance = moveTowardsTarget(target, 3)
            if distance then
                mainRotation()
                local x,y,z = ObjectPosition('player')
                local a,b,c = ObjectPosition(target)
                local angle = GetAnglesBetweenPositions(x,y,z,a,b,c)
                SetPlayerFacing(angle)
            else moveTowardsTarget(target, 3)
            end
            if UnitExists(target) then
                if UnitIsDead(target) and CanLootUnit(target) then
                    ObjectInteract(target)
                end
            end
        else
            setTargets()
            end
        end)
    else
        moveToPoint()
    end
end

function onStuck()
    print(stuck)
    stuck = stuck + 1
        if stuck >= 15 then
            local x, y, z = ObjectPosition("player")
            ClickToMove(math.ceil(x) + 5, math.ceil(y), math.ceil(z))
            stuck = 0
        end
end

function resetStuck()
    stuckTimer = C_Timer.NewTicker(5, function ()
        stuck = 0
    end)
end

resetStuck()

local function sellItems()
    CancelActiveTicker()
    local bagId = 0
    local slot = 1
    local numBags = GetEquippedBagCount()
    ticker = C_Timer.NewTicker(0.3, function ()
      local onPoint = moveTowardsTarget(vendor, 3)
        if onPoint then
            nn.Unlock("TargetUnit", vendor.name, true)
            ObjectInteract("target")
        end
        if MerchantFrame:IsShown() then
            RepairAllItems()
            if bagId <= numBags then
                local slots = C_Container.GetContainerNumSlots(bagId)
                if slot <= slots then
                    if GetItemName(bagId, slot) == Food.food or GetItemName(bagId, slot) == Food.water then
                        slot = slot + 1
                    else
                        C_Container.UseContainerItem(bagId, slot)
                        slot = slot + 1
                    end
                else
                    bagId = bagId + 1
                    slot = 1
                end
            else
                print("Готово")
                moveToPoint()
            end
        end
    end)
end

-- Левая кнопка
local startButton = CreateFrame("Button", "Start", frame, "UIPanelButtonTemplate")
startButton:SetSize(80, buttonsHeight)
startButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, centerFrame)
startButton:SetText("Start")
startButton:SetScript("OnClick", function()
    Start()
end)

-- Правая кнопка
local stopButton = CreateFrame("Button", "Stop", frame, "UIPanelButtonTemplate")
stopButton:SetSize(80, buttonsHeight)
stopButton:SetPoint("LEFT", startButton, "RIGHT", 10, 0)
stopButton:SetText("Stop")
stopButton:SetScript("OnClick", function()
    CancelActiveTicker()
    RestoreHpAndMp()
end)

local getpos = CreateFrame("Button", "getpos", frame, "UIPanelButtonTemplate")
getpos:SetSize(80, buttonsHeight)
getpos:SetPoint("CENTER", startButton, "CENTER", 0, -20)
getpos:SetText("getpos")
getpos:SetScript("OnClick", function()
    local x, y, z = ObjectPosition("player")
    ClickToMove(math.ceil(x) + 15, math.ceil(y) + 15, math.ceil(z))
end)

local getID = CreateFrame("Button", "getID", frame, "UIPanelButtonTemplate")
getID:SetSize(80, buttonsHeight)
getID:SetPoint("CENTER", startButton, "CENTER", 90, -20)
getID:SetText("getID")
getID:SetScript("OnClick", function()
    nn.Unlock("SitStandOrDescendStart")
end)



frame:SetScript("OnEvent", onLootUnit)
frame:RegisterEvent("LOOT_CLOSED")

bagFrame:RegisterEvent("BAG_UPDATE")
bagFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" then
       local space = checkBagSpace()
       if space <= 3 then
        CancelActiveTicker()
        sellItems()
       end
    end
end)

deadFrame:RegisterEvent("PLAYER_DEAD")
deadFrame:SetScript("OnEvent", function (self, event)
    if event == "PLAYER_DEAD" then
        CancelActiveTicker()
        RepopMe()
        ticker = C_Timer.NewTicker(0.3, function ()
            local cx, cy, cz = GetCorpsePosition()
            local corpsePos = {x = cx, y = cy, z = cz}
            moveTowardsTarget(corpsePos, 1)
            RetrieveCorpse()
        end)
    end
end)

respawnFrame:RegisterEvent("PLAYER_UNGHOST")
respawnFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_UNGHOST" then
        CastSpellByName(Auras[2].name)
        CancelActiveTicker()
        Start()
    end
end)

auraFrame:RegisterEvent("UNIT_AURA", "player")
    auraFrame:SetScript("OnEvent", function (self, event, unit)
    if event == "UNIT_AURA" and unit == "player" then
        setBuffTicker()
    end
end)

antiafk()

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_STOPPED_MOVING")
f:SetScript("OnEvent", function (self, event)
    if event == "PLAYER_STOPPED_MOVING" then
        onStuck()
    end
end)

local facingError = CreateFrame("Frame")
facingError:RegisterEvent("UI_ERROR_MESSAGE")
facingError:SetScript("OnEvent", function (self, event, errorType, message)
    if event == "UI_ERROR_MESSAGE" and errorType == 263 then
        local x, y, z = ObjectPosition("player")
        ClickToMove(x + 5, y, z)
    end
end)

local bindFrame = CreateFrame("Frame")
bindFrame:RegisterEvent("LOOT_BIND_CONFIRM")
bindFrame:SetScript("OnEvent", function (self, event, slot, ...)
    if event == "LOOT_BIND_CONFIRM" then
        print("Залутай шмотку")
        
    end
end)