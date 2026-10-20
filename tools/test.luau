-- Checks the pure game logic outside Roblox. Every shared module runs its own asserts when it's
-- required, then the loops below check the numbers that would hurt most if they were wrong.
--   lune run tools/test
local Stats = require("../src/shared/Stats")
local Career = require("../src/shared/Career")
local Config = require("../src/shared/CombatConfig")
local Daily = require("../src/shared/Daily")

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

-- daily streak: a week of logins in a row climbs to the cap, a gap starts over
local streak, last = 0, 0
for day = 100, 110 do
	local n = Daily.next(last, streak, day)
	check(n == day - 99, "streak day " .. day .. " is " .. (day - 99))
	streak, last = n or streak, day
	check(Daily.next(last, streak, day) == nil, "logging in twice on day " .. day .. " gives nothing")
end
check(Daily.next(last, streak, last + 2) == 1, "two days off starts over")
check(Daily.reward(streak) == Daily.MaxDay * Daily.PerDay, "long streak reward is capped")

-- shop: every pass and product has a real id, red gloves are free for everyone, colors don't repeat
-- shop data uses Color3, which only exists inside roblox. lune's roblox library has it
local env: any = getfenv(0)
env.Color3 = require("@lune/roblox").Color3
local Shop = require("../src/shared/Shop")
for _, list in { Shop.Passes, Shop.Products } do
	for name, id in list do
		check(typeof(id) == "number" and id > 0 and id == math.floor(id), name .. " has a real id")
	end
end
check(Shop.glove("Red") ~= nil and Shop.Gloves[1].Name == "Red", "red gloves exist and come first")
local seenGlove = {}
for _, g in Shop.Gloves do
	check(not seenGlove[g.Name], "glove " .. g.Name .. " only listed once")
	seenGlove[g.Name] = true
end
check(Shop.glove("Rainbow") == nil, "an unknown glove color isn't a glove")
check(Shop.VIPDailyBonus > 0 and Shop.VIPDailyBonus < Daily.MaxDay * Daily.PerDay, "vip bonus helps but doesn't beat a long streak")

-- every anim the combat code can ask for has a published id
local AnimIds = require("../src/shared/AnimIds")
for name, move in Config.Moves :: { [string]: any } do
	local anim = move.Anim or name
	check(AnimIds[anim] ~= nil, "move " .. name .. " has an anim (" .. anim .. ")")
end
for stance, s in Config.Stances :: { [string]: any } do
	for base, anim in s.Anims do
		check(AnimIds[anim] ~= nil, stance .. " " .. base .. " has an anim (" .. anim .. ")")
	end
	for _, special in s.Specials do
		local sp = (Config :: any).Specials[special]
		check(sp ~= nil, stance .. " special " .. special .. " exists")
		for _, step in (sp and sp.Chain) or { special } do
			check(Config.Moves[step] ~= nil, special .. " step " .. step .. " is a move")
		end
	end
end
for _, role in { "Idle", "Guard", "LowGuard", "Weave", "CornerSit", "DownFall", "DownLoop", "KOFall", "KOLoop", "Stunned", "Gassed", "Hurt", "JumpRope" } do
	check(AnimIds[role] ~= nil, role .. " has an anim")
end

-- a basic punch thrown back to back must leave a gap after its stun, or it stunlocks
for name, move in Config.Moves :: { [string]: any } do
	if not move.Special then
		check(move.Hitstun < move.Startup + move.Recovery - 0.05, name .. " can't stunlock on its own")
	end
end
check(Config.RepeatFloor > 0 and Config.RepeatFloor < 1 and Config.RepeatFalloff > 0, "spam falloff is sane")

print(if failed == 0 then "all checks passed" else failed .. " checks failed")
if failed > 0 then
	error("tests failed", 0)
end
