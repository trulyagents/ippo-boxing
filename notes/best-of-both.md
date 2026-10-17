# best of both

what i'm taking from the two bought games. g1 = sold to trulyagents.rbxlx (style-heavy one), g2 = sold to trulyagents (2).rbxlx (clean boxing one, the anims came from here)
- both files are client only, no server scripts. so no real damage numbers, ai, saving or round logic to look at. those i design myself
- ideas and design only, no code. move names that are straight from the manga get renamed

## combat
- head block vs body block (g1). wrong height = it lands. looking down turns hook/cross into a body shot (g1)
- counters tied to the punch you counter (g2). cross counter on a straight hits way harder than one on a jab
- charge punches on hold (g1 slugger)
- status effects as timed child objects that freeze while hitstop/slowmo is on (g1). trades and hyper armor fall out of it
- server owns everything, client only sends inputs (both, i already do this)
- skip: g1 client-side hitboxes, g2 trusting mouse.hit

## defence
- weave mode: hold space + wasd (g2), slips dodge head shots not body (g2)
- guard bobbing: block while weaving with a few i-frames at the start (g2)
- guard meter that breaks (both, i have it)
- parry and clinch (g1)

## stamina, health, ko
- max health drops during a fight so damage sticks (g1)
- two-layer bars, front tweens fast, ghost bar trails slow (g1)
- second wind: when you're down, a courage meter gives a comeback chance, guaranteed at 100. +max health, aura, music change, inner thought line (g1). most on-theme thing in either game
- injuries after fights: cuts, swelling, concussion with screen effects (g1). later

## styles and specials
- shared skill data module that both server and ui read, CanUnlock returns a per-requirement breakdown for the ui (g2)
- per-stance loadouts: primary + secondary stance, each with its own 2 specials and guard, T to switch with a cooldown (g2)
- style punch on its own key that's different per style (g1)
- mastery per style through a short 3-step quest (g1)
- combo passives that need a set sequence, like body hook into lunge uppercut buffs the next special (g2)
- specials gated by stats + skill points + prereqs (both)

## progression
- 6 stats (g2's set: power, stamina, technique, endurance, speed, willpower), capped, shown on a radar chart (g2)
- rhythm training minigames with graded timing (g2), but the server times it, the client just sends click times. g2 lets the client send its own score, don't
- you need to spar before training points count (g1). stops afk farming
- traits rolled at character creation (g1), talents later
- jobs/yen and phone ui (g1). way later, not core

## feel
- impact frame (g1, i have it)
- afterimage arm clones on fast punches (g1)
- camera shake scaled by hit type (g1)
- vfx skipped past 40 studs plus a vfx setting (g1)
- opponent cooldown display as a trait perk (g1)
- combat music swap (g2)

## camera
- g1's lock-on: zoom 5-8, side offset scales with distance up to 1.75. better than mine and way better than g2's
- server faces the body to the target, not the client (g1's client cframe write is an exploit)

## world and menus
- 3d menu rooms for character creation and the skill tree (g2)
- character creator with face parts and colors (g2)
- rebindable keys and mobile buttons (g1)

## order i'd build in
1. head/body blocking + weave mode (finish the core fight)
2. counters by punch type + parry
3. lock-on camera like g1
4. second wind + max health damage
5. stances with loadouts + the skill data module
6. stats + server-timed training
7. everything else
