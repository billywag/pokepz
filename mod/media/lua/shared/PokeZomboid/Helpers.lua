-- PokeZomboid helpers (shared: safe on client and server)
PokeZomboid = PokeZomboid or {}

-- Look up by national dex id (number) or key ("pikachu")
function PokeZomboid.getSpecies(idOrKey)
    if type(idOrKey) == "number" then return PokeZomboid.Species[idOrKey] end
    if not PokeZomboid._byKey then
        PokeZomboid._byKey = {}
        for _, s in pairs(PokeZomboid.Species) do PokeZomboid._byKey[s.key] = s end
    end
    return PokeZomboid._byKey[idOrKey]
end

-- Damage multiplier of an attacking type against a list of defender types
function PokeZomboid.typeMultiplier(attackType, defenderTypes)
    local row = PokeZomboid.TypeChart[attackType] or {}
    local m = 1
    for _, t in ipairs(defenderTypes) do
        local v = row[t]
        if v ~= nil then m = m * v end
    end
    return m
end

function PokeZomboid.getEvolutions(id)
    return PokeZomboid.Evolutions[id] or {}
end

-- Main-series stat formula, simplified: no IVs/EVs, neutral nature
function PokeZomboid.statAtLevel(species, stat, level)
    local base = species.stats[stat]
    if stat == "hp" then
        return math.floor((2 * base * level) / 100) + level + 10
    end
    return math.floor((2 * base * level) / 100) + 5
end

-- Returns the first level-up evolution this species qualifies for at the given level, or nil
function PokeZomboid.levelEvolution(id, level)
    for _, e in ipairs(PokeZomboid.getEvolutions(id)) do
        if e.trigger == "level-up" and e.minLevel and level >= e.minLevel then return e end
    end
    return nil
end

-- Total experience needed to reach a level (1-100), from the baked PokeAPI growth-rate tables
function PokeZomboid.expForLevel(growthRate, level)
    local t = PokeZomboid.GrowthRates[growthRate] or PokeZomboid.GrowthRates["medium"]
    if level < 1 then level = 1 elseif level > #t then level = #t end
    return t[level]
end

-- Highest level whose experience threshold is <= exp
function PokeZomboid.levelForExp(growthRate, exp)
    local t = PokeZomboid.GrowthRates[growthRate] or PokeZomboid.GrowthRates["medium"]
    local level = 1
    while level < #t and t[level + 1] <= exp do level = level + 1 end
    return level
end
