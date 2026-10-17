--!strict
-- Published animation ids. Publish each KeyframeSequence in ReplicatedStorage.BoxingAnims
-- from the Animation Editor and paste its number here. Left empty, it only plays in Studio.
return {
	Idle = "",
	Guard = "",
	WalkForward = "",
	WalkBack = "",
	WalkLeft = "",
	WalkRight = "",

	Jab = "",
	Cross = "",
	Hook = "",
	Uppercut = "",
	Body = "",

	SlipLeft = "",
	SlipRight = "",
	SlipDuck = "",
	SlipBack = "",

	HitHeadLeft = "",
	HitHeadRight = "",
	HitHeadTop = "",
	HitBody = "",
	BlockLeft = "",
	BlockRight = "",
	Stunned = "",

	DownFall = "",
	DownLoop = "",
	KOFall = "",
	KOLoop = "",
} :: { [string]: string }
