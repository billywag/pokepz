# CLAUDE.md

Personal Project Zomboid **Build 42** mod with Pokémon-style creatures. Read `PLAN.md` first — it has phases, status, data model and open questions. Update its checkboxes as work lands.

## Hard rules
- Personal use only. Never commit `out/`, `.pokecache/`, sprites, or generated Lua (names/flavor text are Nintendo IP). Code only.
- No runtime network access in PZ Lua — all data is baked in by `PokeFetch.cs`.
- Never hand-edit generated files (`Species.lua`, `Evolutions.lua`, `TypeChart.lua`, `GrowthRates.lua`). Change the fetcher instead.
- Anything marked `(verify)` in PLAN.md: check the game's own Lua in `ProjectZomboid/media/lua` and `media/scripts` before using it. Don't guess B42 APIs from B41 tutorials.

## Stack
- `PokeFetch.cs` — .NET 10 file-based app. Run: `dotnet run PokeFetch.cs -- --gen 1 --max 10`
- Mod code — Lua 5.1 (Kahlua). Keep it 5.1-compatible: no `goto`, no integer division `//`, no `utf8` lib.
- Layout: `shared/` pure logic, `client/` UI/input, `server/` authoritative state.

## Testing
- C#: `dotnet build PokeFetch.cs`
- Offline fetcher test: seed `.pokecache/` with mock JSON. Cache filename = `SHA1(url)` as uppercase hex + `.json`, where `url` is exactly what the fetcher requests (e.g. `https://pokeapi.co/api/v2/generation/1/`, trailing slash included).
- Lua: `lua5.1 tests/run.lua` (harness stubs `Events`, `getTexture`, `ZombRand`, `getGameTime`). Keep pure logic injectable (pass `rand`) so it's testable.

## Conventions
- Global namespace: `PokeZomboid` (always `PokeZomboid = PokeZomboid or {}` at file top; load order between shared files isn't guaranteed)
- Save data: `player:getModData().PokeZomboid`, versioned with a `version` field and migrations in `Party.ensure`
- Stat keys: `hp, atk, def, spa, spd, spe`
- Commits end with the session attribution trailer the environment provides
