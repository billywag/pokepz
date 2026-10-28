// PokeFetch.cs — build-time fetcher for a personal Project Zomboid (Build 42) mod.
// Pulls species data, type chart, evolutions and sprites from PokeAPI, caches everything
// locally, and emits a ready-to-load mod folder with Lua data tables.
//
// Requires the .NET 10 SDK (file-based apps).
//
//   dotnet run PokeFetch.cs -- --gen 1
//   dotnet run PokeFetch.cs -- --gen 1,2,3 --art official --out "%USERPROFILE%\Zomboid\mods"
//   dotnet run PokeFetch.cs -- --gen all
//
// Options:
//   --gen <1 | 1,2 | all>          Generations to include (default: 1)
//   --max <n>                      Cap the number of species (handy for testing)
//   --art <sprite | official>      Small game sprites (default) or large official artwork
//   --out <dir>                    Where the PokeZomboid mod folder is written (default: ./out)
//   --cache <dir>                  JSON cache folder (default: ./.pokecache)
//   --concurrency <n>              Parallel requests (default: 4 — be nice to PokeAPI)
//
// Re-runs are fast: every API response is cached on disk, and existing sprites are skipped.

#:property PublishAot=false

using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

var opt = Options.Parse(args);
var api = new PokeApi(opt.CacheDir, opt.Concurrency);
var modRoot = Path.Combine(opt.OutDir, "PokeZomboid");
var b42 = Path.Combine(modRoot, "42");
var luaShared = Path.Combine(b42, "media", "lua", "shared", "PokeZomboid");
var luaClient = Path.Combine(b42, "media", "lua", "client");
var spriteDir = Path.Combine(b42, "media", "ui", "PokeZomboid", "sprites");
foreach (var d in new[] { Path.Combine(modRoot, "common"), luaShared, luaClient, spriteDir })
    Directory.CreateDirectory(d);

Console.WriteLine($"Generations: {string.Join(",", opt.Generations)} | Art: {opt.Art} | Out: {Path.GetFullPath(modRoot)}");

// ---------------------------------------------------------------- 1. Species list
var speciesRefs = new List<(int Id, string Url)>();
foreach (var gen in opt.Generations)
{
    var g = await api.GetJson($"https://pokeapi.co/api/v2/generation/{gen}/");
    foreach (var s in g["pokemon_species"]!.AsArray())
    {
        var url = s!["url"]!.GetValue<string>();
        speciesRefs.Add((IdFromUrl(url), url));
    }
}
speciesRefs = speciesRefs.DistinctBy(s => s.Id).OrderBy(s => s.Id).ToList();
if (opt.Max > 0) speciesRefs = speciesRefs.Take(opt.Max).ToList();
Console.WriteLine($"Species to fetch: {speciesRefs.Count}");

// ---------------------------------------------------------------- 2. Species + default form
int done = 0;
var species = (await Task.WhenAll(speciesRefs.Select(r => LoadSpecies(r.Url))))
    .OrderBy(s => s.Id).ToList();
Console.WriteLine();

// ---------------------------------------------------------------- 3. Evolution chains
var included = species.Select(s => s.Key).ToHashSet();
var idByKey = species.ToDictionary(s => s.Key, s => s.Id);
var chainUrls = species.Select(s => s.ChainUrl).OfType<string>().Distinct().ToList();
var chains = await Task.WhenAll(chainUrls.Select(api.GetJson));
var evolutions = new List<Evo>();
foreach (var c in chains) Walk(c["chain"]!, evolutions);
Console.WriteLine($"Evolution links: {evolutions.Count}");

// ---------------------------------------------------------------- 4. Type chart
var skipTypes = new HashSet<string> { "unknown", "shadow", "stellar" };
var typeList = await api.GetJson("https://pokeapi.co/api/v2/type/?limit=100");
var typeNames = typeList["results"]!.AsArray()
    .Select(t => t!["name"]!.GetValue<string>())
    .Where(n => !skipTypes.Contains(n)).ToList();
var typeNodes = await Task.WhenAll(typeNames.Select(n => api.GetJson($"https://pokeapi.co/api/v2/type/{n}/")));
var typeChart = new SortedDictionary<string, SortedDictionary<string, double>>();
for (int i = 0; i < typeNames.Count; i++)
{
    var rel = typeNodes[i]["damage_relations"]!;
    var row = new SortedDictionary<string, double>();
    void Add(string field, double mult)
    {
        foreach (var t in rel[field]!.AsArray())
        {
            var n = t!["name"]!.GetValue<string>();
            if (!skipTypes.Contains(n)) row[n] = mult;
        }
    }
    Add("double_damage_to", 2);
    Add("half_damage_to", 0.5);
    Add("no_damage_to", 0);
    typeChart[typeNames[i]] = row;
}
Console.WriteLine($"Types: {typeChart.Count}");

// ---------------------------------------------------------------- 5. Sprites
int spritesDone = 0, spritesMissing = 0;
await Task.WhenAll(species.Select(async s =>
{
    if (s.SpriteUrl is null) { Interlocked.Increment(ref spritesMissing); return; }
    var path = Path.Combine(spriteDir, $"{s.Id}.png");
    if (!File.Exists(path))
        await File.WriteAllBytesAsync(path, await api.GetBytes(s.SpriteUrl));
    Console.Write($"\rSprites: {Interlocked.Increment(ref spritesDone)}/{species.Count}");
}));
Console.WriteLine(spritesMissing > 0 ? $"  ({spritesMissing} species had no sprite)" : "");

// ---------------------------------------------------------------- 6. Emit mod files
var utf8 = new UTF8Encoding(false); // no BOM — a BOM breaks Lua
var stamp = $"-- Generated by PokeFetch.cs from PokeAPI on {DateTime.Now:yyyy-MM-dd HH:mm}. Do not edit by hand; re-run the fetcher.";

File.WriteAllText(Path.Combine(b42, "mod.info"),
    "name=PokeZomboid\nid=PokeZomboid\ndescription=Personal build. Pokemon data and sprites pulled from PokeAPI.\n", utf8);

// Species.lua
var sb = new StringBuilder();
sb.AppendLine(stamp);
sb.AppendLine("PokeZomboid = PokeZomboid or {}");
sb.AppendLine("PokeZomboid.Species = PokeZomboid.Species or {}");
sb.AppendLine("local S = PokeZomboid.Species");
foreach (var s in species)
{
    int St(string k) => s.Stats.GetValueOrDefault(k);
    sb.Append($"S[{s.Id}] = {{ id={s.Id}, key={L(s.Key)}, name={L(s.Name)}, genus={L(s.Genus)}, ");
    sb.Append($"types={{{string.Join(", ", s.Types.Select(L))}}}, ");
    sb.Append($"stats={{hp={St("hp")}, atk={St("attack")}, def={St("defense")}, spa={St("special-attack")}, spd={St("special-defense")}, spe={St("speed")}}}, ");
    sb.Append($"height={s.Height}, weight={s.Weight}, captureRate={s.CaptureRate}, baseHappiness={s.BaseHappiness}, ");
    sb.Append($"growthRate={L(s.GrowthRate)}, legendary={B(s.Legendary)}, mythical={B(s.Mythical)}, ");
    sb.Append($"flavor={L(s.Flavor)}, sprite={(s.SpriteUrl is null ? "nil" : L($"media/ui/PokeZomboid/sprites/{s.Id}.png"))} }}");
    sb.AppendLine();
}
File.WriteAllText(Path.Combine(luaShared, "Species.lua"), sb.ToString(), utf8);

// Evolutions.lua — keyed by the species that evolves
sb.Clear();
sb.AppendLine(stamp);
sb.AppendLine("PokeZomboid = PokeZomboid or {}");
sb.AppendLine("PokeZomboid.Evolutions = PokeZomboid.Evolutions or {}");
sb.AppendLine("local E = PokeZomboid.Evolutions");
foreach (var grp in evolutions.GroupBy(e => e.From).OrderBy(g => g.Key))
{
    var items = grp.Select(e =>
    {
        var parts = new List<string> { $"to={e.To}", $"trigger={L(e.Trigger)}" };
        if (e.MinLevel is int lv) parts.Add($"minLevel={lv}");
        if (e.Item is not null) parts.Add($"item={L(e.Item)}");
        if (e.HeldItem is not null) parts.Add($"heldItem={L(e.HeldItem)}");
        if (e.MinHappiness is int h) parts.Add($"minHappiness={h}");
        if (e.TimeOfDay is not null) parts.Add($"timeOfDay={L(e.TimeOfDay)}");
        return "{ " + string.Join(", ", parts) + " }";
    });
    sb.AppendLine($"E[{grp.Key}] = {{ {string.Join(", ", items)} }}");
}
File.WriteAllText(Path.Combine(luaShared, "Evolutions.lua"), sb.ToString(), utf8);

// TypeChart.lua — only non-neutral multipliers are stored; missing = 1x
sb.Clear();
sb.AppendLine(stamp);
sb.AppendLine("PokeZomboid = PokeZomboid or {}");
sb.AppendLine($"PokeZomboid.Types = {{ {string.Join(", ", typeChart.Keys.Select(L))} }}");
sb.AppendLine("PokeZomboid.TypeChart = {");
foreach (var (atk, row) in typeChart)
    sb.AppendLine($"    {atk} = {{ {string.Join(", ", row.Select(kv => $"{kv.Key}={kv.Value.ToString(CultureInfo.InvariantCulture)}"))} }},");
sb.AppendLine("}");
File.WriteAllText(Path.Combine(luaShared, "TypeChart.lua"), sb.ToString(), utf8);

// Helpers.lua — hand-written logic, regenerated each run so it stays in sync with the data shape
File.WriteAllText(Path.Combine(luaShared, "Helpers.lua"), """
    -- PokeZomboid helpers (shared: safe on client and server)
    PokeZomboid = PokeZomboid or {}

    -- Look up by national dex id (number) or key ("pikachu")
    function PokeZomboid.getSpecies(idOrKey)
        if type(idOrKey) == "number" then return PokeZomboid.Species[idOrKey] end
        if not PokeZomboid._byKey then
            PokeZomboid._byKey = {}
            for _, s in pairs(PokeZomboid.Species) do PokeZomboid._byKey[s.key] = s end
        end
        return PokeZomboid._byKey[idOrKey]
    end

    -- Damage multiplier of an attacking type against a list of defender types
    function PokeZomboid.typeMultiplier(attackType, defenderTypes)
        local row = PokeZomboid.TypeChart[attackType] or {}
        local m = 1
        for _, t in ipairs(defenderTypes) do
            local v = row[t]
            if v ~= nil then m = m * v end
        end
        return m
    end

    function PokeZomboid.getEvolutions(id)
        return PokeZomboid.Evolutions[id] or {}
    end

    -- Main-series stat formula, simplified: no IVs/EVs, neutral nature
    function PokeZomboid.statAtLevel(species, stat, level)
        local base = species.stats[stat]
        if stat == "hp" then
            return math.floor((2 * base * level) / 100) + level + 10
        end
        return math.floor((2 * base * level) / 100) + 5
    end

    -- Returns the first level-up evolution this species qualifies for at the given level, or nil
    function PokeZomboid.levelEvolution(id, level)
        for _, e in ipairs(PokeZomboid.getEvolutions(id)) do
            if e.trigger == "level-up" and e.minLevel and level >= e.minLevel then return e end
        end
        return nil
    end
    """ + "\n", utf8);

// Client: load check + sprite helper
File.WriteAllText(Path.Combine(luaClient, "PokeZomboid_Client.lua"), """
    -- PokeZomboid client bootstrap
    PokeZomboid = PokeZomboid or {}

    function PokeZomboid.getSpriteTexture(id)
        local s = PokeZomboid.Species[id]
        if not s or not s.sprite then return nil end
        return getTexture(s.sprite)
    end

    local function onGameStart()
        local n = 0
        for _ in pairs(PokeZomboid.Species or {}) do n = n + 1 end
        print("[PokeZomboid] Loaded " .. n .. " species, " .. #(PokeZomboid.Types or {}) .. " types")
    end

    Events.OnGameStart.Add(onGameStart)
    """ + "\n", utf8);

Console.WriteLine($"Done. Mod written to {Path.GetFullPath(modRoot)}");

// ================================================================ local functions

async Task<Species> LoadSpecies(string url)
{
    var s = await api.GetJson(url);
    var defUrl = s["varieties"]!.AsArray()
        .First(v => v!["is_default"]!.GetValue<bool>())!["pokemon"]!["url"]!.GetValue<string>();
    var p = await api.GetJson(defUrl);

    var stats = p["stats"]!.AsArray().ToDictionary(
        x => x!["stat"]!["name"]!.GetValue<string>(),
        x => x!["base_stat"]!.GetValue<int>());
    var types = p["types"]!.AsArray()
        .OrderBy(t => t!["slot"]!.GetValue<int>())
        .Select(t => t!["type"]!["name"]!.GetValue<string>()).ToList();

    var sprite = opt.Art == "official"
        ? p["sprites"]?["other"]?["official-artwork"]?["front_default"]?.GetValue<string>()
        : p["sprites"]?["front_default"]?.GetValue<string>();

    var key = s["name"]!.GetValue<string>();
    var result = new Species(
        Id: s["id"]!.GetValue<int>(),
        Key: key,
        Name: English(s["names"], "name") is { Length: > 0 } n ? n : key,
        Genus: English(s["genera"], "genus"),
        Types: types,
        Stats: stats,
        Height: p["height"]?.GetValue<int>() ?? 0,
        Weight: p["weight"]?.GetValue<int>() ?? 0,
        CaptureRate: s["capture_rate"]?.GetValue<int>() ?? 0,
        BaseHappiness: s["base_happiness"]?.GetValue<int>() ?? 0,
        GrowthRate: s["growth_rate"]?["name"]?.GetValue<string>() ?? "medium",
        Legendary: s["is_legendary"]?.GetValue<bool>() ?? false,
        Mythical: s["is_mythical"]?.GetValue<bool>() ?? false,
        Flavor: Clean(English(s["flavor_text_entries"], "flavor_text")),
        SpriteUrl: sprite,
        ChainUrl: s["evolution_chain"]?["url"]?.GetValue<string>());

    Console.Write($"\rSpecies: {Interlocked.Increment(ref done)}/{speciesRefs.Count}");
    return result;
}

void Walk(JsonNode node, List<Evo> list)
{
    var from = node["species"]!["name"]!.GetValue<string>();
    foreach (var next in node["evolves_to"]!.AsArray())
    {
        var to = next!["species"]!["name"]!.GetValue<string>();
        var d = next["evolution_details"]!.AsArray().FirstOrDefault();
        if (included.Contains(from) && included.Contains(to))
        {
            var tod = d?["time_of_day"]?.GetValue<string>();
            list.Add(new Evo(
                idByKey[from], idByKey[to],
                d?["trigger"]?["name"]?.GetValue<string>() ?? "unknown",
                d?["min_level"]?.GetValue<int>(),
                d?["item"]?["name"]?.GetValue<string>(),
                d?["held_item"]?["name"]?.GetValue<string>(),
                d?["min_happiness"]?.GetValue<int>(),
                string.IsNullOrEmpty(tod) ? null : tod));
        }
        Walk(next, list);
    }
}

// Latest English entry (newest game for flavor text)
static string English(JsonNode? arr, string field) =>
    arr?.AsArray()
        .LastOrDefault(e => e?["language"]?["name"]?.GetValue<string>() == "en")?[field]?.GetValue<string>() ?? "";

static string Clean(string s) => Regex.Replace(s.Replace("\u00AD", ""), @"\s+", " ").Trim();

static int IdFromUrl(string url) => int.Parse(url.TrimEnd('/').Split('/').Last(), CultureInfo.InvariantCulture);

static string L(string? s) => s is null
    ? "nil"
    : "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "").Replace("\n", "\\n") + "\"";

static string B(bool b) => b ? "true" : "false";

// ================================================================ types

record Species(int Id, string Key, string Name, string Genus, List<string> Types, Dictionary<string, int> Stats,
    int Height, int Weight, int CaptureRate, int BaseHappiness, string GrowthRate,
    bool Legendary, bool Mythical, string Flavor, string? SpriteUrl, string? ChainUrl);

record Evo(int From, int To, string Trigger, int? MinLevel, string? Item, string? HeldItem, int? MinHappiness, string? TimeOfDay);

sealed class Options
{
    public List<int> Generations { get; private set; } = [1];
    public int Max { get; private set; }
    public string Art { get; private set; } = "sprite";
    public string OutDir { get; private set; } = "out";
    public string CacheDir { get; private set; } = ".pokecache";
    public int Concurrency { get; private set; } = 4;

    public static Options Parse(string[] args)
    {
        var o = new Options();
        for (int i = 0; i < args.Length; i++)
        {
            string Next() => i + 1 < args.Length ? args[++i] : throw new ArgumentException($"Missing value for {args[i]}");
            switch (args[i])
            {
                case "--gen":
                    var v = Next();
                    o.Generations = v.Equals("all", StringComparison.OrdinalIgnoreCase)
                        ? Enumerable.Range(1, 9).ToList()
                        : v.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Select(int.Parse).ToList();
                    break;
                case "--max": o.Max = int.Parse(Next()); break;
                case "--art":
                    o.Art = Next().ToLowerInvariant();
                    if (o.Art is not ("sprite" or "official")) throw new ArgumentException("--art must be 'sprite' or 'official'");
                    break;
                case "--out": o.OutDir = Environment.ExpandEnvironmentVariables(Next()); break;
                case "--cache": o.CacheDir = Environment.ExpandEnvironmentVariables(Next()); break;
                case "--concurrency": o.Concurrency = Math.Clamp(int.Parse(Next()), 1, 16); break;
                default: throw new ArgumentException($"Unknown option {args[i]}");
            }
        }
        return o;
    }
}

sealed class PokeApi
{
    readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(60) };
    readonly SemaphoreSlim _gate;
    readonly string _cache;

    public PokeApi(string cacheDir, int concurrency)
    {
        _cache = cacheDir;
        Directory.CreateDirectory(_cache);
        _gate = new SemaphoreSlim(concurrency);
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("PokeZomboid-PersonalBuild/1.0");
    }

    public async Task<JsonNode> GetJson(string url)
    {
        var file = Path.Combine(_cache, Convert.ToHexString(SHA1.HashData(Encoding.UTF8.GetBytes(url))) + ".json");
        if (File.Exists(file)) return JsonNode.Parse(await File.ReadAllTextAsync(file))!;
        var text = Encoding.UTF8.GetString(await Fetch(url));
        await File.WriteAllTextAsync(file, text);
        return JsonNode.Parse(text)!;
    }

    public Task<byte[]> GetBytes(string url) => Fetch(url);

    async Task<byte[]> Fetch(string url)
    {
        await _gate.WaitAsync();
        try
        {
            for (int attempt = 1; attempt <= 5; attempt++)
            {
                HttpResponseMessage resp;
                try { resp = await _http.GetAsync(url); }
                catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
                {
                    if (attempt == 5) throw;
                    await Task.Delay(500 * attempt * attempt);
                    continue;
                }
                using (resp)
                {
                    if (resp.IsSuccessStatusCode) return await resp.Content.ReadAsByteArrayAsync();
                    var code = (int)resp.StatusCode;
                    if (code != (int)HttpStatusCode.TooManyRequests && code < 500)
                        throw new HttpRequestException($"HTTP {code} for {url}");
                }
                await Task.Delay(500 * attempt * attempt);
            }
            throw new HttpRequestException($"Gave up on {url}");
        }
        finally { _gate.Release(); }
    }
}
