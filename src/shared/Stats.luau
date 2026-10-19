--!strict
-- The 6 boxer stats, what raises them and what they unlock. Shared so a stats screen can read it.
local Stats = {}

Stats.Names = { "Power", "Stamina", "Technique", "Endurance", "Speed", "Willpower" }
Stats.Cap = 100

-- what a stat gives at the cap, it scales up in a straight line from 0
Stats.MaxBonus = {
	Power = 0.3, -- damage dealt
	Stamina = 0.3, -- off every stamina cost
	Technique = 0.3, -- guard damage dealt
	Endurance = 0.25, -- off damage taken
	Speed = 0.15, -- off punch startup
	Willpower = 0.5, -- courage gained
}

-- gym equipment by model name prefix, first match wins
Stats.Equipment = {
	{ "HeavySandbag", "Power" },
	{ "Sandbag", "Technique" },
	{ "JumpRope", "Stamina" },
	{ "MittModel", "Speed" },
}
Stats.TrainHold = 2.5 -- seconds holding the prompt per rep
Stats.TrainGain = 1
Stats.TrainCooldown = 3
-- endurance and willpower only grow by fighting
Stats.FightGain = { Endurance = 0.1, Willpower = 1 } -- per clean hit taken, per get up
-- land this many clean hits (on anyone, dummies count) and training counts for this long after
Stats.FightHits = 10
Stats.FightWindow = 1800

-- what each stance and special needs, anything not listed is open from the start
Stats.Unlocks = {
	PeekABoo = { Speed = 10, Endurance = 10 },
	StepCounter = { Technique = 15 },
	WeaveRoll = { Speed = 25, Stamina = 20 },
	LungeUppercut = { Power = 20 },
} :: { [string]: { [string]: number } }

function Stats.bonus(stats: { [string]: number }, name: string): number
	return math.min(stats[name] or 0, Stats.Cap) / Stats.Cap * Stats.MaxBonus[name]
end

-- every requirement not met yet, so a ui can show "Speed 4/10"
function Stats.missing(stats: { [string]: number }, unlock: string): { { Stat: string, Need: number, Have: number } }
	local out = {}
	for stat, need in Stats.Unlocks[unlock] or {} do
		local have = stats[stat] or 0
		if have < need then
			table.insert(out, { Stat = stat, Need = need, Have = have })
		end
	end
	return out
end

function Stats.unlocked(stats: { [string]: number }, unlock: string): boolean
	return #Stats.missing(stats, unlock) == 0
end

assert(
	Stats.bonus({ Power = 50 }, "Power") == 0.15 and Stats.bonus({ Power = 500 }, "Power") == 0.3,
	"stat bonus scaling is off"
)
assert(
	not Stats.unlocked({ Speed = 10 }, "PeekABoo") and Stats.unlocked({ Speed = 10, Endurance = 12 }, "PeekABoo"),
	"unlock check is off"
)

return Stats
