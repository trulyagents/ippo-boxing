# spec: stances, loadouts, skill data

step 5 of best-of-both. g2: one shared skill module the server and ui both read, per-stance loadouts (two stances, each with its own specials and guard), switch with a key on a cooldown. g1: each style has its own walk/idle/anims and a style punch, styles unlock through a short quest. names are mine, nothing named after manga characters

## one data module
- Shared.Skills: every stance and special in one table, read by the server (rules) and later the ui (skill screen)
- each entry: Name, Type (Stance / Special / Passive), Requirements (stats, other skills), Description
- CanUse(profile, skill) returns a per-requirement breakdown like g2's CanUnlock, so the ui can show ticks and crosses later
- no stats or saving yet (that's step 6), for now everything is unlocked so i can test it

## stances (start with 4, all from the bought anims)
- Orthodox: what we have now. balanced, no changes
- Peek-a-boo: high tight guard. guard damage taken -20%, slips cost 2 less, walk speed -1. hooks out of it are faster. uses g2's peek a boo stance/walk anims
- Outboxer: light on the feet. walk speed +2, jab and cross range +1, but body shots taken drain 25% more stamina. g2 outboxer dash anim for the back slip
- Infighter (crouched): low and close. body shots +20% damage, uppercut startup -15%, but straights you throw have -0.5 range. g2 crouching anims
- each stance changes idle, walk and guard anims, plus a few numbers. punches stay the same anims for now

## loadout
- you pick a primary and a secondary stance
- T is lock-on, so stance switch goes on G
- switching takes 0.4s (can't punch or guard during it) and has a 4s cooldown, a small bar under your name shows it
- each stance has 2 special slots (Z and X). switching stance swaps which specials you have

## specials (first batch, built on the anims we already have)
- Flicker Jab (outboxer): low hand jab from the hip, comes from an odd angle, can't be parried, a bit weaker
- Body Breaker (infighter): heavy left body hook, big stamina drain, slow wind up, telegraphed
- Weave Roll (peek-a-boo): figure-eight bob that chains hooks off each side while moving, costs a lot of stamina, the signature move. g2's weave roll anims
- Lunge Uppercut (infighter / peek-a-boo): step in and drive up from the legs, huge damage, very punishable on a whiff
- Step Counter (orthodox / outboxer): a counter that only works in the counter window, steps in for extra range
- each has its own cooldown, shown on two small slots by the hud

## server
- fighter gets Stance, Loadout, SpecialCooldowns. stance mods applied in setWalk / resolveHit / punch through one Stances lookup
- new remote inputs: "Stance" (switch), "Special" (slot 1 or 2). validated against the loadout and cooldowns, rate limited like the rest
- specials are just moves in CombatConfig with extra flags (CantParry, Steps, OnlyInCounter, Chain), so resolveHit stays one function

## hud
- stance name small under your name, switch cooldown bar
- two special slots with cooldown sweep next to the panel. built in studio like the rest of the hud

## not doing yet
- unlocking / quests / stats, that's step 6 with saving
- per-stance punch anims (only idle/walk/guard swap for now)
- the other 10 styles g1 has

## decided
- G switches stance, Z / X are the two specials
- start with 2 stances (orthodox plus one) and polish them hard before adding more
- the two are orthodox and peek-a-boo, g2 has the most anims for peek-a-boo (idle, guard, 4 walks, jab, cross, hooks, the roll)

## built (first pass)
- stances and specials are tables in CombatConfig (Stances, Specials, Loadout), no separate Skills module yet, that comes with unlocks in step 6
- orthodox: no changes. Z step counter (only out of a counter window, steps in 22, range 9), X double jab (two quick jabs)
- peek-a-boo: guard damage taken x0.8, slips 2 cheaper, walk -1, hooks wind up x0.85. swaps idle, guard, walks, jab, cross, hook. Z weave roll (right, left, right off g2's dempsey roll anims, can walk 8 while rolling), X lunge uppercut (big, slow, beats a duck)
- specials are a Chain of special-only moves (Special = true, the punch keys can't throw them), one stamina cost and a cooldown for the whole chain. a hit during wind up breaks the chain
- special moves have Like = the base punch, so sounds, fx and hit reactions treat them like that punch (Config.feelOf)
- stance box sits right of the hud panel: stance name on the brush banner, G cooldown bar, two cream tags with a dark sweep for the special cooldowns. step counter stays dark until a counter window is open
- controls card got G and Z / X rows
- tested in studio: switch, cooldown, walk speed, lunge, roll and double jab all land on the partner, no errors

## still to tune
- the roll and lunge impact times are guesses from the keyframes (0.6 / 0.5 / 0.4), check them by eye
- numbers on every special are first guesses
