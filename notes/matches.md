# matches

ring matches from g2's join pads (Map.GymRing.JoinPads Red and Blue). numbers in CombatConfig.Match

- prompt on the corner outside the ropes joins, again leaves. walk 10 studs off your spot and you lose it
- both pads taken = match: reset both, corners, 3 sec freeze, FIGHT, 3 rounds of 90s with 10s breaks
- only the two in the match can hit each other (Fighter.Match), outsiders and dummies can't touch them
- KO ends it, leaving or dying is a forfeit, otherwise a decision on damage dealt + 15 per knockdown. equal = draw
- someone down at the bell still has to beat the count
- after: winner shout, 6s, both reset and put outside the ropes, counts as a spar for training
- the sparring partner (Map.Gym.SparSpot) and the punching bag dummy (Map.Gym.BagSpot) both live upstairs, the ring is only for matches
- ring has MatchOn, MatchRound, MatchEndsAt attributes, the hud clock (BoxingHUD.RoundClock) reads them within 70 studs
- players spawn on the sidewalk outside the gym door (Map.PlayerSpawn), not in the ring anymore
- g2 used 180s rounds and 3 or 5 round limits, i went shorter for roblox attention spans
- rings: every ring is a model tagged BoxingRing (Shared.Rings). the gym's is workspace.Ring (its JoinPads is an ObjectValue to Map.GymRing.JoinPads), plus Map.Basement.Ring1-4, clones of GymRing dropped 18 down. Matches runs one setup per ring. a spot belongs to the nearest ring with height counted triple, so the gym and basement don't hear each other
- basement: opened it. the baseplate had a hole cut over the building (Baseplate North/South/East/West), the stairwell cover is gone. old baseplate and cover are in ServerStorage.BasementBackup
- ai opponents: alone on a pad for Config.Match.AIWait (15s) and an AI boxer (AIBoxer, random name, shirt and style) takes the other corner. skill climbs with your rank. it's worth Config.Match.AIPoints (half) of the rank points, still counts for quests and record. destroyed after the fight
- the upstairs bag and sparring partner use the same AIBoxer brain now
- spectating: WATCH stamp (StarterGui.Spectate) or K shows while any ring has a fight and you're not in one, goes ring to ring, past the last it stops. camera circles the two boxers. the client tells the server (Watch remote, rate limited, checks the tag) so intro, shouts and round calls reach watchers. round clock and music follow the watched ring (client Watch module)
- not done: spectator seats, betting, a real 2 player spectate test
- the wall interval timer (Map.GymRing.IntervalTimer, g2's prop) works now: IntervalTimer.client shows the round, minutes and seconds left off the ring's MatchRound/MatchEndsAt and lights the 10 bars for the share of the round left. 0:00 between fights. digits are my own 7 segment pngs (art/timer/make_digits.py), unlit segments are fully clear because the gym lights brighten decals so even faint ones read as lit
- match intro: after both pads are taken, both boxers stand frozen in their corners for Config.Match.Intro (4.5s) while MatchIntro (StarterGui, built in studio) slides in a red and a blue card with name, rank, record (wins-losses-draws, KOs) and their avatar headshot on the right, VS pops with the bell, then it clears and ROUND 1 gets called
- corner between rounds: MatchCorner (StarterGui, built in studio) slides in for the 10s break. this round's punches landed, damage and knockdowns for both, ahead/behind/even on the cards, and g1's corner pick: 1 hydrate (stamina back), 2 treatment (15 max health back off the lasting damage, then 30% of what's missing), 3 pep talk (+35 courage). Config.Match.Corner. one pick per break, server checks you're in the break and haven't picked (CornerPick remote). guard always comes back, nothing else does unless you pick
- corner stool: ReplicatedStorage.BoxingGear.CornerStool (parts, cushion top at 0.9 studs, no collision). the server drops one under each boxer at END OF ROUND and sets Sitting on the character, both go at the bell
- CornerSit anim: keyframed by me in blender on the R6 rig (models/anims/PaBPunches.blend), 2s loop. hips 0.56 down, legs 62 deg forward (R6 has no knees so the feet reach the canvas from a low stool). first version dropped the hips 0.9 and the thighs went through the seat, the back edge of a leg block dips about 0.45 below the hip when it swings forward. sized it against an exact copy of the stool in blender after that. legs straight out read better as sitting but looked bad, arms back over the 3.5 stud rope, head back, a heavy breath every second with the arms and head trailing. FighterAnimator plays it while Sitting is on and mutes idle/hurt/gassed
- gotcha: FighterAnimator only plays roles that also have a KeyframeSequence in ReplicatedStorage.BoxingAnims, the id alone isn't enough
- result screen: MatchResult (StarterGui, built in studio) for the 2 fighters. you win/lose/draw and how, whole fight punches and knockdowns, rank points gained or lost, new rank and record. the record is written before the screen now so it shows the new numbers
- both cards use art/menu/card_plain.png, the style card without the halftone strip (the dots made the text hard to read). if images show blank in studio it is studio not fetching, a full studio restart fixed it
- the controls card (H) hides when a ring match starts and H can't open it mid match
- leaving before the first FIGHT bell is no contest: the one who stayed gets no win and no points ("OPPONENT LEFT"), the leaver still takes the loss. stops an alt leaving on cue to farm wins
- resetting mid match now destroys your old body (it used to stay in the game as a ghost fighter), so the match sees you gone and it's a forfeit
