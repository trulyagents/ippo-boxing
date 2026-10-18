# progression

stats, unlocks and saving (step 6). numbers live in src/shared/Stats.luau

- 6 stats from g2: power, stamina, technique, endurance, speed, willpower. 0 to 100, each one scales a combat number in a straight line up to its max bonus
- power = damage, stamina = cheaper punches, technique = guard damage, endurance = less damage taken, speed = faster startup, willpower = more courage
- gym trains 4 of them with a hold prompt: heavy bag power, small bags technique, jump ropes stamina, mitts speed. server owns the cooldown
- endurance and willpower only grow in fights (clean hits taken, getting up)
- unlocks: peek-a-boo and 3 of the specials need stats, double jab is open. dummies skip the checks
- saving is ProfileStore (copied from forgotten fates), stats go on the player as StatPower etc for a ui later
- studio saves to its own store (BoxersStudio) so testing never touches live data. needs api access on in game settings
- not done yet: server-timed rhythm minigames, spar before training counts, a training anim

## menu
- M or the corner button opens it, nothing else stays on screen. won't open when locked on, down or stunned, and closes itself if a fight starts
- stats tab: radar (6 spokes + edges the script places) and a bar per stat. styles tab: a card per stance in the loadout, cloned from the StyleCard template, specials rows cloned from SpecialRow
- the only popup during play is "+1 POWER" on whole point gains, fight gains of 0.1 stay quiet
- X only closes by clicking, the X key is a special
