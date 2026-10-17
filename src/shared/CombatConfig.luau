--!strict
-- All the combat numbers in one place. Times are in seconds.

export type Move = {
	Startup: number, -- wind up before the punch can land
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
		Startup = 0.12, Recovery = 0.16, Damage = 4, Stamina = 4, GuardDamage = 6,
		Range = 6, Target = "Head", Hitstun = 0.25, ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
	},
	Cross = {
		Startup = 0.2, Recovery = 0.28, Damage = 8, Stamina = 8, GuardDamage = 12,
		Range = 6.5, Target = "Head", Hitstun = 0.35, ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
	},
	Hook = {
		Startup = 0.26, Recovery = 0.32, Damage = 10, Stamina = 10, GuardDamage = 10,
		Range = 5, Target = "Head", Hitstun = 0.4, ThroughGuard = 0.4,
		DodgedBy = { Duck = true, Back = true },
	},
	Uppercut = {
		Startup = 0.3, Recovery = 0.38, Damage = 12, Stamina = 12, GuardDamage = 8,
		Range = 4.5, Target = "Head", Hitstun = 0.45, ThroughGuard = 0,
		DodgedBy = { Left = true, Right = true, Back = true },
		BeatsSlip = { Duck = true },
	},
	Body = {
		Startup = 0.22, Recovery = 0.3, Damage = 6, Stamina = 9, GuardDamage = 4,
		Range = 5, Target = "Body", Hitstun = 0.3, ThroughGuard = 0.6,
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

CombatConfig.GuardBreakStun = 1.2

CombatConfig.SlipTime = 0.35 -- i-frames against punches the slip dodges
CombatConfig.SlipCost = 10
CombatConfig.SlipCooldown = 0.6
CombatConfig.CounterWindow = 0.7 -- after a clean slip, your next punch is a counter
CombatConfig.CounterBonus = 1.6
CombatConfig.SlipPunishBonus = 1.5 -- uppercut into a duck
CombatConfig.InputBuffer = 0.3 -- a punch pressed this early still comes out

-- guard height: high blocks head shots, low blocks body shots
CombatConfig.GuardSwitchTime = 0.12 -- not blocking while the hands move between heights
CombatConfig.LowGuardHeadBonus = 1.1 -- head shots on a low guard hit a bit harder
CombatConfig.LowGuardPitch = -25 -- degrees, looking further down than this is a low guard

-- weave mode (hold space)
CombatConfig.WeaveWalkSpeed = 6
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

CombatConfig.WalkSpeed = 13
CombatConfig.GuardWalkSpeed = 8

-- remote rate limit
CombatConfig.ActionsPerSecond = 14
CombatConfig.ActionBurst = 8

return CombatConfig
