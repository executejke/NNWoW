local nn = ...

local ticker -- Тикер

local Rotation = {
    {name = "Crusader Strike", id = 407676},
    {name = "Judgement", id = 20271}
}

local Targets = {}  -- Таблица с целями

local target -- Основная цель

local Quality = {Common = nil, Uncommon = nil, Rare = nil, Epic = nil}

local Auras = {
    {name = "Seal of Righteousness", isActive = false},
    {name = "Blessing of Might", isActive = false}
}

local auraFrame = CreateFrame("Frame") -- Фрейм Аур 

local bagFrame = CreateFrame("Frame") -- Фрейм сумки

local auraTicker

local vendor = {name = "Adlin Pridedrift", x = -6228, y = 320, z = 383}

local mana = nil

local health = nil

local sellTicker

-- Устанавливаем цели в таблицу Targets
local function setTargets()
    local objects = ObjectManager("Unit" or 5) or {} -- Вовзращает таблицу с объектами, "Unit" or 5 возвращает именно объекты юниты.

    for k, v in ipairs(objects) do 
        if nn.UnitName(v) == "Ragged Young Wolf" or nn.UnitName(v) == "Burly Rockjaw Trogg" or nn.UnitName(v) == "Rockjaw Trogg" then -- Фильтруем таблицу по нужным нам юнитам.
            if not UnitIsDead(v) then  -- Если юнит не мертв
                Targets = {}
                table.insert(Targets, v) -- Кладем его в таблицу Targets
            end
        end
    end
    if #Targets > 0 then
        target = Targets[#Targets]
        else print("Пустовато")
    end
end

local function checkBuffs()
    if UnitAffectingCombat("player") then
        return
    end
    local allBuffsActive = true
    for _, buff in ipairs(Auras) do
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

local function setBuffTicker()
    if not auraTicker then
        auraTicker = C_Timer.NewTicker(0.5, checkBuffs)
    end
end

local function getPowerPercentage()
    local power = {
        health = math.ceil((UnitHealth("player") / UnitHealthMax("player")) * 100),
        mana = math.ceil((UnitPower("player") / UnitPowerMax("player")) * 100)
    }
    return power
end

local function getFoodAndWaterCount()
    local items = {
        water = GetItemCount("Conjured Purified Water"),
        food = GetItemCount("Conjured Bread")
    }
    return items
end

local function restoreMana()
    if getPowerPercentage().mana <= 50 and not (UnitAffectingCombat("player")) then
        nn.Unlock("UseAction", "7")
    end
end

local function restoreHealth()
    if getPowerPercentage().health <= 50 and not(UnitAffectingCombat("player")) then
        nn.Unlock("UseAction", "8")
    end
end

local function onDeadUnit(self, event, ...)
    if UnitExists(target) then
        if event == "UNIT_HEALTH_FREQUENT" and UnitIsDead(target) and CanLootUnit(target) then
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

local function moveTowardsTarget(target, stopDistance)
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
        end

        if path and #path > 1 then
            
            local targetPointIndex = #path > 2 and 3 or 2
            if path[targetPointIndex] then 
                ClickToMove(tonumber(path[targetPointIndex].x), tonumber(path[targetPointIndex].y), tonumber(path[targetPointIndex].z))
            else
                ClickToMove(tonumber(path[#path].x), tonumber(path[#path].y), tonumber(path[#path].z))
            end
        else
            print(error("PATH OR TARGET NOT EXISTS"))
        end
end

local function onLootUnit(self, event, ...)
    if event == "LOOT_CLOSED" then
        setTargets()
    end
end

local function mainRotation()
    StartAttack()
    CastSpellByName(Rotation[1].name)
    CastSpellByName(Rotation[2].name)
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

local frame = createMainFrame() -- Создаем фрейм
local buttonsHeight = 22; -- Высота кнопки
local allLines = createBorderLine(frame) -- Создаем все линии вокруг фрейма
local centerFrame = (math.ceil(frame:GetHeight()) - buttonsHeight) / 2 -- Рассчитываем центр основного фрейма

-- Кусок гавна нада переделать
local function start()
    setTargets()
    checkBuffs()
    if target then
        if ticker then
            ticker:Cancel()
        end
        ticker = C_Timer.NewTicker(1, function ()
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
        end)
    end
end

local function sellItems()
    if sellTicker then
        sellTicker:Cancel()
    end
    local bagId = 0
    local slot = 1
    local numBags = 4
    if ticker then
        ticker:Cancel()
    end
    sellTicker = C_Timer.NewTicker(0.5, function ()
        moveTowardsTarget(vendor, 3)
        nn.Unlock("TargetUnit", vendor.name, true)
        ObjectInteract("target")
        if MerchantFrame:IsShown() then
            if bagId <= numBags then
                local slots = C_Container.GetContainerNumSlots(bagId)
                if slot <= slots then
                    C_Container.UseContainerItem(bagId, slot)
                    slot = slot + 1
                else
                    bagId = bagId + 1
                    slot = 1
                end
            else
                print("Готово")
                start()
                sellTicker:Cancel()
                sellTicker = nil
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
    start()
    auraFrame:RegisterEvent("UNIT_AURA", "player")
    auraFrame:SetScript("OnEvent", function (self, event, unit)
    if event == "UNIT_AURA" and unit == "player" then
        setBuffTicker()
    end
end)
end)

-- Правая кнопка
local stopButton = CreateFrame("Button", "Stop", frame, "UIPanelButtonTemplate")
stopButton:SetSize(80, buttonsHeight)
stopButton:SetPoint("LEFT", startButton, "RIGHT", 10, 0)
stopButton:SetText("Stop")
stopButton:SetScript("OnClick", function()
    if ticker then
        ticker:Cancel()
    end
end)

local getC = CreateFrame("Button", "getC", frame, "UIPanelButtonTemplate")
getC:SetSize(80, buttonsHeight)
getC:SetPoint("CENTER", startButton, "CENTER", 50, -20)
getC:SetText("getpos")
getC:SetScript("OnClick", function()
    print(ObjectPosition("player"))
end)



frame:SetScript("OnEvent", onLootUnit)
frame:RegisterEvent("LOOT_CLOSED")

bagFrame:RegisterEvent("BAG_UPDATE")
bagFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" then
       local space = checkBagSpace()
       if space <= 3 then
        sellItems()
       end
    end
end)