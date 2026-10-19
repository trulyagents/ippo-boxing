# progression

stats, unlocks and saving (step 6). numbers live in src/shared/Stats.luau

- 6 stats from g2: power, stamina, technique, endurance, speed, willpower. 0 to 100, each one scales a combat number in a straight line up to its max bonus
- power = damage, stamina = cheaper punches, technique = guard damage, endurance = less damage taken, speed = faster startup, willpower = more courage
- gym trains 4 of them with a rhythm drill: heavy bag power, small bags technique, jump ropes stamina, mitts speed
- endurance and willpower only grow in fights (clean hits taken, getting up)
- unlocks: peek-a-boo and 3 of the specials need stats, double jab is open. dummies skip the checks
- saving is ProfileStore (copied from forgotten fates), stats go on the player as StatPower etc for a ui later
- studio saves to its own store (BoxersStudio) so testing never touches live data. needs api access on in game settings
- not done yet: a jump rope anim (bags and mitts play the real punch anims)

## menu
- M or the corner button opens it, nothing else stays on screen. won't open when locked on, down or stunned, and closes itself if a fight starts
- stats tab: radar (6 spokes + edges the script places) and a bar per stat. styles tab: a card per stance in the loadout, cloned from the StyleCard template, specials rows cloned from SpecialRow
- the only popup during play is "+1 POWER" on whole point gains, fight gains of 0.1 stay quiet
- X only closes by clicking, the X key is a special

## spar first
- training only counts after landing 10 clean hits (dummies count) in the last 30 min, or a finished ring match. otherwise the prompt says SPAR FIRST
- endurance from getting hit needs the same, so standing afk next to the partner does nothing

## drills
- every station has its own minigame, all graded on the server (Stats.Drills):
  - heavy bag, Charge: hold space or click, let go in the gold (1s held, perfect +-0.08, good +-0.2). 5 reps
  - bag work, Combo: notes slide in with M1/M2/E on them, throw that punch on the beat, wrong key is a miss. 10 beats
  - jump rope, Rhythm: press on the beat, skips go from 0.6s apart down to 0.36s. 16 beats
  - mitts, Reaction: the mitt flashes at a random moment (server sends the cue live), hit it under 0.25s for perfect, 0.38 for good. early presses do nothing, slow ones miss. 8 reps
- the client only sends Hit (with the punch for combos), Down and Up for the charge. beats are perfect within 0.07s, good within 0.15. the server takes the player's ping off, more than 3 presses a rep counts nothing
- gain is 2 for a perfect run, scaled by score, to one decimal
- a drill puts you in fight mode and stands you square in front of the equipment, no walking till it's done
- landed reps throw the punch anim and swing the bag on its rope
- still needs the spar first rule, except while you're on the quest line
- rotated frames don't clip their children, so the drill panel isn't tilted like the menu
- jump rope prop: the server sets Skipping on the character for the jump rope drill, JumpRopeProp (client, runs for everyone you can see) clones the handles off a rack rope into the gloves and draws the rope as a Beam between them. the beam's ends get turned every frame so the arc swings down, back, over the head and out front, timed off the skip anim so it passes under the feet at the top of each skip
