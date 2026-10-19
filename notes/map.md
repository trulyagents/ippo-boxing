# map

gym based on the kamogawa gym look (yellow walls, green mat floor, blue ring, red/white/blue ropes, fluorescent tubes, window wall, lockers, bags on blue frames)

- the building is g2's gym (Workspace/Map/EnterableBuildings/KamogawaGym in sold to trulyagents (2)), the ring is its KamogawaRing from Debris/Rings
- pulled with `tools/pull_model.py`, uploaded as private models with `tools/publish_model.py` (gym 119143050678016, ring 135315736867935), loaded in studio with InsertService:LoadAsset. unions and meshes come through fine that way
- lives in workspace.Map (Gym, GymRing). place only, not in git (build/ is ignored)
- ring centre at 0,0. ring base sits on the gym floor (3.3), canvas top 6.3. it came in sunk 2 studs into the floor, raised it and the FighterSpawns with it
- the ground (Baseplate top) is 2.3, where the front facade ends. the ring room is the street-level floor. the building has a basement down to -18.7 that sat in a slope in g2's map, it's hidden under the baseplate now. floors above at 12.3, 21.3, 30.3, 39.3
- levelled the props: tables, mat and the ring's bell table were floating 0.5-0.9 over the floor, the outdoor shed 1.2 over the ground. all dropped to sit on it. lockers, glove cubby, boxes, moped were already fine. jump ropes hang off a wall bar, bag frames are planted 0.9 into the floor on purpose
- the stairwell down to the basement opened onto the baseplate. covered it with Gym.BasementCover (a clone of the floor part) at 3.3, the up flights start from it
- moving it: wrap the children in a Model and PivotTo once. moving every part on its own double-moves anything welded (ropes, bags)
- sign renamed to 黒山ボクシングジム (kuroyama boxing gym), original name, no ippo names
- my old ring's parts are in ServerStorage.OldRingBackup. workspace.Ring only holds FighterSpawns now. BagSpot, R6AnimRig and SpawnLocation got lifted onto the gym floor
- the ring has g2's match values (RoundTime, KoLimit, RedBoxerName...) and JoinPads, unused for now, maybe useful for matches later. g2 also has an ArenaRing for real fights
- lighting: daytime, clocktime 15.2, brightness 2.6, warm ambient, atmosphere haze, GymGrade color correction, GymSunRays. both blooms (Bloom, GymBloom) are off, they made skin and ropes glow. Lighting.Technology can't be set from scripts, set it to Future by hand
- outside is g2's city, in workspace.Map.Street: City (roads, sidewalks, poles), Lights, StaticBuildings(+Base), PropBuildings (the far skyscrapers), Grass, Water, Store. same uploads trick (tools/pull_model.py then publish_model.py)
- g2's city lines up with the gym by moving it (194.25, 2.3, -65.94), no rotation. worked that out by matching parts in the gym against g2's original gym
- roads sit at 3.3 (same as the gym floor), sidewalks 3.55. the baseplate (top 2.3) is just under it and shows through the empty lots
- moving water lost its scripts on the pull so it's still water. skipped g2's korakuen hall (real name) and the doors folder
- g1 spots: only the basketball court came through (Street.Spots.Basketball), its Area and Bubble zones removed, no scripts so it's just scenery. g1's ramen shop and skate park are packages, the place file only has empty models for them. the ramen kitchen props on their own looked bad so i took them out
- filled the empty lots with copies of g2's 4 house types (Street.FillBuildings), back to back rows facing the roads. found the empty lots by checking each sidewalk Foundation slab for parts on top
- the hall's lot was sunk 8 studs, raised it with a LotFill slab at 3.55 and made it a park (Street.Park): g2 grass, bushes, a path and streetlights down the middle
- two small lots top left are still bare
- walking out of the gym works, 60 fps in studio with the whole city. pathfinding can't get out of the ring because of the ropes, players can
- upstairs (sparring floor) furnished, all in Workspace.Map.Gym.Upstairs (lives in the place, ctrl+s): blue sparring mat with a red border and 4 padded corner posts under the sparring partner, mirror wall on the west side, 3 benches and a copy of the gym lockers on the north wall, glove cubby / water cooler / dumbbell rack on the south wall, 4 posters (SurfaceGui, Bangers), 9 of the gym's ceiling lights. no prompts or scripts in any of it. middle stays open for sparring
- the upstairs mirror works (client/Mirror). roblox can't reflect, so each client builds it for real: a mirrored copy of the room's 222 parts behind the glass, a mirror sized hole in the wall behind it (the two Wall2 pieces are hidden locally and rebuilt around the hole), and a jointless twin of every fighter in the room posed every frame. real 3d, so it's right from any angle
- only on while your camera is upstairs. then the outside parts that sit where the copy goes (street, stairwell) are hidden locally, back when you leave
- what gets hidden: parts entirely behind the glass (the floor and ceiling cross it, so they stay)
- the mirror first went across the doorway to the stairs (west wall, z -12 to -5): it blocked the way up and the reflection showed the stairwell. moved to the solid wall at z 7 to 33. a mirror needs solid wall behind it
- Reflectance on a part only mirrors the sky, not the room or people, that's why this is built for real
- shortcut: twins are blocky copies (a turned copy reads as a reflection for R6 boxes, the gloves' thumbs are the only thing on the wrong side), rebuilt when someone leaves the room
