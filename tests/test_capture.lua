local Capture = PokeZomboid.Capture

test("ball bonuses", function()
    T.eq(Capture.ballBonus("poke"), 1.0)
    T.eq(Capture.ballBonus("great"), 1.5)
    T.eq(Capture.ballBonus("ultra"), 2.0)
    T.errors(function() Capture.ballBonus("master-of-none") end)
end)

test("chance at full HP is a third of the capture rate", function()
    T.eq(Capture.chance(45, 19, 19, 1.0), 15)
end)

test("chance rises as HP drops", function()
    T.near(Capture.chance(45, 1, 19, 1.0), (57 - 2) * 45 / 57)
    T.near(Capture.chance(45, 1, 19, 1.5), (57 - 2) * 45 * 1.5 / 57)
    T.ok(Capture.chance(45, 1, 19, 1.0) > Capture.chance(45, 10, 19, 1.0))
end)

test("chance clamps to 255 and has a floor of 1", function()
    T.eq(Capture.chance(255, 1, 19, 2.0), 255)
    T.eq(Capture.chance(3, 100, 100, 1.0), 1)
end)

test("chance treats out-of-range HP sanely", function()
    T.eq(Capture.chance(45, 50, 19, 1.0), 15, "curHp above max is clamped to max")
    T.near(Capture.chance(45, 0, 19, 1.0), 45, 1e-9, "curHp 0 is the best case")
    T.errors(function() Capture.chance(45, 1, 0, 1.0) end)
end)

test("roll succeeds when rand(256) < chance", function()
    T.eq(Capture.roll(45, 19, 19, 1.0, T.seq(14)), true)
    T.eq(Capture.roll(45, 19, 19, 1.0, T.seq(15)), false)
end)

test("roll returns the chance it used", function()
    local _, a = Capture.roll(45, 19, 19, 1.0, T.seq(0))
    T.eq(a, 15)
end)

test("roll at 255 always catches without rolling", function()
    T.eq(Capture.roll(255, 1, 19, 2.0, T.seq()), true)
end)

test("roll defaults to ZombRand", function()
    local caught = Capture.roll(45, 19, 19, 1.0)
    T.eq(type(caught), "boolean")
end)
