--!strict
-- Published animation ids, one per KeyframeSequence in ReplicatedStorage.BoxingAnims.
-- An empty one gets registered on the fly, which only plays in Studio. Any id listed in
-- the OriginalIds attribute is someone else's and gets skipped the same way.
return {
	Idle = "rbxassetid://138260167411579",
	Guard = "rbxassetid://90596097636849",
	LowGuard = "rbxassetid://74985604077382",
	Weave = "rbxassetid://103729062707961",
	WalkForward = "rbxassetid://131348826657355",
	WalkBack = "rbxassetid://97792164577747",
	WalkLeft = "rbxassetid://81778306568182",
	WalkRight = "rbxassetid://132837474921349",

	Jab = "rbxassetid://126434169379193",
	Cross = "rbxassetid://95204103785804",
	Hook = "rbxassetid://77858313729368",
	Uppercut = "rbxassetid://102823493012435",
	Body = "rbxassetid://107103161920799",

	SlipLeft = "rbxassetid://108536448030193",
	SlipRight = "rbxassetid://121362249839937",
	SlipDuck = "rbxassetid://126639021632157",
	SlipBack = "rbxassetid://73491992942193",

	HitHeadLeft = "rbxassetid://129650507422320",
	HitHeadRight = "rbxassetid://83013444830368",
	HitHeadTop = "rbxassetid://104034134110725",
	HitBody = "rbxassetid://70746184553496",
	BlockLeft = "rbxassetid://97843350435928",
	BlockRight = "rbxassetid://88373425819489",
	Stunned = "rbxassetid://77847472771541",

	DownFall = "rbxassetid://87955555575889",
	DownLoop = "rbxassetid://122644516213347",
	KOFall = "rbxassetid://97345833232763",
	KOLoop = "rbxassetid://112639789123472",
} :: { [string]: string }
