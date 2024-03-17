local nn = ...

local Targets = {}  -- Таблица с целями

-- local Points = {
--     x = -5784, y = -2846, z = 368
-- }

local Points = {
    {x = -10063, y = -1095, z = 28},
    {x = -10080, y = -1000, z = 32},
    {x = -10059, y = -947, z = 36},
    {x = -10063, y = -858, z = 36},
    {x = -10026, y = -711, z = 38},
    {x = -10003, y = -503, z = 39},
}

local step = 1

-- {x = -5916, y = -2908, z = 368}

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
    {name = "Blessing of Wisdom", isActive = false},
    {name = "Retribution Aura"}
}

local Food = {
    food = "Ice Cold Milk",
    water = "Dalaran Sharp"
}

local trainer = {name = "Brandur Ironhammer", x = -4601, y = -898, z = 503}

local foodVendor = {name = "Innkeeper Trelayne", x = -10517, y = -1162, z = 29}

local vendor = {name = "Gavin Gnarltree", x = -10595, y = -1155, z = 31}

local Quality = {Common = nil, Uncommon = nil, Rare = nil, Epic = nil}

local auraFrame = CreateFrame("Frame") -- Фрейм Аур 

local bagFrame = CreateFrame("Frame") -- Фрейм сумки

local deadFrame = CreateFrame("Frame") -- Фрейм смерти

local respawnFrame = CreateFrame("Frame") -- Фрейм возрождения

local combatFrame = CreateFrame("Frame")

local MpAndHpFrame = CreateFrame("Frame")

local target -- Основная цель

local ticker -- Тикер

local auraTicker

local stuck = 0

local timer



function RespawnPlayer()
    CancelActiveTicker()
        RepopMe()
        ticker = C_Timer.NewTicker(0.3, function ()
            local cx, cy, cz = GetCorpsePosition()
            local corpsePos = {x = cx, y = cy, z = cz}
            moveTowardsTarget(corpsePos, 1)
            RetrieveCorpse()
        end)
end

function GetItemQuantity(itemName)
    return GetItemCount(select(1, GetItemInfo(itemName)))
end

function GetHP()
    return math.ceil((UnitHealth("player") / UnitHealthMax("player")) * 100)
end

function GetMP()
    return math.ceil((UnitPower("player") / UnitPowerMax("player")) * 100)
end

function IsFoodEmpty()
    return GetItemCount(select(1, GetItemInfo(Food.food))) <= 1 or GetItemCount(select(1, GetItemInfo(Food.water))) <= 1
end

function BuyFood()
        CancelActiveTicker()
        ticker = C_Timer.NewTicker(0.3, function ()
           local inPoint = moveTowardsTarget(foodVendor, 3)
           if inPoint then
            nn.Unlock("TargetUnit", foodVendor.name, true)
            ObjectInteract("target")
            if GossipFrame:IsShown() then
                C_GossipInfo.SelectOption(96505)
            end
            if MerchantFrame:IsShown() then
                local itemsQuantity = GetMerchantNumItems()
                for i = 1, itemsQuantity do
                    local name = select(1, GetMerchantItemInfo(i))
                    if GetItemQuantity(Food.food) >= 20 and GetItemQuantity(Food.water) >= 20 then
                        target = nil
                        CancelActiveTicker()
                        Start()
                        return
                    end
                    if name == Food.food and GetItemQuantity(Food.food) < 20 then
                        local toBuy = 20 - GetItemQuantity(Food.food)
                        BuyMerchantItem(i, toBuy)
                    elseif name == Food.water and GetItemQuantity(Food.water) < 20 then
                        local toBuy = 20 - GetItemQuantity(Food.water)
                        BuyMerchantItem(i, toBuy)
                    end
                end
            end
           end
        end)
    end

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
    return GetHP() == 100 and GetMP() == 100
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
        if GetHP() <= 50 then
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

function setTargets()
    local objects = ObjectManager("Unit") or {} -- Получаем таблицу с объектами
    local targetsWithDistances = {}

    if #objects > 0 then
        for _, v in ipairs(objects) do
            if nn.UnitName(v) == "Rabid Dire Wolf" or nn.UnitName(v) == "Green Recluse" or nn.UnitName(v) == "Venom Web Spider" or nn.UnitName(v) == "Starving Dire Wolf" or nn.UnitName(v) == "Pygmy Venom Web Spider" then -- Фильтруем таблицу по нужным нам юнитам.
                if not UnitIsDead(v) and not (UnitIsTapDenied(v)) then -- Если юнит жив и не тапнутый, то добавляем его в таблицу
                    local distance = Distance("player", v) -- Получаем расстояние до юнита
                    table.insert(targetsWithDistances, {unit = v, distance = distance}) -- Вставляем юнита и расстояние в таблицу
                end
            end
        end
    end

    table.sort(targetsWithDistances, function(a, b)
        return a.distance < b.distance
    end)

    -- Выбираем ближайшего юнита
    if #targetsWithDistances > 0 then
        target = targetsWithDistances[1].unit -- Ближайший юнит теперь первый в отсортированной таблице
    else
        target = nil
    end
end

-- Кусок гавна нада переделать
function Start()
    if UnitIsDeadOrGhost("player") then
        RespawnPlayer()
        return
    end
    setTargets()
    checkBuffs(Auras)
    if target then
        CancelActiveTicker()
        ticker = C_Timer.NewTicker(0.3, function ()
            if target then
            if IsFoodEmpty() then BuyFood() return end
            if GetHP() <= 50 and not (UnitAffectingCombat("player"))
                or
               GetMP() <= 50 and not (UnitAffectingCombat("player"))
            then
                local x, y, z = ObjectPosition("player")
                ClickToMove(x, y, z)
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
        else
            MoveToPoint()
            end
        end)
    else
        if IsFoodEmpty() then
            BuyFood()
            return
        end
        MoveToPoint()
    end
end

function MoveToPoint()
    CancelActiveTicker()
    ticker = C_Timer.NewTicker(0.3, function ()
       local onPoint = moveTowardsTarget(Points[step], 3)
       setTargets()
        if target then
            CancelActiveTicker()
            Start()
        end
        if onPoint and not target then
            step = step + 1
        end
        if step > #Points then
            step = 1
        end
    end)
end

function onStuck()
    stuck = stuck + 1
        if stuck >= 15 then
            local x, y, z = ObjectPosition("player")
            ClickToMove(math.ceil(x) + 5, math.ceil(y), math.ceil(z))
            nn.Unlock("JumpOrAscendStart")
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
                CancelActiveTicker()
                print("Готово")
                Start()
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
end)

local getpos = CreateFrame("Button", "getpos", frame, "UIPanelButtonTemplate")
getpos:SetSize(80, buttonsHeight)
getpos:SetPoint("CENTER", startButton, "CENTER", 0, -20)
getpos:SetText("getpos")
getpos:SetScript("OnClick", function()
    local x, y, z = ObjectPosition("player")
    print(math.ceil(x), math.ceil(y), math.ceil(z))
end)

local getID = CreateFrame("Button", "getID", frame, "UIPanelButtonTemplate")
getID:SetSize(80, buttonsHeight)
getID:SetPoint("CENTER", startButton, "CENTER", 90, -20)
getID:SetText("getID")
getID:SetScript("OnClick", function()
    print(UnitIsTapDenied(nil))
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
        RespawnPlayer()
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
    auraFrame:SetScript("OnEvent", function (self, event, unit, updateInfo)
    if event == "UNIT_AURA" and unit == "player" then
        setBuffTicker()
        local name, icon, count, type = UnitDebuff("player", 1)
        if type == "Disease" or type == "Poison" then
            CastSpellByName("Purify", "player")
        end
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
        ConfirmLootSlot(slot)
    end
end)
