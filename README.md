# pokepz

Personal Project Zomboid (Build 42) mod experiment. Pokémon data and sprites are pulled at build time from [PokeAPI](https://pokeapi.co) and turned into Lua data tables.

> Personal use only. Generated output (`out/`) and the API cache (`.pokecache/`) are gitignored and must not be committed — the sprites and names belong to Nintendo / Game Freak / The Pokémon Company.

## Requirements

- .NET 10 SDK (uses a file-based app — no project file needed)
- Project Zomboid Build 42 (stable 42.20+)

## Usage

```
dotnet run PokeFetch.cs -- --gen 1 --max 10                    # quick smoke test
dotnet run PokeFetch.cs -- --gen 1 --out "%USERPROFILE%\Zomboid\mods"
dotnet run PokeFetch.cs -- --gen all --art official             # all generations, large artwork
```

| Option | Default | Description |
|---|---|---|
| `--gen <1 \| 1,2 \| all>` | `1` | Generations to include |
| `--max <n>` | none | Cap species count (testing) |
| `--art <sprite \| official>` | `sprite` | Small game sprites or official artwork |
| `--out <dir>` | `./out` | Where the `PokeZomboid` mod folder is written |
| `--cache <dir>` | `./.pokecache` | JSON response cache |
| `--concurrency <n>` | `4` | Parallel requests (keep it low — be nice to PokeAPI) |

Every API response is cached on disk, so re-runs are near-instant.

## Generated mod layout

```
PokeZomboid/
├── common/
└── 42/
    ├── mod.info
    └── media/
        ├── lua/
        │   ├── shared/PokeZomboid/
        │   │   ├── Species.lua      -- dex id, name, genus, types, base stats, capture/growth, flavor, sprite path
        │   │   ├── Evolutions.lua   -- trigger, level, item, happiness, time-of-day
        │   │   ├── TypeChart.lua    -- 18-type damage chart (non-neutral entries only)
        │   │   └── Helpers.lua      -- getSpecies, typeMultiplier, statAtLevel, levelEvolution
        │   └── client/
        │       └── PokeZomboid_Client.lua  -- getSpriteTexture + load check
        └── ui/PokeZomboid/sprites/{id}.png
```

After enabling the mod, check `console.txt` in your Zomboid folder for:

```
[PokeZomboid] Loaded N species, 18 types
```

## Lua API

```lua
local s = PokeZomboid.getSpecies(25)            -- or "pikachu"
PokeZomboid.statAtLevel(s, "hp", 50)            -- stat keys: hp, atk, def, spa, spd, spe
PokeZomboid.typeMultiplier("water", s.types)    -- 0, 0.25, 0.5, 1, 2, 4
PokeZomboid.levelEvolution(s.id, 22)            -- first qualifying level-up evolution, or nil
PokeZomboid.getSpriteTexture(s.id)              -- client only
```

## Roadmap

- [x] Build-time data + sprite fetcher
- [ ] Capture item (roll against `captureRate`, store on player mod data)
- [ ] Party UI using sprite textures
- [ ] Companion creatures on the B42 animal system
- [ ] Combat vs. zombies with type multipliers

Full phased plan, data model and open questions: [PLAN.md](PLAN.md).
