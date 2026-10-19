--!strict
-- Published animation ids, one per KeyframeSequence in ReplicatedStorage.BoxingAnims.
-- An empty one gets registered on the fly, which only plays in Studio. Any id listed in
-- the OriginalIds attribute is someone else's and gets skipped the same way.
return {
	Idle = "rbxassetid://78797780707371",
	Guard = "rbxassetid://121959437597638",
	LowGuard = "rbxassetid://74985604077382",
	Weave = "rbxassetid://103729062707961",
	Gassed = "rbxassetid://127200357135694",
	Hurt = "rbxassetid://132529103977923",
	WalkForward = "rbxassetid://136642203909858",
	WalkBack = "rbxassetid://119239880734447",
	WalkLeft = "rbxassetid://131192021226753",
	WalkRight = "rbxassetid://105280436269746",

	Jab = "rbxassetid://140008204799543",
	Cross = "rbxassetid://114981067057611",
	Hook = "rbxassetid://105095025823676",
	Uppercut = "rbxassetid://97886341600237",
	Body = "rbxassetid://139433932241585",

	SlipLeft = "rbxassetid://123554709180570",
	SlipRight = "rbxassetid://110329219250331",
	SlipDuck = "rbxassetid://90800663225650",
	SlipBack = "rbxassetid://116691994517215",

	HitHeadLeft = "rbxassetid://95737528979029",
	HitHeadRight = "rbxassetid://117330054122626",
	HitHeadTop = "rbxassetid://108503536991941",
	HitBody = "rbxassetid://94807664517280",
	BlockLeft = "rbxassetid://102563830343816",
	BlockRight = "rbxassetid://123013324168698",
	Stunned = "rbxassetid://82784956855590",

	DownFall = "rbxassetid://125416969645312",
	DownLoop = "rbxassetid://119360513054677",
	KOFall = "rbxassetid://72405842376521",
	KOLoop = "rbxassetid://127872440092908",

	-- peek-a-boo stance
	PaBIdle = "rbxassetid://136227323046006",
	PaBGuard = "rbxassetid://73886140634591",
	PaBWalkForward = "rbxassetid://107769646923286",
	PaBWalkBack = "rbxassetid://102258030186308",
	PaBWalkLeft = "rbxassetid://118988293879002",
	PaBWalkRight = "rbxassetid://70428063252302",
	PaBJab = "rbxassetid://127754604446320",
	PaBCross = "rbxassetid://126410129366507",
	PaBHook = "rbxassetid://113725756323495",
	-- made in blender on the r6 rig (models/anims), not from the bought games
	PaBUppercut = "rbxassetid://80422103123831",
	PaBBody = "rbxassetid://73021932379975",
	PaBHitHeadLeft = "rbxassetid://95443444556297",
	PaBHitHeadRight = "rbxassetid://76947056083034",
	PaBHitHeadTop = "rbxassetid://124207011365437",
	PaBHitBody = "rbxassetid://99779381260180",
	PaBBlockLeft = "rbxassetid://81486267254632",
	PaBBlockRight = "rbxassetid://100071338403870",
	PaBStunned = "rbxassetid://125606427623625",

	-- specials, built from the good punches' impact poses plus my own torso moves (tools/compose.py)
	RollLeft = "rbxassetid://92837164821911",
	RollRight = "rbxassetid://111487002291729",
	LungeUppercut = "rbxassetid://110247453598111",
	StepCounter = "rbxassetid://78317788834785",

	-- training. g2's boxer skip with the feet lifted out of the floor (tools/jumprope.py)
	JumpRope = "rbxassetid://111205795682531",
} :: { [string]: string }
