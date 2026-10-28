local Party = PokeZomboid.Party

test("ensure creates current-version save data once", function()
    local player = newTestPlayer()
    local d = Party.ensure(player)
    T.eq(d.version, Party.VERSION)
    T.eq(d.nextUid, 1)
    T.eq(#d.party, 0)
    T.eq(#d.box, 0)
    T.ok(d.dex.seen and d.dex.caught)
    T.eq(Party.ensure(player), d, "second call returns the same table")
    T.eq(player:getModData().PokeZomboid, d)
end)

test("ensure upgrades unversioned data without losing creatures", function()
    local player = newTestPlayer()
    player:getModData().PokeZomboid = { party = { { uid = 1, speciesId = 3, level = 5, exp = 100, curHp = 10 } } }
    local d = Party.ensure(player)
    T.eq(d.version, Party.VERSION)
    T.eq(#d.party, 1)
    T.eq(d.party[1].speciesId, 3)
    T.eq(d.nextUid, 2, "nextUid skips past existing uids")
    T.ok(d.box and d.dex)
end)

test("ensure refuses data from a newer mod version", function()
    local player = newTestPlayer()
    player:getModData().PokeZomboid = { version = Party.VERSION + 1, party = {}, box = {} }
    T.errors(function() Party.ensure(player) end)
end)

test("newCreature starts at full HP with exp for its level", function()
    local c = Party.newCreature(1, 5)
    T.eq(c.speciesId, 1)
    T.eq(c.level, 5)
    T.eq(c.exp, 135)
    T.eq(c.curHp, 19)
    T.eq(Party.maxHp(c), 19)
    T.eq(c.uid, nil, "uid is assigned by add")
    T.eq(c.caughtBall, "poke")
end)

test("newCreature clamps level and rejects unknown species", function()
    T.eq(Party.newCreature(3, 0).level, 1)
    T.eq(Party.newCreature(3, 250).level, 100)
    T.errors(function() Party.newCreature(999, 5) end)
end)

test("newCreature records ball and capture time", function()
    T.setWorldHours(42.5)
    local c = Party.newCreature(3, 5, { ball = "ultra" })
    T.eq(c.caughtBall, "ultra")
    T.eq(c.caughtAtHours, 42.5)
    T.setWorldHours(0)
end)

test("add fills party to 6 then overflows to box", function()
    local player = newTestPlayer()
    for i = 1, 6 do T.eq(Party.add(player, Party.newCreature(3, 5)), "party") end
    T.eq(Party.add(player, Party.newCreature(1, 5)), "box")
    local d = Party.ensure(player)
    T.eq(#d.party, 6)
    T.eq(#d.box, 1)
    T.eq(d.box[1].uid, 7)
    T.eq(d.nextUid, 8)
    T.ok(d.dex.caught[1] and d.dex.seen[1] and d.dex.caught[3])
    T.eq(d.dex.caught[2], nil)
end)

test("findByUid searches party and box", function()
    local player = newTestPlayer()
    for i = 1, 7 do Party.add(player, Party.newCreature(3, 5)) end
    local c, where, index = Party.findByUid(player, 7)
    T.eq(c.uid, 7)
    T.eq(where, "box")
    T.eq(index, 1)
    local _, where2 = Party.findByUid(player, 2)
    T.eq(where2, "party")
    T.eq(Party.findByUid(player, 99), nil)
end)

test("addExp below the next level only adds exp", function()
    local c = Party.newCreature(1, 5)
    local events = Party.addExp(c, 10)
    T.eq(#events, 0)
    T.eq(c.exp, 145)
    T.eq(c.level, 5)
end)

test("addExp level-up raises max and current HP by the same amount", function()
    local c = Party.newCreature(1, 5)
    c.curHp = 10
    local events = Party.addExp(c, 44) -- 135 -> 179 = level 6 exactly
    T.eq(c.level, 6)
    T.eq(#events, 1)
    T.eq(events[1].type, "levelUp")
    T.eq(events[1].level, 6)
    T.eq(Party.maxHp(c), 21)
    T.eq(c.curHp, 12)
end)

test("addExp across many levels reports each level then evolution", function()
    local c = Party.newCreature(1, 5)
    local events = Party.addExp(c, 2535 - 135) -- exactly level 16
    T.eq(c.level, 16)
    T.eq(#events, 12)
    T.eq(events[1].level, 6)
    T.eq(events[11].level, 16)
    T.eq(events[12].type, "canEvolve")
    T.eq(events[12].to, 2)
    T.eq(c.curHp, 40)
end)

test("addExp caps at level 100", function()
    local c = Party.newCreature(3, 99)
    Party.addExp(c, 10000000)
    T.eq(c.level, 100)
    T.eq(c.exp, PokeZomboid.expForLevel("fast", 100))
    T.eq(#Party.addExp(c, 500), 0)
end)

test("addExp leaves a fainted creature at 0 HP", function()
    local c = Party.newCreature(1, 5)
    c.curHp = 0
    Party.addExp(c, 44)
    T.eq(c.level, 6)
    T.eq(c.curHp, 0)
end)

test("addExp ignores zero and negative amounts", function()
    local c = Party.newCreature(1, 5)
    T.eq(#Party.addExp(c, 0), 0)
    T.eq(#Party.addExp(c, -50), 0)
    T.eq(c.exp, 135)
end)

test("evolve keeps identity and scales HP proportionally", function()
    local c = Party.newCreature(1, 16)
    c.uid, c.nickname, c.curHp = 5, "Sprout", 20
    Party.evolve(c, 2)
    T.eq(c.speciesId, 2)
    T.eq(c.uid, 5)
    T.eq(c.nickname, "Sprout")
    T.eq(c.level, 16)
    T.eq(Party.maxHp(c), 45)
    T.eq(c.curHp, 23) -- 20/40 of 45 = 22.5, rounded
end)

test("evolve: full HP stays full, damaged never rounds to 0, fainted stays fainted", function()
    local full = Party.newCreature(1, 16)
    Party.evolve(full, 2)
    T.eq(full.curHp, 45)

    local low = Party.newCreature(4, 1)
    low.curHp = 1
    Party.evolve(low, 3)
    T.eq(low.curHp, 1)

    local fainted = Party.newCreature(1, 16)
    fainted.curHp = 0
    Party.evolve(fainted, 2)
    T.eq(fainted.curHp, 0)
end)

test("evolve rejects unknown species", function()
    T.errors(function() Party.evolve(Party.newCreature(1, 16), 999) end)
end)

test("heal restores max HP", function()
    local c = Party.newCreature(1, 16)
    c.curHp = 0
    Party.heal(c)
    T.eq(c.curHp, 40)
end)
