# map

gym based on the kamogawa gym look (yellow walls, green mat floor, blue ring, red/white/blue ropes, fluorescent tubes, window wall, lockers, bags on blue frames)

- the building is g2's gym (Workspace/Map/EnterableBuildings/KamogawaGym in sold to trulyagents (2)), the ring is its KamogawaRing from Debris/Rings
- pulled with `tools/pull_model.py`, uploaded as private models with `tools/publish_model.py` (gym 119143050678016, ring 135315736867935), loaded in studio with InsertService:LoadAsset. unions and meshes come through fine that way
- lives in workspace.Map (Gym, GymRing). place only, not in git (build/ is ignored)
- ring centre at 0,0. ring base sits on the gym floor (3.3), canvas top 6.3. it came in sunk 2 studs into the floor, raised it and the FighterSpawns with it
- the ground (Baseplate top) is 2.3, where the front facade ends. the ring room is the street-level floor. the building has a basement down to -18.7 that sat in a slope in g2's map, it's hidden under the baseplate now. floors above at 12.3, 21.3, 30.3, 39.3
- moving it: wrap the children in a Model and PivotTo once. moving every part on its own double-moves anything welded (ropes, bags)
- sign renamed to 黒山ボクシングジム (kuroyama boxing gym), original name, no ippo names
- my old ring's parts are in ServerStorage.OldRingBackup. workspace.Ring only holds FighterSpawns now. BagSpot, R6AnimRig and SpawnLocation got lifted onto the gym floor
- the ring has g2's match values (RoundTime, KoLimit, RedBoxerName...) and JoinPads, unused for now, maybe useful for matches later. g2 also has an ArenaRing for real fights
- lighting: daytime, clocktime 15.2, brightness 2.6, warm ambient, atmosphere haze, GymGrade color correction, GymBloom, GymSunRays. Lighting.Technology can't be set from scripts, set it to Future by hand
- outside is still the plain baseplate, street / neighbourhood is a later job
