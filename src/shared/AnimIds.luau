--!strict
-- Published animation ids. Publish each KeyframeSequence in ReplicatedStorage.BoxingAnims
-- from the Animation Editor and paste its number here. Left empty, it only plays in Studio.
-- The filled ones are still the bought game's ids, left in for the spoofer to swap. Until
-- they're swapped the animator ignores them (OriginalIds attribute) and uses the Studio copy.
-- Their punch ids were server side and aren't in the files, so those need publishing.
return {
	Idle = "rbxassetid://12573039647",
	Guard = "",
	WalkForward = "rbxassetid://12595140782",
	WalkBack = "rbxassetid://12595144635",
	WalkLeft = "rbxassetid://12595155118",
	WalkRight = "rbxassetid://12595164337",

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
