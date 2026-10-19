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
-- a training session is a short rhythm drill. the server owns the beat times and grades every press
export type Drill = { Beats: number, Gaps: { number }, Punches: { string }? }
Stats.Drills = {
	Power = { Beats = 8, Gaps = { 0.9 }, Punches = { "Cross", "Hook" } }, -- heavy, steady shots
	Technique = { Beats = 10, Gaps = { 0.5, 0.5, 1 }, Punches = { "Jab", "Jab", "Cross" } }, -- combos with a beat between
	Stamina = { Beats = 16, Gaps = { 0.45 } }, -- jump rope, fast and even
	Speed = { Beats = 12, Gaps = { 0.3, 0.8 }, Punches = { "Jab", "Cross" } }, -- quick pairs on the mitts
} :: { [string]: Drill }
Stats.DrillLeadIn = 1.5 -- seconds before the first beat
Stats.DrillPerfect = 0.1 -- seconds either side of a beat
Stats.DrillGood = 0.22
Stats.DrillGain = 2 -- for a perfect session, scales down with accuracy
Stats.DrillCooldown = 2
Stats.DrillStandOff = 3.2 -- how far from the bag or mitts you get stood for a drill
Stats.DrillPush = { Perfect = 7, Good = 4 } -- studs per second a landed drill punch swings the bag
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

-- seconds after the lead in for every beat of a drill
function Stats.beatTimes(drill: Drill): { number }
	local times, t = {}, 0
	for i = 1, drill.Beats do
		table.insert(times, t)
		t += drill.Gaps[(i - 1) % #drill.Gaps + 1]
	end
	return times
end

-- how far off the beat a press was, in seconds either way
function Stats.grade(off: number): string
	off = math.abs(off)
	return if off <= Stats.DrillPerfect then "Perfect" elseif off <= Stats.DrillGood then "Good" else "Miss"
end

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
	Stats.grade(-0.05) == "Perfect" and Stats.grade(0.2) == "Good" and Stats.grade(0.3) == "Miss",
	"drill grading is off"
)
assert(
	#Stats.beatTimes(Stats.Drills.Speed) == 12 and Stats.beatTimes(Stats.Drills.Speed)[3] == 1.1,
	"beat times are off"
)
assert(
	Stats.bonus({ Power = 50 }, "Power") == 0.15 and Stats.bonus({ Power = 500 }, "Power") == 0.3,
	"stat bonus scaling is off"
)
assert(
	not Stats.unlocked({ Speed = 10 }, "PeekABoo") and Stats.unlocked({ Speed = 10, Endurance = 12 }, "PeekABoo"),
	"unlock check is off"
)

return Stats
