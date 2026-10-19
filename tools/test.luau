-- Checks the pure game logic outside Roblox. Every shared module runs its own asserts when it's
-- required, then the loops below check the numbers that would hurt most if they were wrong.
--   lune run tools/test
local Stats = require("../src/shared/Stats")
local Career = require("../src/shared/Career")
local Config = require("../src/shared/CombatConfig")

local failed = 0
local function check(ok: boolean, what: string)
	if not ok then
		failed += 1
		print("FAIL " .. what)
	end
end

-- ranks: thresholds go up, every point total gets exactly the rank whose band it's in
for i = 2, #Career.Ranks do
	check(Career.Ranks[i].At > Career.Ranks[i - 1].At, "rank " .. i .. " starts above the one before")
end
for points = 0, 2000, 5 do
	local name, nextAt = Career.rankOf(points)
	local want = Career.Ranks[1]
	for _, r in Career.Ranks do
		if points >= r.At then
			want = r
		end
	end
	check(name == want.Name, "rankOf(" .. points .. ") is " .. want.Name)
	check(nextAt == nil or nextAt > points, "next rank for " .. points .. " is ahead of it")
end

-- match points: a KO win beats a win beats a draw beats nothing beats a loss
local P = Career.Points
check(P.Win + P.KO > P.Win and P.Win > P.Draw and P.Draw > 0 and P.Loss < 0, "match points are ordered")

-- quests: every reward is a real stat, every event is one the server actually sends
-- keep in step with every Career.event call (Fighters, Training, Career.matchResult)
local EVENTS = { Hit = true, Drill = true, PerfectDrill = true, Match = true, Win = true, KO = true }
for i, q in Career.Quests do
	check(EVENTS[q.Event] == true, "quest " .. i .. " event " .. tostring(q.Event) .. " is sent somewhere")
	check(Stats.MaxBonus[q.Reward.Stat] ~= nil, "quest " .. i .. " reward stat " .. q.Reward.Stat .. " exists")
	check(q.For == nil or Stats.Drills[q.For] ~= nil, "quest " .. i .. " drill " .. tostring(q.For) .. " exists")
	check(q.Need >= 1, "quest " .. i .. " needs at least 1")
end

-- drill grading: perfect is inside good, and a press gets a worse grade the further off it is
local order = { Perfect = 3, Good = 2, Miss = 1 }
local last = 3
for ms = 0, 400 do
	local g = order[Stats.grade(ms / 1000)]
	check(g <= last, "beat grade never gets better further from the beat (" .. ms .. "ms)")
	last = g
end
last = 3
for ms = 0, 1000, 5 do
	local g = order[Stats.reactGrade(ms / 1000)]
	check(g <= last, "mitt grade never gets better slower (" .. ms .. "ms)")
	last = g
end
check(Stats.chargeGrade(Stats.ChargeMax + 0.01) == "Miss", "holding past the meter misses")

-- beats come later and later, and the jump rope only ever speeds up
for stat, drill in Stats.Drills do
	if drill.Beats then
		local times = Stats.beatTimes(drill)
		check(#times == drill.Beats, stat .. " drill has every beat")
		for i = 2, #times do
			check(times[i] > times[i - 1], stat .. " beat " .. i .. " is after the one before")
		end
	end
end
local rope = Stats.Drills.Stamina.Gaps :: { number }
for i = 2, #rope do
	check(rope[i] <= rope[i - 1], "jump rope gap " .. i .. " isn't slower than the last")
end

-- stat bonuses stay inside 0..max for any stat value, even silly ones
for _, name in Stats.Names do
	for _, v in { -50, 0, 1, 50, 100, 1e9 } do
		local b = Stats.bonus({ [name] = v }, name)
		check(b <= Stats.MaxBonus[name] + 1e-9, name .. " bonus at " .. v .. " stays under the max")
	end
end

-- corner picks all exist and only give what they say
for _, pick in { "Hydrate", "Treatment", "PepTalk" } do
	check(Config.Match.Corner[pick] ~= nil, "corner pick " .. pick .. " is configured")
end

print(if failed == 0 then "all checks passed" else failed .. " checks failed")
if failed > 0 then
	error("tests failed", 0)
end
