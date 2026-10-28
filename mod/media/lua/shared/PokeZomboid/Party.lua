-- PokeZomboid party data model (shared, pure apart from player:getModData)
-- Save data lives in player:getModData().PokeZomboid; see PLAN.md "Save data".
PokeZomboid = PokeZomboid or {}
PokeZomboid.Party = PokeZomboid.Party or {}
local Party = PokeZomboid.Party

Party.VERSION = 1
Party.MAX_PARTY = 6
Party.MAX_LEVEL = 100

-- migrations[n] upgrades data from version n to n + 1
local migrations = {
    -- 0 -> 1: unversioned data from early builds; fill in anything missing
    [0] = function(d)
        d.party = d.party or {}
        d.box = d.box or {}
        d.dex = d.dex or {}
        d.dex.seen = d.dex.seen or {}
        d.dex.caught = d.dex.caught or {}
        local maxUid = 0
        for _, list in ipairs({ d.party, d.box }) do
            for _, c in ipairs(list) do
                if c.uid and c.uid > maxUid then maxUid = c.uid end
            end
        end
        d.nextUid = math.max(d.nextUid or 1, maxUid + 1)
    end,
}

-- Create or migrate this player's save data and return it
function Party.ensure(player)
    local md = player:getModData()
    local d = md.PokeZomboid
    if not d then
        d = { version = 0 }
        md.PokeZomboid = d
    end
    local v = d.version or 0
    if v > Party.VERSION then
        error("PokeZomboid save data is version " .. v .. ", this mod only understands up to " .. Party.VERSION)
    end
    while v < Party.VERSION do
        migrations[v](d)
        v = v + 1
        d.version = v
    end
    return d
end

local function speciesOf(speciesId)
    local s = PokeZomboid.getSpecies(speciesId)
    if not s then error("Unknown species " .. tostring(speciesId)) end
    return s
end

function Party.maxHp(c)
    return PokeZomboid.statAtLevel(speciesOf(c.speciesId), "hp", c.level)
end

-- A new creature at full HP. uid is assigned when it is added to a player.
-- opts: { ball = "great", nickname = "..." }
function Party.newCreature(speciesId, level, opts)
    opts = opts or {}
    local s = speciesOf(speciesId)
    level = math.max(1, math.min(Party.MAX_LEVEL, math.floor(level)))
    local c = {
        uid = nil,
        speciesId = s.id,
        nickname = opts.nickname,
        level = level,
        exp = PokeZomboid.expForLevel(s.growthRate, level),
        curHp = 0,
        caughtAtHours = getGameTime():getWorldAgeHours(),
        caughtBall = opts.ball or "poke",
    }
    c.curHp = Party.maxHp(c)
    return c
end

-- Add to the party, or the box when the party is full. Returns "party" or "box".
function Party.add(player, c)
    local d = Party.ensure(player)
    c.uid = d.nextUid
    d.nextUid = d.nextUid + 1
    d.dex.seen[c.speciesId] = true
    d.dex.caught[c.speciesId] = true
    if #d.party < Party.MAX_PARTY then
        table.insert(d.party, c)
        return "party"
    end
    table.insert(d.box, c)
    return "box"
end

-- Returns creature, "party" | "box", index — or nil
function Party.findByUid(player, uid)
    local d = Party.ensure(player)
    for _, where in ipairs({ "party", "box" }) do
        for i, c in ipairs(d[where]) do
            if c.uid == uid then return c, where, i end
        end
    end
    return nil
end

-- Adds experience and applies level-ups. Returns a list of events:
--   { type = "levelUp", level = n }  one per level gained
--   { type = "canEvolve", to = speciesId }  once, if a level-up made a level evolution available
function Party.addExp(c, amount)
    local events = {}
    if amount <= 0 or c.level >= Party.MAX_LEVEL then return events end
    local s = speciesOf(c.speciesId)
    local cap = PokeZomboid.expForLevel(s.growthRate, Party.MAX_LEVEL)
    c.exp = math.min(c.exp + amount, cap)

    local newLevel = PokeZomboid.levelForExp(s.growthRate, c.exp)
    while c.level < newLevel do
        local before = Party.maxHp(c)
        c.level = c.level + 1
        -- Main-series behaviour: current HP rises by however much max HP rose; fainted stays fainted
        if c.curHp > 0 then c.curHp = c.curHp + (Party.maxHp(c) - before) end
        table.insert(events, { type = "levelUp", level = c.level })
    end

    if #events > 0 then
        local evo = PokeZomboid.levelEvolution(c.speciesId, c.level)
        if evo then table.insert(events, { type = "canEvolve", to = evo.to }) end
    end
    return events
end

-- Changes species in place, keeping uid/nickname/level/exp. HP keeps the same fraction of max.
function Party.evolve(c, toSpeciesId)
    speciesOf(toSpeciesId)
    local oldMax = Party.maxHp(c)
    c.speciesId = toSpeciesId
    local newMax = Party.maxHp(c)
    if c.curHp > 0 then
        c.curHp = math.max(1, math.floor(c.curHp * newMax / oldMax + 0.5))
    end
end

function Party.heal(c)
    c.curHp = Party.maxHp(c)
end
