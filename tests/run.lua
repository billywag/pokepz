-- Lua 5.1 test harness for PokeZomboid's pure logic. Run from the repo root:
--   lua5.1 tests/run.lua
-- Stubs the handful of PZ globals the shared code touches, loads tiny made-up fixtures
-- instead of the generated data, then runs every test file listed below.

local MOD = "mod/media/lua/"

-- ---------------------------------------------------------------- PZ stubs
Events = setmetatable({}, {
    __index = function(t, name)
        local ev = { handlers = {} }
        function ev.Add(fn) table.insert(ev.handlers, fn) end
        function ev.Remove(fn)
            for i, h in ipairs(ev.handlers) do if h == fn then table.remove(ev.handlers, i) return end end
        end
        rawset(t, name, ev)
        return ev
    end,
})

-- ZombRand(n) returns an integer in [0, n)
function ZombRand(n) return math.random(0, n - 1) end
function getTexture(path) return { path = path } end
function isDebugEnabled() return true end

local worldHours = 0
function getGameTime() return { getWorldAgeHours = function() return worldHours end } end

-- Fake IsoPlayer: just enough for getModData()
function newTestPlayer()
    local md = {}
    return { getModData = function() return md end }
end

-- ---------------------------------------------------------------- tiny test framework
local passed, failed, current = 0, 0, nil
local failures = {}

T = {}

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

local function fail(msg, level)
    error(msg, (level or 2) + 1)
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        fail((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.near(actual, expected, eps, msg)
    if math.abs(actual - expected) > (eps or 1e-9) then
        fail((msg and (msg .. ": ") or "") .. "expected ~" .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.ok(cond, msg)
    if not cond then fail(msg or "expected truthy value", 2) end
end

function T.errors(fn, msg)
    if pcall(fn) then fail(msg or "expected an error", 2) end
end

function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        table.insert(failures, current .. " > " .. name .. "\n    " .. tostring(err))
    end
end

-- Deterministic rand for tests: returns the queued values in order, ignoring n
function T.seq(...)
    local vals, i = { ... }, 0
    return function(n)
        i = i + 1
        local v = vals[i]
        assert(v ~= nil, "T.seq ran out of values")
        assert(v >= 0 and v < n, "T.seq value " .. v .. " out of range for rand(" .. n .. ")")
        return v
    end
end

function T.setWorldHours(h) worldHours = h end

-- ---------------------------------------------------------------- load code under test
local function load(path) dofile(path) end

load("tests/fixtures/Species.lua")
load("tests/fixtures/Evolutions.lua")
load("tests/fixtures/TypeChart.lua")
load("tests/fixtures/GrowthRates.lua")
load(MOD .. "shared/PokeZomboid/Helpers.lua")
load(MOD .. "shared/PokeZomboid/Party.lua")
load(MOD .. "shared/PokeZomboid/Capture.lua")

-- ---------------------------------------------------------------- run
local files = {
    "tests/test_helpers.lua",
    "tests/test_party.lua",
    "tests/test_capture.lua",
}

for _, f in ipairs(files) do
    current = f
    local chunk, err = loadfile(f)
    if not chunk then
        failed = failed + 1
        table.insert(failures, f .. "\n    " .. err)
    else
        local ok, e = pcall(chunk)
        if not ok then
            failed = failed + 1
            table.insert(failures, f .. " (top level)\n    " .. tostring(e))
        end
    end
end

for _, f in ipairs(failures) do print("FAIL " .. f) end
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
