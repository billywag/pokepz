local P = PokeZomboid

test("getSpecies by id and key", function()
    T.eq(P.getSpecies(1).key, "sproutling")
    T.eq(P.getSpecies("emberpup").id, 3)
    T.eq(P.getSpecies("nope"), nil)
end)

test("typeMultiplier combines dual types", function()
    T.eq(P.typeMultiplier("fire", { "grass", "poison" }), 2)
    T.eq(P.typeMultiplier("grass", { "grass", "poison" }), 0.25)
    T.eq(P.typeMultiplier("normal", { "fire" }), 1)
    T.eq(P.typeMultiplier("unknown-type", { "fire" }), 1)
end)

test("statAtLevel hp and other stats", function()
    local s = P.getSpecies(1)
    T.eq(P.statAtLevel(s, "hp", 5), 19)
    T.eq(P.statAtLevel(s, "hp", 16), 40)
    T.eq(P.statAtLevel(s, "atk", 50), 54)
end)

test("levelEvolution only fires on level-up triggers at minLevel", function()
    T.eq(P.levelEvolution(1, 15), nil)
    T.eq(P.levelEvolution(1, 16).to, 2)
    T.eq(P.levelEvolution(3, 100), nil, "item evolution is not a level evolution")
    T.eq(P.levelEvolution(2, 100), nil, "no evolutions")
end)

test("expForLevel reads the growth table and clamps", function()
    T.eq(P.expForLevel("medium", 1), 0)
    T.eq(P.expForLevel("medium", 10), 1000)
    T.eq(P.expForLevel("medium-slow", 5), 135)
    T.eq(P.expForLevel("medium", 0), 0)
    T.eq(P.expForLevel("medium", 150), 1000000)
    T.eq(P.expForLevel("not-a-rate", 10), 1000, "unknown rate falls back to medium")
end)

test("levelForExp is the inverse of expForLevel", function()
    T.eq(P.levelForExp("medium", 0), 1)
    T.eq(P.levelForExp("medium", 999), 9)
    T.eq(P.levelForExp("medium", 1000), 10)
    T.eq(P.levelForExp("medium", 99999999), 100)
    for lv = 1, 100 do
        T.eq(P.levelForExp("medium-slow", P.expForLevel("medium-slow", lv)), lv, "round trip at " .. lv)
    end
end)
