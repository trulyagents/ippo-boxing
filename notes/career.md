# career

fight record, rank and quests. lists in src/shared/Career.luau, saving in src/server/Career.luau

- record: wins, losses, draws, ko wins from ring matches. quitting a match mid fight counts as a loss (written before the profile closes)
- rank points: win +25, ko win +10 more, loss -15 (never under 0), draw +5. ranks rookie 0, prospect 100, contender 250, ranked 500, title challenger 900, champion 1400
- wins and rank show in the player list (leaderstats)
- quests: one at a time in order, the first ones walk a new player through sparring, the drills, then the ring. each gives a small stat bump. QUEST DONE pops when one finishes
- while you still have quests left the spar first rule is off for drills
- menu has a RECORD tab (rank, progress to the next one, record, current quest). one NEXT: line sits under the menu button, hidden while the menu is open and once every quest is done
- not done: daily quests, rewards past stats (money, gear), a rank badge over heads
- saving: profilestore autosaves every 5 min, saves on leave and on shutdown, and has the session lock. a match result also saves right away (PlayerData.save after matchResult), so a server crash can't eat a win
- the saved table has Version = 1. new fields just go in the template (Reconcile fills them in). renaming or reshaping one means bumping Version and migrating old saves in PlayerData.load
- the onboarding funnel (creator hub > analytics > funnels): step 1 "Joined" for a brand new player, step n+1 when quest n is done. the drop between two steps shows where new players quit. Career.joined + the quest completion in Career.event
- ranked board: Workspace.Map.Gym.RankBoard (west wall, between the doorways, lives in the place). top 10 by rank points from the OrderedDataStore "RankPoints" ("RankPointsStudio" in studio). written after every match and on join, the board refreshes every 2 min and 10s after a write (the sorted list lags a write by a few seconds). names from UserService, cached
- daily streak (shared/Daily): first login of the utc day. streak +1 if yesterday counted, else back to 1. pays 0.5 per streak day (max day 7 = 3.5) onto your weakest stat, shown on the unlock card 4s after joining. Daily = { Last, Streak } in the profile
