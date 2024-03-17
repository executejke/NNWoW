local nn = ...

local Gapa = {}

local timer

function Gapa.hitEnemy()
    local objects = Objects()

    for key, value in pairs(objects) do
        print(nn.UnitName(value))
    end
        
end


return Gapa