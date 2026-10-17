# spec: counters by punch type + parry

step 2 of best-of-both. g2: which counter you get depends on what you counter, and a cross counter on a straight is huge. g1: separate parry, plus counters tracked by type. numbers are mine

## how counters work now
- only one kind: clean slip opens 0.7s, next punch does 1.6x
- hitting someone during their wind up just cancels their punch, nothing extra

## counter types

### slip counter (keep)
- clean slip, then punch inside 0.7s = 1.6x. stays the bread and butter one

### read counters (new)
your punch lands while theirs is still winding up. the bonus depends on the matchup, like g2:
- cross into their jab or cross = **cross counter**, 2x damage, 1.6x hitstun, strong impact frame. the big one
- hook into their cross = **hook counter**, 1.7x. hook goes round the straight
- uppercut into their hook = **inside counter**, 1.8x. you're inside the wide punch
- body into their uppercut = **body counter**, 1.5x and double stamina drain. they stood up tall
- jab into anything = **stop**, 1.2x. just cuts their punch off
- anything else landing in their wind up = 1.2x like a stop
- if they're under 35 health, a cross counter is an automatic knockdown (g2 has it as an instant ko, that felt too much)

### punish (new)
- your punch lands during their recovery after a whiff = 1.3x, "PUNISHED"
- makes throwing at air cost something

## parry (g1)
- tap F just before a jab or cross lands. window is the last 0.15s of their wind up
- parry = no damage, their arm gets knocked aside: they're stunned 0.4s and recovery +0.25s. you get a 0.5s counter window at 1.4x
- only straights. hooks, uppercuts and body shots can't be parried, they just hit your guard
- if you mistime it you're just guarding, so it's safe but not free
- no spam: the guard press only counts as a parry if you weren't guarding for the last 0.6s
- costs 4 stamina

## feel
- callout per type: CROSS COUNTER!, HOOK COUNTER!, INSIDE!, BODY COUNTER!, STOP!, PUNISHED!, PARRY!
- cross counter gets the strong impact frame and slow-mo like a knockdown, the rest use the normal counter feel
- parry gets a sharp clack sound and a blue spark on the glove

## server changes
- resolveHit looks at the target's state and Action when the hit lands: Windup + Action = read counter table, Recovery after a whiff = punish
- new table in CombatConfig: Counters[myMove][theirMove] = { Name, Damage, Hitstun }
- guard press records GuardPressedAt. a straight landing within 0.15s of that press, after 0.6s unguarded, is a parry
- Hit broadcasts carry the counter name so the hud and fx can show it

## dummies
- sparring partner parries about 20% of jabs and sometimes answers your cross with a cross counter, so you learn to feint

## anims
- parry: look through the bought games for a parry or deflect (g1 has detroit/reflect counter stuff), else keyframe a quick glove slap
- getting parried: reuse BlockHit for now
- counters use the normal punch anims

## decided
- yes to the low-health cross counter knockdown
- parry on F tap
- built and tested, see combat.md
