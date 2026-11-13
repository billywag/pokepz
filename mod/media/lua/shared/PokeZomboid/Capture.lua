-- PokeZomboid capture formula (shared, pure). Simplified Gen 3+: one roll, no shake checks.
PokeZomboid = PokeZomboid or {}
PokeZomboid.Capture = PokeZomboid.Capture or {}
local Capture = PokeZomboid.Capture

Capture.BALLS = { poke = 1.0, great = 1.5, ultra = 2.0 }

function Capture.ballBonus(ball)
    local b = Capture.BALLS[ball]
    if not b then error("Unknown ball " .. tostring(ball)) end
    return b
end

-- Catch value a in [1, 255]: ((3*maxHp - 2*curHp) * captureRate * ballBonus) / (3*maxHp)
function Capture.chance(captureRate, curHp, maxHp, ballBonus)
    if maxHp <= 0 then error("maxHp must be positive") end
    curHp = math.max(0, math.min(curHp, maxHp))
    local a = ((3 * maxHp - 2 * curHp) * captureRate * ballBonus) / (3 * maxHp)
    return math.max(1, math.min(255, a))
end

-- Returns caught (boolean), a. rand(n) must return an integer in [0, n); defaults to ZombRand.
function Capture.roll(captureRate, curHp, maxHp, ballBonus, rand)
    local a = Capture.chance(captureRate, curHp, maxHp, ballBonus)
    if a >= 255 then return true, a end
    rand = rand or ZombRand
    return rand(256) < a, a
end
