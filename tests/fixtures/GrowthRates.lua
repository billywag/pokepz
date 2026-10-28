-- Test fixture: growth-rate tables built from the main-series formulas (level 1 is always 0 XP,
-- matching PokeAPI). The real GrowthRates.lua is generated from PokeAPI's exact tables.
PokeZomboid = PokeZomboid or {}
PokeZomboid.GrowthRates = {}

local function build(f)
    local t = { 0 }
    for n = 2, 100 do t[n] = math.floor(f(n)) end
    return t
end

PokeZomboid.GrowthRates["fast"] = build(function(n) return 4 * n ^ 3 / 5 end)
PokeZomboid.GrowthRates["medium"] = build(function(n) return n ^ 3 end)
PokeZomboid.GrowthRates["slow"] = build(function(n) return 5 * n ^ 3 / 4 end)
PokeZomboid.GrowthRates["medium-slow"] = build(function(n) return 6 * n ^ 3 / 5 - 15 * n ^ 2 + 100 * n - 140 end)
