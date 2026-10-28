# pokepz — Development Plan

Personal Project Zomboid **Build 42** (stable 42.20+) mod that adds capturable, trainable Pokémon-style creatures that fight zombies. Data comes from PokeAPI at build time via `PokeFetch.cs`; everything in-game is Lua.

Status legend: `[x]` done · `[ ]` todo · `(verify)` = confirm against the actual B42 game Lua before relying on it.

---

## Ground rules

- **Personal use only.** Never commit `out/`, `.pokecache/`, sprites, or any generated Lua containing names/flavor text. The repo holds code only.
- **No network at runtime.** PZ's Lua (Kahlua, ~Lua 5.1) is sandboxed. All PokeAPI data is baked in by `PokeFetch.cs`.
- **Generated vs. hand-written Lua.** `Species.lua`, `Evolutions.lua`, `TypeChart.lua` are generated — never hand-edit. Hand-written gameplay code lives in `mod/` (see Phase 1) and is copied into the output by the fetcher.
- **Shared/client/server split.** Pure logic (formulas, data access) → `shared/`. UI, textures, input → `client/`. Authoritative state changes (capture rolls, XP, damage) → `server/` so the mod works in multiplayer later. In single-player, server Lua also runs locally.
- **Source of truth for B42 APIs** is the game's own Lua: `<Steam>/steamapps/common/ProjectZomboid/media/lua/` and `media/scripts/`. Grep it before using any API marked `(verify)`.

---

## Phase 0 — Data pipeline

- [x] `PokeFetch.cs`: species, default form stats/types, evolutions, 18-type chart, sprites → B42 mod folder
- [x] Disk cache keyed by `SHA1(url)` uppercase hex in `.pokecache/`
- [x] Lua helpers: `getSpecies`, `typeMultiplier`, `statAtLevel`, `levelEvolution`, `getSpriteTexture`
- [x] Verified: compiles on .NET 10; mocked-cache run; generated Lua loads in Lua 5.1 and helpers return correct values
- [ ] **First live run** against PokeAPI (`--gen 1`), load in game, confirm `[PokeZomboid] Loaded 151 species, 18 types` in `console.txt`
- [ ] Fix cosmetic progress-line race (`Species: 2/2Species: 1/2`) — print from a single place after `Interlocked.Increment`, or throttle with a lock
- [ ] Move hand-written Lua (`Helpers.lua`, `PokeZomboid_Client.lua`) out of C# string literals into `mod/` source files; fetcher copies `mod/**` into `out/PokeZomboid/42/` verbatim. Easier to edit and lint.
- [ ] Add `expForLevel(growthRate, level)` to helpers (formulas below)
- [ ] Optional: `--moves` flag to fetch level-up learnsets for a later moves system (skip for now; Phase 5 uses type-based attacks)

**Growth-rate formulas** (n = level):
- `fast`: 4n³/5 · `medium` / `medium-fast`: n³ · `slow`: 5n³/4
- `medium-slow`: 6n³/5 − 15n² + 100n − 140
- `slow-then-very-fast` (erratic) and `fast-then-very-slow` (fluctuating): piecewise — implement from PokeAPI's `growth-rate/{name}` `levels` table instead of formulas (fetch it; it gives exact XP per level 1–100). **Preferred:** fetch all 6 growth-rate tables in `PokeFetch.cs` and emit `GrowthRates.lua` — no formulas needed.

---

## Phase 1 — Player data model + debug tools

Goal: own creatures, persist them across saves, no world spawns yet.

**Repo layout to introduce**
```
mod/
  media/lua/shared/PokeZomboid/Party.lua       -- data model + pure functions
  media/lua/shared/PokeZomboid/Capture.lua     -- capture formula (pure)
  media/lua/server/PokeZomboid_Server.lua      -- authoritative mutations
  media/lua/client/PokeZomboid_Debug.lua       -- debug commands
  media/scripts/PokeZomboid_items.txt          -- item definitions
tests/
  run.lua                                       -- Lua 5.1 harness with PZ stubs
  fixtures/                                     -- tiny mock Species/Evolutions/TypeChart
```

**Save data** — `player:getModData().PokeZomboid` (verify persistence in B42 SP + MP):
```lua
{
  version = 1,
  nextUid = 1,
  party = { -- max 6
    { uid=1, speciesId=25, nickname=nil, level=5, exp=125, curHp=20,
      caughtAtHours=0, caughtBall="poke" },
  },
  box = {},                          -- overflow storage, same shape
  dex = { seen = {}, caught = {} },  -- [speciesId] = true
}
```
- `Party.ensure(player)` — create/migrate (`version` field drives migrations)
- `Party.newCreature(speciesId, level)` — computes max HP via `statAtLevel`, sets `exp = expForLevel(...)`
- `Party.add(player, creature)` → party if < 6, else box
- `Party.addExp(creature, amount)` → handles level-ups, returns list of events (`levelUp`, `canEvolve`)
- `Party.evolve(creature, toSpeciesId)` — keeps uid/nickname/level, recalculates HP proportionally
- [ ] Debug (client, only when `isDebugEnabled()` (verify)): give creature by id/name, set level, heal party, wipe save data, print party to console

**Tests:** `lua5.1 tests/run.lua` — stub `Events`, `getTexture`, `ZombRand` (wrap `math.random`), `getGameTime`. Run on every change.

---

## Phase 2 — Items + capture

**Items** (`media/scripts/PokeZomboid_items.txt`) — B42 item script syntax changed from B41; copy the structure of an existing vanilla throwable/consumable (verify): Poké Ball (×1.0), Great Ball (×1.5), Ultra Ball (×2.0), Potion (+20 HP), Revive. Icons can use the fetched item sprites later (`PokeFetch.cs --items`), placeholders first.

**Capture formula** (`Capture.lua`, simplified Gen 3+, no shake checks):
```
a = ((3*maxHp - 2*curHp) * captureRate * ballBonus) / (3*maxHp)
caught = ZombRand(256) < a      -- clamp a to 255
```
- Pure function `Capture.roll(captureRate, curHp, maxHp, ballBonus, rand)` — inject `rand` for tests
- Server applies result, consumes ball, adds to party, marks dex caught

**Loot:** add balls/potions to distributions (verify B42 `ProceduralDistributions` table names) — small chance in toy stores, bedrooms, sporting goods.

Until Phase 4 there are no world targets, so add an interim **Encounter** event: on a random timer while outdoors (or while foraging — verify B42 foraging hooks), roll a wild species weighted by inverse `captureRate`, open a simple encounter window (sprite, name, level, HP bar) with Throw Ball / Run. This is fully playable and exercises capture end to end.

---

## Phase 3 — Party UI

- ISUI panel (`ISCollapsableWindow` subclass — verify B42 base classes) toggled by a hotkey (verify B42 keybinding registration via `keyBinding` / options)
- Six slots: sprite (`getSpriteTexture`), nickname/name, level, HP bar, type labels
- Context actions: rename, reorder, move to box, use Potion, evolve (when `levelEvolution` returns a result — level-up evolutions only; item/trade/happiness ones later)
- Box view: paged list

---

## Phase 4 — Creatures in the world (B42 animal system)

Highest risk / most unknowns. **Spike first, before writing features:**
1. Grep game Lua for animal definitions (verify; likely under `media/lua/shared/Definitions/` and the `IsoAnimal` Java class)
2. Can a mod register a **new animal type** reusing an existing skeleton/animset (e.g. rabbit, dog-sized, deer)?
3. Can an animal be told to **follow** a player and stay tame? (B42 has leash/follow behavior for livestock — verify)
4. Can we hook **damage** from/to an animal and run our own HP?

Plan B if new types aren't moddable: reuse vanilla animals as visual stand-ins (rabbit/deer/etc. tinted) and attach our creature uid in the animal's mod data; show the real sprite above it in UI.

Then:
- [ ] Spawn wild creatures by biome (forest/field/town/water edge by type), level band by distance from spawn or days survived
- [ ] Throw ball at a world animal → capture roll → despawn on success
- [ ] Send out / recall one companion; companion follows player
- [ ] 3D models: out of scope until mechanics work; sprites + stand-ins first

---

## Phase 5 — Combat vs. zombies

- Companion auto-targets nearest zombie within N tiles
- Damage (simplified main-series): `floor(((2*L/5+2) * power * atk/def) / 50 + 2) * typeMult * rand(0.85–1.0)` with a fixed `power` per attack tier; zombies treated as fixed type `normal` (configurable) and fixed def
- Zombies attack companions; at 0 HP the companion faints (recalled, needs Revive)
- XP on zombie kill (`OnZombieDead` (verify)) → `Party.addExp`, level-up toast
- Sandbox options: spawn rate, XP multiplier, zombie "type", friendly-fire toggle

---

## Phase 6 — Multiplayer

- All mutations via `sendClientCommand` → `Events.OnClientCommand` on server; server replies with `sendServerCommand` (verify B42 names)
- Server owns capture rolls, XP, HP; clients render
- Test on a local dedicated server before calling it done

---

## Open questions

- B42 item script format details (copy from vanilla)
- Whether `getModData()` on the player is sufficient for MP persistence or needs global mod data
- Animal-system moddability (Phase 4 spike decides the whole approach)
- Hotkey registration API in B42 options UI

## Suggested next step for a code session

1. Do the Phase 0 live run on your machine and paste the console line + any errors
2. Implement Phase 0 cleanup (move Lua to `mod/`, growth-rate tables)
3. Build `tests/run.lua`, then Phase 1 `Party.lua` + `Capture.lua` test-first
