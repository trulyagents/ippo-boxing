--!strict
-- Published animation ids. Publish each KeyframeSequence in ReplicatedStorage.BoxingAnims
-- from the Animation Editor and paste its number here. Left empty, it only plays in Studio.
-- The "theirs" comments are the bought game's ids. They only load in that game's place, so
-- they're just for reference. Their punch ids were server side and aren't in the files.
return {
	Idle = "", -- theirs: 12573039647
	Guard = "", -- theirs: not in files
	WalkForward = "", -- theirs: 12595140782
	WalkBack = "", -- theirs: 12595144635
	WalkLeft = "", -- theirs: 12595155118
	WalkRight = "", -- theirs: 12595164337

	Jab = "", -- theirs: not in files
	Cross = "", -- theirs: not in files
	Hook = "", -- theirs: not in files
	Uppercut = "", -- theirs: not in files
	Body = "", -- theirs: not in files

	SlipLeft = "", -- theirs: not in files
	SlipRight = "", -- theirs: not in files
	SlipDuck = "", -- theirs: not in files
	SlipBack = "", -- theirs: not in files

	HitHeadLeft = "", -- theirs: not in files
	HitHeadRight = "", -- theirs: not in files
	HitHeadTop = "", -- theirs: not in files
	HitBody = "", -- theirs: not in files
	BlockLeft = "", -- theirs: not in files
	BlockRight = "", -- theirs: not in files
	Stunned = "", -- theirs: not in files

	DownFall = "", -- theirs: not in files
	DownLoop = "", -- theirs: not in files
	KOFall = "", -- theirs: not in files
	KOLoop = "", -- theirs: not in files
} :: { [string]: string }
