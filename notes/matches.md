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
