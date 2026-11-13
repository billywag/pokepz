-- PokeZomboid client bootstrap
PokeZomboid = PokeZomboid or {}

function PokeZomboid.getSpriteTexture(id)
    local s = PokeZomboid.Species[id]
    if not s or not s.sprite then return nil end
    return getTexture(s.sprite)
end

local function onGameStart()
    local n = 0
    for _ in pairs(PokeZomboid.Species or {}) do n = n + 1 end
    print("[PokeZomboid] Loaded " .. n .. " species, " .. #(PokeZomboid.Types or {}) .. " types")
end

Events.OnGameStart.Add(onGameStart)
