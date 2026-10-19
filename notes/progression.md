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
- prompt starts a drill, the server picks beat times from Stats.Drills and sends them, the client draws notes sliding to the hit line (BoxingMenu.Drill)
- the client only sends "Hit", the server grades it against its own clock minus the player's ping. perfect 0.1s, good 0.22s
- only the first press near each beat counts and more than 2 presses per beat counts nothing, so mashing gets 0
- gain is 2 for a perfect run, scaled by score, to one decimal. +1.7 popup on the menu
- a drill puts you in fight mode (boxing stance) and stands you square in front of the bag or mitts, 3.2 studs out, on the open side nearest where you walked up from (worked out once by raycasting the 4 sides). the client does the move, it owns the character. no walking or turning till it's done
- the bags already had g2's rope physics, landed drill punches push them (perfect pushes harder). the server owns the bags so it can swing them
- still needs the spar first rule, except while you're on the quest line
- rotated frames don't clip their children, so the drill panel isn't tilted like the menu
