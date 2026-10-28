-- Test fixture: evolution links between the made-up species
PokeZomboid = PokeZomboid or {}
PokeZomboid.Evolutions = {}
local E = PokeZomboid.Evolutions
E[1] = { { to=2, trigger="level-up", minLevel=16 } }
E[3] = { { to=4, trigger="use-item", item="fire-stone" } }
