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
- not done: spectator seats, betting, ranked, more than one ring
- the wall interval timer (Map.GymRing.IntervalTimer, g2's prop) works now: IntervalTimer.client shows the round, minutes and seconds left off the ring's MatchRound/MatchEndsAt and lights the 10 bars for the share of the round left. 0:00 between fights. digits are my own 7 segment pngs (art/timer/make_digits.py), unlit segments are fully clear because the gym lights brighten decals so even faint ones read as lit
- match intro: after both pads are taken, both boxers stand frozen in their corners for Config.Match.Intro (4.5s) while MatchIntro (StarterGui, built in studio) slides in a red and a blue card with name, rank and record (wins-losses-draws, KOs), VS pops with the bell, then it clears and ROUND 1 gets called
