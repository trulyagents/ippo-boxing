# progression

stats, unlocks and saving (step 6). numbers live in src/shared/Stats.luau

- 6 stats from g2: power, stamina, technique, endurance, speed, willpower. 0 to 100, each one scales a combat number in a straight line up to its max bonus
- power = damage, stamina = cheaper punches, technique = guard damage, endurance = less damage taken, speed = faster startup, willpower = more courage
- gym trains 4 of them with a hold prompt: heavy bag power, small bags technique, jump ropes stamina, mitts speed. server owns the cooldown
- endurance and willpower only grow in fights (clean hits taken, getting up)
- unlocks: peek-a-boo and 3 of the specials need stats, double jab is open. dummies skip the checks
- saving is ProfileStore (copied from forgotten fates), stats go on the player as StatPower etc for a ui later
- studio saves to its own store (BoxersStudio) so testing never touches live data. needs api access on in game settings
- not done yet: stats screen (build it in studio), server-timed rhythm minigames, spar before training counts, a training anim
