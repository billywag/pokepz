-- Test fixture: made-up species in the same shape PokeFetch.cs generates. Not real data.
PokeZomboid = PokeZomboid or {}
PokeZomboid.Species = {}
local S = PokeZomboid.Species
S[1] = { id=1, key="sproutling", name="Sproutling", genus="Seed Creature", types={"grass", "poison"},
    stats={hp=45, atk=49, def=49, spa=65, spd=65, spe=45}, height=7, weight=69, captureRate=45, baseHappiness=50,
    growthRate="medium-slow", legendary=false, mythical=false, flavor="Test fixture.", sprite="media/ui/PokeZomboid/sprites/1.png" }
S[2] = { id=2, key="sprouter", name="Sprouter", genus="Seed Creature", types={"grass", "poison"},
    stats={hp=60, atk=62, def=63, spa=80, spd=80, spe=60}, height=10, weight=130, captureRate=45, baseHappiness=50,
    growthRate="medium-slow", legendary=false, mythical=false, flavor="Test fixture.", sprite="media/ui/PokeZomboid/sprites/2.png" }
S[3] = { id=3, key="emberpup", name="Emberpup", genus="Ember Creature", types={"fire"},
    stats={hp=39, atk=52, def=43, spa=60, spd=50, spe=65}, height=6, weight=85, captureRate=255, baseHappiness=50,
    growthRate="fast", legendary=false, mythical=false, flavor="Test fixture.", sprite=nil }
S[4] = { id=4, key="stonewall", name="Stonewall", genus="Rock Creature", types={"rock"},
    stats={hp=100, atk=100, def=150, spa=30, spd=30, spe=20}, height=20, weight=3000, captureRate=3, baseHappiness=0,
    growthRate="slow", legendary=true, mythical=false, flavor="Test fixture.", sprite="media/ui/PokeZomboid/sprites/4.png" }
