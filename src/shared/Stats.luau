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
} :: { [string]: number }

-- gym equipment by model name prefix, first match wins
Stats.Equipment = {
	{ "HeavySandbag", "Power" },
	{ "Sandbag", "Technique" },
	{ "JumpRope", "Stamina" },
	{ "MittModel", "Speed" },
}
-- every station has its own minigame, the server times and grades all of them
--   Charge: hold and let go in the sweet spot (heavy bag)
--   Combo: notes slide in with the punch to throw, right key on the beat (bag work)
--   Rhythm: press on the beat, it speeds up (jump rope)
--   Reaction: the mitt flashes at a random moment, hit it fast (mitts)
export type Drill = {
	Kind: string,
	Beats: number?, -- Combo and Rhythm
	Gaps: { number }?,
	Keys: { string }?, -- Combo, the punch each beat wants, cycled
	Reps: number?, -- Charge and Reaction
	Punches: { string }?, -- what you throw on a landed rep, cycled
}
-- jump rope starts at a skip every 0.6s and ends at 0.36s
local rope = {}
for i = 0, 14 do
	table.insert(rope, 0.6 - 0.24 * i / 14)
end
Stats.Drills = {
	Power = { Kind = "Charge", Reps = 5, Punches = { "Cross", "Hook" } },
	Technique = {
		Kind = "Combo",
		Beats = 10,
		Gaps = { 0.55, 0.55, 1 },
		Keys = { "Jab", "Jab", "Cross", "Jab", "Cross", "Hook" },
	},
	Stamina = { Kind = "Rhythm", Beats = 16, Gaps = rope },
	Speed = { Kind = "Reaction", Reps = 8, Punches = { "Jab", "Cross" } },
} :: { [string]: Drill }
-- the input for each combo key, shown on the note
Stats.ComboInputs = { Jab = "M1", Cross = "M2", Hook = "E" } :: { [string]: string }
Stats.ChargeTarget = 1 -- seconds held for a perfect charge
Stats.ChargePerfect = 0.08 -- either side of the target
Stats.ChargeGood = 0.2
Stats.ChargeMax = 2 -- the meter's full length, holding past it is a miss
Stats.ReactPerfect = 0.25 -- reaction time after the flash
Stats.ReactGood = 0.38
Stats.ReactWindow = 0.9 -- how long the mitt stays up
Stats.ReactDelay = { 0.8, 2.2 } -- random wait before each flash
Stats.DrillLeadIn = 1.5 -- seconds before the first beat
Stats.DrillPerfect = 0.07 -- seconds either side of a beat
Stats.DrillGood = 0.15
Stats.DrillGain = 2 -- for a perfect session, scales down with accuracy
Stats.DrillCooldown = 2
Stats.DrillStandOff = 3.2 -- how far from the bag or mitts you get stood for a drill
Stats.DrillPush = { Perfect = 7, Good = 4 } :: { [string]: number } -- studs per second a landed drill punch swings the bag
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
	OutBoxer = { Speed = 15, Stamina = 10 },
	FlickerJab = { Speed = 20 },
	PivotHook = { Technique = 20 },
	Slugger = { Power = 15, Endurance = 10 },
	Haymaker = { Power = 25 },
	HookBarrage = { Stamina = 20, Power = 15 },
	PhillyShell = { Technique = 20, Speed = 15 },
	RollCounter = { Technique = 25 },
	CheckHook = { Speed = 25 },
} :: { [string]: { [string]: number } }

-- seconds after the lead in for every beat of a Combo or Rhythm drill
function Stats.beatTimes(drill: Drill): { number }
	local gaps = drill.Gaps :: { number }
	local times, t = {}, 0
	for i = 1, drill.Beats :: number do
		table.insert(times, t)
		t += gaps[(i - 1) % #gaps + 1]
	end
	return times
end

function Stats.chargeGrade(held: number): string
	local off = math.abs(held - Stats.ChargeTarget)
	return if held > Stats.ChargeMax
		then "Miss"
		elseif off <= Stats.ChargePerfect then "Perfect"
		elseif off <= Stats.ChargeGood then "Good"
		else "Miss"
end

function Stats.reactGrade(seconds: number): string
	return if seconds <= Stats.ReactPerfect then "Perfect" elseif seconds <= Stats.ReactGood then "Good" else "Miss"
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
	Stats.grade(-0.05) == "Perfect" and Stats.grade(0.12) == "Good" and Stats.grade(0.2) == "Miss",
	"drill grading is off"
)
assert(
	#Stats.beatTimes(Stats.Drills.Technique) == 10 and math.abs(Stats.beatTimes(Stats.Drills.Technique)[4] - 2.1) < 1e-9,
	"beat times are off"
)
assert(
	Stats.chargeGrade(1.05) == "Perfect" and Stats.chargeGrade(0.85) == "Good" and Stats.chargeGrade(0.7) == "Miss",
	"charge grading is off"
)
assert(Stats.reactGrade(0.25) == "Perfect" and Stats.reactGrade(0.6) == "Miss", "reaction grading is off")
assert(
	Stats.bonus({ Power = 50 }, "Power") == 0.15 and Stats.bonus({ Power = 500 }, "Power") == 0.3,
	"stat bonus scaling is off"
)
assert(
	not Stats.unlocked({ Speed = 10 }, "PeekABoo") and Stats.unlocked({ Speed = 10, Endurance = 12 }, "PeekABoo"),
	"unlock check is off"
)

return Stats
