local nn = ...

local ticker

local Rotation = {} 

local Targets = {} 

local restorePowerItems = {
    food = {
        {name = "Conjured Muffin", level = 1},
        {name = "Conjured Bread", level = 5},
        {name = "Conjured Rye", level = 15},
        {name = "Conjured Pumpernickel", level = 25},
        {name = "Conjured Sourdough", level = 35},
        {name = "Conjured Sweet Roll", level = 45}
    },
    water = {
        {name = "Conjured Water", level = 1},
        {name = "Conjured Fresh Water", level = 5},
        {name = "Conjured Purified Water", level = 15},
        {name = "Conjured Spring Water", level = 25},
        {name = "Conjured Mineral Water", level = 35},
        {name = "Conjured Sparkling Water", level = 45},
    },
}

local i = 1

local ti = 1 

local target

local Auras = {
    {name = "Arcane Intellect", isActive = false},
    {name = "Frost Armor", isActive = false},
}

local auraFrame = CreateFrame("Frame")

local auraTicker

local mana = nil

local health = nil

local auraCounter = 0

local count = 0

while true do 
   local spellName, spellSubName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
   if not spellName then
      break
   end

   local spellID = select(2, GetSpellBookItemInfo(i, BOOKTYPE_SPELL))
   local spellInfo = {GetSpellInfo(spellID)}

   table.insert( Rotation, i, {spellName, spellInfo[4], spellInfo[6]})
--    print("Заклинание: " .. spellName)
--    print("ID заклинания: " .. spellID)
--    print("Стоимость маны: " .. (spellInfo[4] or "N/A"))
--    print("Дистанция: " .. (spellInfo[6] or "N/A"))
   
   i = i + 1
end



local function setTargets()
    local objects = ObjectManager("Unit" or 5) or {} 

    for k, v in ipairs(objects) do 
        if nn.UnitName(v) == "Great Goretusk" or nn.UnitName(v) == "Goretusk" or nn.UnitName(v) == "Fleshripper" then
            if not UnitIsDead(v) then  
                Targets = {}
                table.insert(Targets, v) 
            end
        end
    end
    if #Targets > 0 then
        target = Targets[1]
        else print("Пустовато")
    end
end

local function checkBuffs()
    if UnitAffectingCombat("player") then
        return
    end
    local allBuffsActive = true
    for _, buff in ipairs(Auras) do
        
        local buffFound = false
        for i = 1, 10 do
            local name = UnitBuff("player", i)
            if name == buff.name then
                buffFound = true
                break
            end
        end
        
        if not buffFound then
            CastSpellByName(buff.name, "player")
            
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

local function onLootUnit(self, event, ...)
    if event == "LOOT_CLOSED" then
        setTargets()
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

local frame = createMainFrame() 
local buttonsHeight = 22; 
local allLines = createBorderLine(frame) 
local centerFrame = (math.ceil(frame:GetHeight()) - buttonsHeight) / 2 

local function start()
    setTargets()
    checkBuffs()
    if target then
        ticker = C_Timer.NewTicker(0.2, function ()
            TargetUnit(target)
            local distance = Distance("player", target)
            local x, y, z = ObjectPosition("target")
            local x1, y1, z1 = ObjectPosition("player")
            local moveThreshold = 35
            local castThreshold = 30
            local isCasting = false
            if distance > moveThreshold then
                ClickToMove(x, y, z)
                isCasting = false
            elseif distance <= castThreshold or (isCasting and distance <= moveThreshold) then
                ClickToMove(x1,y1,z1)
                CastSpellByName("Frostbolt", target)
                isCasting = true
            end
            if UnitExists(target) then
                if UnitIsDead(target) and CanLootUnit(target) then
                    ObjectInteract(target)
                end
            end
        end)
    else print("cancel")
    end
end

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

local stopButton = CreateFrame("Button", "Stop", frame, "UIPanelButtonTemplate")
stopButton:SetSize(80, buttonsHeight)
stopButton:SetPoint("LEFT", startButton, "RIGHT", 10, 0)
stopButton:SetText("Stop")
stopButton:SetScript("OnClick", function()
    if ticker then
        ticker:Cancel()
    end
    restoreMana()
    -- print(getPowerPercentage().mana, getPowerPercentage().health)
    -- nn.Unlock("UseAction", "7")
    -- print(GetItemCount(7))
    -- local id = GetContainerItemID(1, 4)
    -- local itemName = GetItemInfo(id)
    -- print(itemName)
    -- nn.Unlock("UseAction", "11")
    print(mana)
end)

local optionButton = CreateFrame("Button", "Options", frame, "UIPanelButtonTemplate")
optionButton:SetSize(80, buttonsHeight)
optionButton:SetPoint("Bottom", startButton, "Bottom", 50, -centerFrame)
optionButton:SetText("Options")
optionButton:SetScript("OnClick", function()
    if not options then
        local optionFrame = CreateFrame("Frame", "options", UIParent)
        optionFrame:SetSize(600, 600)
        optionFrame:SetPoint("CENTER")
        optionFrame:EnableMouse(true)
        optionFrame:SetMovable(true)
        optionFrame:RegisterForDrag("LeftButton")
        optionFrame:SetScript("OnDragStart", optionFrame.StartMoving)
        optionFrame:SetScript("OnDragStop", optionFrame.StopMovingOrSizing)
        optionFrame:SetScript("OnHide", function() optionFrame:SetShown(false) end)


        local background = optionFrame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(true)
        background:SetColorTexture(0, 0, 0, 0.5)

        local closeButton = CreateFrame("Button", "CloseButton", optionFrame, "UIPanelCloseButton")
        closeButton:SetPoint("TOPRIGHT", optionFrame, "TOPRIGHT")
        closeButton:SetScript("OnClick", function() optionFrame:Hide() end)

    
        local titleText = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetPoint("TOP", 0, -20)
        titleText:SetText("Options")

        local inputHealth = CreateFrame("EditBox", "inputHealth", optionFrame, "InputBoxTemplate")
        inputHealth:SetPoint("TOPLEFT", 20, -60)
        inputHealth:SetSize(140, 30)
        inputHealth:SetAutoFocus(false)
        inputHealth:SetMaxLetters(3)
        inputHealth:SetNumeric(true)

        local healthLabel = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        healthLabel:SetPoint("TOP", inputHealth, "TOP", 10, 10)
        healthLabel:SetText("Set Health % For Restore Health")

        local inputMana = CreateFrame("EditBox", "inputHealth", optionFrame, "InputBoxTemplate")
        inputMana:SetPoint("TOPLEFT", 20, -110)
        inputMana:SetSize(140, 30)
        inputMana:SetAutoFocus(false)
        inputMana:SetMaxLetters(3)
        inputMana:SetNumeric(true)

        local manaLabel = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        manaLabel:SetPoint("TOP", inputMana, "TOP", 10, 10)
        manaLabel:SetText("Set Health % For Restore Mana")

        local confirmButton = CreateFrame("Button", nil, optionFrame, "GameMenuButtonTemplate")
        confirmButton:SetPoint("LEFT", inputHealth, "RIGHT", 0, 0)
        confirmButton:SetSize(40, 20)
        confirmButton:SetText("OK")
        confirmButton:SetNormalFontObject("GameFontNormalSmall")
        confirmButton:SetHighlightFontObject("GameFontHighlightSmall")

        confirmButton:SetScript("OnClick", function() mana = inputHealth:GetText() end)

        optionFrame:Show()
    else
        options:SetShown(not options:IsShown())
    end
end)


frame:SetScript("OnEvent", onLootUnit)
frame:RegisterEvent("LOOT_CLOSED")