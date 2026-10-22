--!strict
-- every combat number in one place, times in seconds

export type Move = {
	Startup: number, -- wind up before the punch can land
	MoveSpeed: number, -- walk speed while throwing it, so you plant your feet
	Step: number, -- studs per second of push forward when it fires
	Recovery: number, -- after it lands or whiffs, before you can act
	Damage: number,
	Stamina: number, -- cost to throw
	GuardDamage: number, -- how much it chews through a guard
	Range: number,
	Target: "Head" | "Body",
	Hitstun: number,
	ThroughGuard: number, -- share of damage that still lands on a guard (hooks wrap around)
	DodgedBy: { [string]: boolean }, -- slip directions that make it whiff
	BeatsSlip: { [string]: boolean }?, -- slips it punishes instead
	BodyDrain: number?, -- stamina it takes from the target
	Anim: string?, -- anim role when it isn't named after the move
	Special: boolean?, -- only thrown through a special slot, never the punch keys
	Like: string?, -- base punch it hits like, for sounds, fx and reactions
}

local CombatConfig = {}

CombatConfig.Moves = {
	Jab = {
		Startup = 0.12,
		MoveSpeed = 6,
		Step = 4,
		Recovery = 0.16,
		Damage = 4,
		Stamina = 6,
		GuardDamage = 6,
		Range = 6,
		Target = "Head",
		Hitstun = 0.16, -- under the 0.28s it takes to throw the next one, so jabs alone can't stunlock
		ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
	},
	Cross = {
		Startup = 0.2,
		MoveSpeed = 2,
		Step = 9,
		Recovery = 0.28,
		Damage = 8,
		Stamina = 8,
		GuardDamage = 12,
		Range = 6.5,
		Target = "Head",
		Hitstun = 0.35,
		ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
	},
	Hook = {
		Startup = 0.26,
		MoveSpeed = 2,
		Step = 6,
		Recovery = 0.32,
		Damage = 10,
		Stamina = 10,
		GuardDamage = 10,
		Range = 5,
		Target = "Head",
		Hitstun = 0.4,
		ThroughGuard = 0.4,
		DodgedBy = { Duck = true, Back = true },
	},
	Uppercut = {
		Startup = 0.3,
		MoveSpeed = 1,
		Step = 7,
		Recovery = 0.38,
		Damage = 12,
		Stamina = 12,
		GuardDamage = 8,
		Range = 4.5,
		Target = "Head",
		Hitstun = 0.45,
		ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
		BeatsSlip = { Duck = true },
	},
	Body = {
		Startup = 0.22,
		MoveSpeed = 1,
		Step = 8,
		Recovery = 0.3,
		Damage = 6,
		Stamina = 9,
		GuardDamage = 4,
		Range = 5,
		Target = "Body",
		Hitstun = 0.3,
		ThroughGuard = 0.6,
		DodgedBy = { Back = true },
		BodyDrain = 14,
	},
	-- special hits, thrown by the specials below
	StepCounter = {
		Startup = 0.18,
		MoveSpeed = 2,
		Step = 22,
		Recovery = 0.4,
		Damage = 14,
		Stamina = 0,
		GuardDamage = 14,
		Range = 9,
		Target = "Head",
		Hitstun = 0.5,
		ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
		Like = "Cross",
		Special = true,
	},
	QuickJab = {
		Startup = 0.1,
		MoveSpeed = 6,
		Step = 4,
		Recovery = 0.1,
		Damage = 4,
		Stamina = 0,
		GuardDamage = 6,
		Range = 6,
		Target = "Head",
		Hitstun = 0.22,
		ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
		Anim = "Jab",
		Like = "Jab",
		Special = true,
	},
	-- the new styles' special moves (anims built in tools/compose.py)
	PivotHook = {
		Startup = 0.24,
		MoveSpeed = 4,
		Step = 6,
		Recovery = 0.3,
		Damage = 12,
		Stamina = 0,
		GuardDamage = 12,
		Range = 6,
		Target = "Head",
		Hitstun = 0.45,
		ThroughGuard = 0.4,
		DodgedBy = { Duck = true, Back = true },
		Like = "Hook",
		Special = true,
	},
	Haymaker = {
		Startup = 0.42,
		MoveSpeed = 0,
		Step = 10,
		Recovery = 0.6,
		Damage = 26,
		Stamina = 0,
		GuardDamage = 22,
		Range = 6.5,
		Target = "Head",
		Hitstun = 0.7,
		ThroughGuard = 0.3,
		-- big and slow, easy to read and slip
		DodgedBy = { Left = true, Right = true, Back = true, Duck = true },
		Like = "Cross",
		Special = true,
	},
	QuickHook = {
		Startup = 0.17,
		MoveSpeed = 3,
		Step = 4,
		Recovery = 0.14,
		Damage = 8,
		Stamina = 0,
		GuardDamage = 9,
		Range = 5,
		Target = "Head",
		Hitstun = 0.32,
		ThroughGuard = 0.4,
		DodgedBy = { Duck = true, Back = true },
		Anim = "Hook",
		Like = "Hook",
		Special = true,
	},
	RollCounter = {
		Startup = 0.2,
		MoveSpeed = 2,
		Step = 10,
		Recovery = 0.35,
		Damage = 15,
		Stamina = 0,
		GuardDamage = 12,
		Range = 7,
		Target = "Head",
		Hitstun = 0.5,
		ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
		Like = "Cross",
		Special = true,
	},
	CheckHook = {
		Startup = 0.2,
		MoveSpeed = 4,
		Step = 2,
		Recovery = 0.3,
		Damage = 13,
		Stamina = 0,
		GuardDamage = 11,
		Range = 5.5,
		Target = "Head",
		Hitstun = 0.45,
		ThroughGuard = 0.4,
		DodgedBy = { Duck = true, Back = true },
		Like = "Hook",
		Special = true,
	},
	RollLeft = {
		Startup = 0.3,
		MoveSpeed = 8,
		Step = 6,
		Recovery = 0.05,
		Damage = 7,
		Stamina = 0,
		GuardDamage = 9,
		Range = 5.5,
		Target = "Head",
		Hitstun = 0.35,
		ThroughGuard = 0.4,
		DodgedBy = { Duck = true, Back = true },
		Like = "Hook",
		Special = true,
	},
	RollRight = {
		Startup = 0.3,
		MoveSpeed = 8,
		Step = 6,
		Recovery = 0.05,
		Damage = 7,
		Stamina = 0,
		GuardDamage = 9,
		Range = 5.5,
		Target = "Head",
		Hitstun = 0.35,
		ThroughGuard = 0.4,
		DodgedBy = { Duck = true, Back = true },
		Like = "Hook",
		Special = true,
	},
	LungeUppercut = {
		Startup = 0.38,
		MoveSpeed = 0,
		Step = 20,
		Recovery = 0.8,
		Damage = 22,
		Stamina = 0,
		GuardDamage = 12,
		Range = 7,
		Target = "Head",
		Hitstun = 0.6,
		ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
		BeatsSlip = { Duck = true },
		Like = "Uppercut",
		Special = true,
	},
} :: { [string]: Move }

-- stances: each swaps idle, walk and guard anims (and some punches), plus a few numbers.
-- Anims maps a base role to this stance's version, anything missing uses the base one
export type Stance = {
	Name: string, -- shown on the hud
	Anims: { [string]: string },
	WalkBonus: number,
	GuardTaken: number, -- guard damage taken multiplier
	SlipDiscount: number, -- stamina off every slip
	StartupMult: { [string]: number },
	DamageMult: { [string]: number }?, -- damage dealt by move
	Specials: { string }, -- Z and X
}
CombatConfig.Stances = {
	Orthodox = {
		Name = "ORTHODOX",
		Anims = {},
		WalkBonus = 0,
		GuardTaken = 1,
		SlipDiscount = 0,
		StartupMult = {},
		Specials = { "StepCounter", "DoubleJab" },
	},
	PeekABoo = {
		Name = "PEEK-A-BOO",
		Anims = {
			Idle = "PaBIdle",
			Guard = "PaBGuard",
			WalkForward = "PaBWalkForward",
			WalkBack = "PaBWalkBack",
			WalkLeft = "PaBWalkLeft",
			WalkRight = "PaBWalkRight",
			Jab = "PaBJab",
			Cross = "PaBCross",
			Hook = "PaBHook",
			Uppercut = "PaBUppercut",
			Body = "PaBBody",
			HitHeadLeft = "PaBHitHeadLeft",
			HitHeadRight = "PaBHitHeadRight",
			HitHeadTop = "PaBHitHeadTop",
			HitBody = "PaBHitBody",
			BlockLeft = "PaBBlockLeft",
			BlockRight = "PaBBlockRight",
			Stunned = "PaBStunned",
		},
		WalkBonus = -1,
		GuardTaken = 0.8,
		SlipDiscount = 2,
		StartupMult = { Hook = 0.85 },
		Specials = { "WeaveRoll", "LungeUppercut" },
	},
	OutBoxer = {
		Name = "OUT-BOXER",
		Anims = {
			Idle = "OutIdle",
			Guard = "OutGuard",
			WalkForward = "OutWalkForward",
			WalkBack = "OutWalkBack",
			WalkLeft = "OutWalkLeft",
			WalkRight = "OutWalkRight",
		},
		WalkBonus = 2,
		GuardTaken = 1.1,
		SlipDiscount = 3,
		StartupMult = { Jab = 0.85, Cross = 0.9 },
		DamageMult = { Jab = 1.15 },
		Specials = { "FlickerJab", "PivotHook" },
	},
	Slugger = {
		Name = "SLUGGER",
		Anims = {
			Idle = "SlugIdle",
			Guard = "SlugGuard",
			WalkForward = "SlugWalkForward",
			WalkBack = "SlugWalkBack",
			WalkLeft = "SlugWalkLeft",
			WalkRight = "SlugWalkRight",
		},
		WalkBonus = -2,
		GuardTaken = 0.85,
		SlipDiscount = 0,
		StartupMult = { Hook = 1.1, Cross = 1.05 },
		DamageMult = { Hook = 1.25, Cross = 1.2, Uppercut = 1.2 },
		Specials = { "Haymaker", "HookBarrage" },
	},
	PhillyShell = {
		Name = "PHILLY SHELL",
		Anims = {
			Idle = "PhillyIdle",
			Guard = "PhillyGuard",
			WalkForward = "PhillyWalkForward",
			WalkBack = "PhillyWalkBack",
			WalkLeft = "PhillyWalkLeft",
			WalkRight = "PhillyWalkRight",
		},
		WalkBonus = 0,
		GuardTaken = 0.9,
		SlipDiscount = 1,
		StartupMult = { Cross = 0.9 },
		DamageMult = { Cross = 1.1 },
		Specials = { "RollCounter", "CheckHook" },
	},
} :: { [string]: Stance }
CombatConfig.Loadout = { "Orthodox", "PeekABoo", "OutBoxer", "Slugger", "PhillyShell" } -- G cycles through the unlocked ones
CombatConfig.StanceSwitchTime = 0.4 -- can't punch or guard while switching
CombatConfig.StanceSwitchCooldown = 4

-- specials: a chain of special moves thrown back to back for one stamina cost
export type Special = {
	Name: string,
	Chain: { string },
	Stamina: number,
	Cooldown: number,
	OnlyInCounter: boolean?, -- needs an open counter window (after a clean slip or parry)
}
CombatConfig.Specials = {
	StepCounter = { Name = "STEP COUNTER", Chain = { "StepCounter" }, Stamina = 12, Cooldown = 6, OnlyInCounter = true },
	DoubleJab = { Name = "DOUBLE JAB", Chain = { "QuickJab", "QuickJab" }, Stamina = 8, Cooldown = 4 },
	WeaveRoll = {
		Name = "WEAVE ROLL",
		Chain = { "RollRight", "RollLeft", "RollRight" },
		Stamina = 30,
		Cooldown = 10,
	},
	LungeUppercut = { Name = "LUNGE UPPERCUT", Chain = { "LungeUppercut" }, Stamina = 18, Cooldown = 8 },
	FlickerJab = { Name = "FLICKER JAB", Chain = { "QuickJab", "QuickJab", "QuickJab" }, Stamina = 10, Cooldown = 5 },
	PivotHook = { Name = "PIVOT HOOK", Chain = { "PivotHook" }, Stamina = 14, Cooldown = 7 },
	Haymaker = { Name = "HAYMAKER", Chain = { "Haymaker" }, Stamina = 20, Cooldown = 10 },
	HookBarrage = { Name = "HOOK BARRAGE", Chain = { "QuickHook", "QuickHook", "QuickHook" }, Stamina = 18, Cooldown = 8 },
	RollCounter = { Name = "ROLL COUNTER", Chain = { "RollCounter" }, Stamina = 12, Cooldown = 6, OnlyInCounter = true },
	CheckHook = { Name = "CHECK HOOK", Chain = { "CheckHook" }, Stamina = 12, Cooldown = 6 },
} :: { [string]: Special }

-- the base punch a move counts as on the client (specials borrow the base ones' feel)
function CombatConfig.feelOf(moveName: string): string
	local move = CombatConfig.Moves[moveName]
	return (move and move.Like) or moveName
end

CombatConfig.MaxHealth = 100
CombatConfig.MaxStamina = 100
CombatConfig.MaxGuard = 100

CombatConfig.StaminaRegen = 12 -- per second, halved while guarding
CombatConfig.GuardRegen = 14 -- per second, after GuardRegenDelay without being hit
CombatConfig.GuardRegenDelay = 1.2
CombatConfig.GassedBelow = 20 -- under this, punches wind up slower
CombatConfig.GassedSlowdown = 1.4
CombatConfig.HurtBelow = 0.35 -- share of max health, under this a fighter looks hurt

CombatConfig.GuardBreakStun = 1.2

CombatConfig.SlipTime = 0.35 -- i-frames against punches the slip dodges
CombatConfig.SlipCost = 10
CombatConfig.SlipCooldown = 0.6
CombatConfig.SlipBackSpeed = 26 -- studs per second a player's back slip slides them for 0.15s (about 4 studs)
CombatConfig.CounterWindow = 0.7 -- after a clean slip, your next punch is a counter
CombatConfig.CounterBonus = 1.6
CombatConfig.SlipPunishBonus = 1.5 -- uppercut into a duck
CombatConfig.InputBuffer = 0.3 -- a punch pressed this early still comes out
-- the same punch thrown again within RepeatWindow loses RepeatFalloff of its damage and hitstun
-- each time, down to RepeatFloor. mixing punches resets it
CombatConfig.RepeatWindow = 1.2
CombatConfig.RepeatFalloff = 0.15
CombatConfig.RepeatFloor = 0.4

-- lasting damage: clean head shots also eat into max health for the rest of the fight
CombatConfig.LastingDamageShare = 0.2
CombatConfig.MinMaxHealth = 50
CombatConfig.HealthRegen = 2 -- per second, up to your current max
CombatConfig.HealthRegenDelay = 3 -- seconds without getting hit

-- courage builds as you fight and can trigger a second wind when you're knocked down
CombatConfig.MaxCourage = 100
CombatConfig.CourageGain = {
	CleanLanded = 3,
	CounterLanded = 8,
	Slipped = 4,
	Parried = 6,
	KnockedDown = 15,
	GotUp = 10,
	CleanTaken = -2,
} :: { [string]: number }
-- chance of a second wind by courage, checked top down. 100 always gets it
CombatConfig.SecondWindChance = {
	{ At = 100, Chance = 1 },
	{ At = 90, Chance = 0.7 },
	{ At = 60, Chance = 0.35 },
	{ At = 30, Chance = 0.15 },
	{ At = 0, Chance = 0.05 },
}
CombatConfig.SecondWindDelay = 1.2 -- the beat on the canvas before you get up
CombatConfig.SecondWindMaxHealth = 20 -- added to max health, can go past 100
CombatConfig.SecondWindHealth = 0.7 -- share of the new max you get up with
CombatConfig.FiredUpTime = 8
CombatConfig.FiredUpStamina = 2 -- stamina regen multiplier
CombatConfig.FiredUpSpeed = 0.9 -- wind up multiplier
CombatConfig.FiredUpGuard = 0.75 -- guard damage multiplier
CombatConfig.SecondWindLines = {
	"not yet... my legs still work",
	"i didn't come this far to stay down",
	"one more round. just one more",
	"everyone's watching. get up",
	"it hurts. good. that means i'm still here",
	"i haven't shown them anything yet",
}

-- read counters: your punch lands while theirs is still winding up. [yours][theirs]
export type Counter = { Name: string, Damage: number, Hitstun: number }
CombatConfig.Counters = {
	Cross = {
		Jab = { Name = "CROSS COUNTER", Damage = 2, Hitstun = 1.6 },
		Cross = { Name = "CROSS COUNTER", Damage = 2, Hitstun = 1.6 },
	},
	Hook = { Cross = { Name = "HOOK COUNTER", Damage = 1.7, Hitstun = 1.4 } },
	Uppercut = { Hook = { Name = "INSIDE", Damage = 1.8, Hitstun = 1.4 } },
	Body = { Uppercut = { Name = "BODY COUNTER", Damage = 1.5, Hitstun = 1.3 } },
} :: { [string]: { [string]: Counter } }
CombatConfig.StopCounter = { Name = "STOP", Damage = 1.2, Hitstun = 1 } :: Counter -- anything else in their wind up
CombatConfig.CrossCounterKnockdownBelow = 35 -- health, a cross counter on someone this low drops them
CombatConfig.PunishBonus = 1.3 -- hitting someone recovering from a whiff

-- parry: tap guard just before a straight lands
CombatConfig.ParryWindow = 0.15
CombatConfig.ParryRearm = 0.6 -- must have been unguarded this long, so holding and tapping doesn't work
CombatConfig.ParryCost = 4
CombatConfig.ParryStun = 0.65 -- the attacker's arm gets knocked aside
CombatConfig.ParryCounterWindow = 0.5
CombatConfig.ParryCounterBonus = 1.4
CombatConfig.ParryMoves = { Jab = true, Cross = true } :: { [string]: boolean }

-- guard height: high blocks head shots, low blocks body shots
CombatConfig.GuardSwitchTime = 0.12 -- not blocking while the hands move between heights
CombatConfig.LowGuardHeadBonus = 1.1 -- head shots on a low guard hit a bit harder
CombatConfig.LowGuardPitch = -25 -- degrees, looking further down than this is a low guard

-- weave mode (hold space)
CombatConfig.WeaveWalkSpeed = 5
CombatConfig.WeaveSlipCooldown = 0.45
CombatConfig.SlipChainCost = 3 -- extra stamina per slip chained inside the window
CombatConfig.SlipChainWindow = 1.5
CombatConfig.BobSlipTime = 0.12 -- i-frames on a slip with the guard up
CombatConfig.BobSlipCost = 6

CombatConfig.HitCone = 0.45 -- dot product, about 63 degrees either side

-- knockdowns
CombatConfig.DownCount = 10 -- referee count, one number per second
CombatConfig.GetUpPresses = { 8, 14, 20 } -- mashes needed, harder each knockdown
CombatConfig.HealthAfterDown = { 60, 40, 25 }
CombatConfig.MaxKnockdowns = 3 -- third one is a TKO

CombatConfig.WalkSpeed = 10
CombatConfig.StreetWalkSpeed = 16 -- out of fight mode, normal roblox walking
CombatConfig.StreetJumpHeight = 7.2
CombatConfig.StreetJumpPower = 50
CombatConfig.GuardWalkSpeed = 6

-- remote rate limit
CombatConfig.ActionsPerSecond = 14
CombatConfig.ActionBurst = 8

-- ring matches, joined from the pads in the corners
CombatConfig.Match = {
	Rounds = 3,
	RoundTime = 90,
	BreakTime = 10,
	-- between rounds you pick one, guard comes back either way
	Corner = {
		Hydrate = {}, -- stamina all the way back
		Treatment = { MaxHealth = 15, Heal = 0.3 }, -- lasting damage back off max health, then a share of what's missing
		PepTalk = { Courage = 35 },
	} :: { [string]: { MaxHealth: number?, Heal: number?, Courage: number? } },
	Intro = 4.5, -- the VS screen with both boxers before round 1
	Countdown = 3, -- frozen in the corners before each round
	KnockdownPoints = 15, -- on top of damage dealt, for the decision
	EndTime = 7, -- result screen up, then both go back outside the ropes
	PadLeaveDistance = 10, -- walk this far off your pad and you give it up
	AIWait = 15, -- alone on a pad this long and an AI boxer takes the other corner
}

return CombatConfig
