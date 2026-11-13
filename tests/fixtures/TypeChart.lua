-- Test fixture: a few type relations, same shape as the generated TypeChart.lua
PokeZomboid = PokeZomboid or {}
PokeZomboid.Types = { "fire", "grass", "normal", "poison", "rock" }
PokeZomboid.TypeChart = {
    fire = { fire=0.5, grass=2, rock=0.5 },
    grass = { fire=0.5, grass=0.5, poison=0.5, rock=2 },
    normal = { rock=0.5 },
    poison = { grass=2, poison=0.5, rock=0.5 },
    rock = { fire=2 },
}
