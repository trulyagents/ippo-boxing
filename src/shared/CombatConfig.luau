--!strict
-- All the combat numbers in one place. Times are in seconds.

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
}

local CombatConfig = {}

CombatConfig.Moves = {
	Jab = {
		Startup = 0.12,
		MoveSpeed = 6,
		Step = 4,
		Recovery = 0.16,
		Damage = 4,
		Stamina = 4,
		GuardDamage = 6,
		Range = 6,
		Target = "Head",
		Hitstun = 0.25,
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
} :: { [string]: Move }

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
CombatConfig.CounterWindow = 0.7 -- after a clean slip, your next punch is a counter
CombatConfig.CounterBonus = 1.6
CombatConfig.SlipPunishBonus = 1.5 -- uppercut into a duck
CombatConfig.InputBuffer = 0.3 -- a punch pressed this early still comes out

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
}
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
CombatConfig.GuardWalkSpeed = 6

-- remote rate limit
CombatConfig.ActionsPerSecond = 14
CombatConfig.ActionBurst = 8

return CombatConfig
