# spec: second wind + lasting damage

step 4 of best-of-both. both ideas are g1's: max health drops during a fight, and a courage meter that can trigger a comeback when you're knocked down (their chance tiers, aura, music swap, inner monologue). numbers and lines are mine

## lasting damage
- clean head shots and counters also knock 20% of their damage off your max health for the rest of the fight. blocked and chip damage don't
- max health can't drop below 50
- health comes back slowly: 2 per second after 3s without getting hit, but only up to your current max
- so early on you recover between exchanges, late in a fight you don't. trading gets scarier as the fight goes
- getting up from a knockdown gives you min(the usual 60/40/25, your max health)
- all of it resets on Reset, and later when a new fight starts

## courage
- hidden-ish meter 0 to 100, thin orange bar under guard
- gain: clean hit landed +3, counter +8, clean slip +4, parry +6, getting knocked down +15, getting back up +10
- lose: clean hit taken -2
- dummies have it too

## second wind
- rolls when you get back up from a knockdown, once per fight
- chance by courage: under 30 = 5%, 30-59 = 15%, 60-89 = 35%, 90+ = 70%, 100 = always
- when it fires:
  - you're up instantly, no more mashing
  - +20 max health (can go past 100) and health set to 70% of the new max
  - 8 seconds fired up: stamina regen x2, punch wind up 10% faster, guard takes 25% less damage
  - steam/heat shimmer coming off the body, screen edges go warm, slow-mo beat as you stand
  - a short inner thought line on screen, original ones like "not yet... my legs still work", "i didn't come this far to stay down", "one more round. just one more"
  - courage goes back to 0
- opponent sees "SECOND WIND!" and the aura, so they know to back off

## hud
- health bar gets a dark grey section at the end showing what max health you've lost
- two layer bars (g1): front snaps down fast, a pale ghost chunk trails behind over about 1s so you can see how big the hit was
- courage bar under guard, glows when it's 90+

## server changes
- fighter gets MaxHealthNow, Courage, SecondWindUsed, FiredUpUntil. all published as attributes
- regen in Fighters.tick, courage changes in resolveHit / slip / parry / knockDown / getUp
- getUp rolls the second wind and broadcasts "SecondWind" with the line index
- fired up checked in punch (startup), tick (stamina regen) and resolveHit (guard damage)

## not doing yet
- music swap, there's no fight music yet
- injuries (cuts, swelling) from g1, later step

## decided
- 100 courage is guaranteed
- text lines only for now
- built and tested, see combat.md
