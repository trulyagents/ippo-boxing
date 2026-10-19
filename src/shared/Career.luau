--!strict
-- Ranks and the quest line. Shared so the menu can show them.
local Career = {}

-- rank points from ring matches
Career.Points = { Win = 25, KO = 10, Loss = -15, Draw = 5 }
Career.Ranks = {
	{ Name = "ROOKIE", At = 0 },
	{ Name = "PROSPECT", At = 100 },
	{ Name = "CONTENDER", At = 250 },
	{ Name = "RANKED", At = 500 },
	{ Name = "TITLE CHALLENGER", At = 900 },
	{ Name = "CHAMPION", At = 1400 },
}

-- the rank for some points, and the points the next one starts at (nil at the top)
function Career.rankOf(points: number): (string, number?)
	local name, nextAt = Career.Ranks[1].Name, nil
	for i, rank in Career.Ranks do
		if points >= rank.At then
			name = rank.Name
			nextAt = if Career.Ranks[i + 1] then Career.Ranks[i + 1].At else nil
		end
	end
	return name, nextAt
end

-- one quest at a time, in order. Event is what counts toward it, For narrows it down
export type Quest = { Text: string, Event: string, For: string?, Need: number, Reward: { Stat: string, Amount: number } }
Career.Quests = {
	{
		Text = "Head upstairs and land 10 clean hits",
		Event = "Hit",
		Need = 10,
		Reward = { Stat = "Endurance", Amount = 1 },
	},
	{
		Text = "Finish a drill on the heavy bag",
		Event = "Drill",
		For = "Power",
		Need = 1,
		Reward = { Stat = "Power", Amount = 1 },
	},
	{
		Text = "Finish a drill on the jump rope",
		Event = "Drill",
		For = "Stamina",
		Need = 1,
		Reward = { Stat = "Stamina", Amount = 1 },
	},
	{
		Text = "Finish a drill on the mitts",
		Event = "Drill",
		For = "Speed",
		Need = 1,
		Reward = { Stat = "Speed", Amount = 1 },
	},
	{ Text = "Get a perfect drill", Event = "PerfectDrill", Need = 1, Reward = { Stat = "Technique", Amount = 2 } },
	{
		Text = "Take a corner pad in the ring and finish a match",
		Event = "Match",
		Need = 1,
		Reward = { Stat = "Willpower", Amount = 2 },
	},
	{ Text = "Win a ring match", Event = "Win", Need = 1, Reward = { Stat = "Power", Amount = 2 } },
	{ Text = "Win a match by K.O.", Event = "KO", Need = 1, Reward = { Stat = "Speed", Amount = 2 } },
	{ Text = "Win 5 ring matches", Event = "Win", Need = 5, Reward = { Stat = "Willpower", Amount = 3 } },
} :: { Quest }

assert(Career.rankOf(0) == "ROOKIE" and select(2, Career.rankOf(0)) == 100, "rank start is off")
assert(
	Career.rankOf(260) == "CONTENDER" and Career.rankOf(5000) == "CHAMPION" and select(2, Career.rankOf(5000)) == nil,
	"rank tiers are off"
)

return Career
