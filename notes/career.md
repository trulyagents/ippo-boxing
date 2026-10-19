# career

fight record, rank and quests. lists in src/shared/Career.luau, saving in src/server/Career.luau

- record: wins, losses, draws, ko wins from ring matches. quitting a match mid fight counts as a loss (written before the profile closes)
- rank points: win +25, ko win +10 more, loss -15 (never under 0), draw +5. ranks rookie 0, prospect 100, contender 250, ranked 500, title challenger 900, champion 1400
- wins and rank show in the player list (leaderstats)
- quests: one at a time in order, the first ones walk a new player through sparring, the drills, then the ring. each gives a small stat bump. QUEST DONE pops when one finishes
- while you still have quests left the spar first rule is off for drills
- menu has a RECORD tab (rank, progress to the next one, record, current quest). one NEXT: line sits under the menu button, hidden while the menu is open and once every quest is done
- not done: daily quests, rewards past stats (money, gear), a rank badge over heads
