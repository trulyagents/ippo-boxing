# spec: head/body blocking + weave mode

step 1 of best-of-both. high/low guard idea from g1, weave mode idea from g2. numbers are mine, neither file had server code

## guard height
- hold F = guard. high or low comes from camera pitch: look down past about 25 degrees = low guard, otherwise high. same look-down trick g1 uses for body punches, so later looking down while punching = body shot too
- high guard: blocks head shots like now (straights fully, hooks chip 40% through). body shots land clean, full damage and full stamina drain
- low guard: blocks body shots fully, no chip, stamina drain halved. head shots land clean +10% (you dropped your hands)
- switching high/low takes 0.12s and you're not blocking during it, so guessing wrong actually costs you
- wrong guard = "OPEN" callout on the hit
- guard meter and guard break same as now

## weave mode
- hold space = weave mode. lower stance, walk speed 6. you can still punch out of it, that's how counters get set up
- while holding space:
  - A / D = slip left / right. dodges straights (jab, cross, uppercut)
  - W = duck under. dodges hooks, gets punished by uppercuts (1.5x like now)
  - S = pull back. dodges everything but costs the most
- slips never dodge body shots except pull back (g2 rule)
- slip i-frames 0.35s like now, clean slip still opens the 0.7s counter window
- cooldown between slips drops to 0.45s in weave mode so you can chain a weave
- each slip costs 10 stamina, +3 for each extra slip within 1.5s so you can't weave forever
- space alone no longer ducks. the quick slip is now hold space + direction

## guard bobbing (g2)
- hold F and space together = blocking weave. a slip in this mode gets only 0.12s of i-frames, but you keep your guard up after it. costs 6 stamina
- safer but no counter window

## server changes
- Guard remote takes "High" | "Low" | false instead of true/false. server checks the value and rate limits like now
- new remote input "Weave" true/false, slips only accepted while weave mode is on
- attributes: GuardHeight ("High"/"Low"/nil) replaces Guarding, Weaving (bool)
- dummies: sparring partner picks high or low guard based on what you threw last, so it can be opened up

## anims
- high guard: current Guard (OrthodoxStance_Block)
- low guard: g1's "low guard"
- weave mode loop: need one. try g2's weave/peekaboo stance first, if none fits i keyframe a low bob
- slips: current SlipLeft/Right/Back, duck = current SlipDuck
- blocked body shot: BlockLeft/Right reused for now

## decided
- camera pitch for high/low (mobile still needs a button later)
- built and tested, see combat.md
