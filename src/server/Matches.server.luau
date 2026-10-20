--!strict
-- Ring matches, in every ring tagged BoxingRing (the gym's and the basement ones, see
-- Shared.Rings). Two boxers take the pads in the red and blue corners, then it's a few rounds
-- scored on damage and knockdowns, a KO ends it early. Only the two of them can hit each other.
-- Alone on a pad for Config.AIWait and an AI boxer takes the other corner (AIBoxer), worth a
-- share of the rank points. Each ring carries MatchOn, MatchRound and MatchEndsAt for the clocks.
-- Spectators tell the server which ring they watch (Watch) so they get its shouts and screens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local Config = CombatConfig.Match
local CareerData = require(ReplicatedStorage.Shared.Career)
local Rings = require(ReplicatedStorage.Shared.Rings)
local Fighters = require(script.Parent.Fighters)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)
local Corner = require(script.Parent.Corner)
local AIBoxer = require(script.Parent.AIBoxer)
local Remotes = require(script.Parent.Remotes)

local fx = Remotes.Fx
local random = Random.new()

-- who is spectating which ring. nil = whatever ring you're standing by
local watching: { [Player]: Model } = {}
local watchBudget: { [Player]: { Tokens: number, Last: number } } = {}
Remotes.Watch.OnServerEvent:Connect(function(player, ring)
	local now = os.clock()
	local b = watchBudget[player] or { Tokens = 4, Last = now }
	watchBudget[player] = b
	b.Tokens = math.min(4, b.Tokens + (now - b.Last) * 2)
	b.Last = now
	if b.Tokens < 1 then
		return
	end
	b.Tokens -= 1
	if ring == nil then
		watching[player] = nil
	elseif typeof(ring) == "Instance" then
		local model = ring :: Instance
		if model:IsA("Model") and model:HasTag(Rings.Tag) then
			watching[player] = model
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	watching[player] = nil
	watchBudget[player] = nil
end)

-- everyone who should see what happens in this ring: the ones by it and the ones watching it
local function audience(ring: Model): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local watched = watching[player]
		if watched then
			if watched == ring then
				table.insert(out, player)
			end
		else
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and Rings.nearest(root.Position) == ring then
				table.insert(out, player)
			end
		end
	end
	return out
end

type Pad = {
	Name: string,
	Start: BasePart, -- inside the ring, where you stand for the bell
	Outside: BasePart, -- outside the ropes, where the prompt is and where you go after
	Prompt: ProximityPrompt,
	Occupied: BoolValue,
	OccupiedName: StringValue,
	Player: Player?,
	AI: Fighters.Fighter?,
	Since: number, -- when the player took it
}

local function fighterOf(player: Player): Fighters.Fighter?
	return Fighters.get(player.Character)
end

local function setup(ring: Model)
	local padRef = ring:WaitForChild("JoinPads")
	local padFolder = if padRef:IsA("ObjectValue") then padRef.Value :: Instance else padRef
	local pads: { Pad } = {}
	local running = false
	local summoning = false
	local recorded: { [Player]: boolean } = {} -- players whose result is already in this match

	local function setPad(pad: Pad, player: Player?, ai: Fighters.Fighter?)
		pad.Player, pad.AI = player, ai
		pad.Since = os.clock()
		pad.Occupied.Value = player ~= nil or ai ~= nil
		pad.OccupiedName.Value = if player then player.DisplayName elseif ai then ai.Model.Name else "Nil"
		pad.Prompt.ActionText = if player or ai then "Leave" else "Fight"
		pad.Prompt.ObjectText = string.upper(pad.Name) .. " CORNER"
	end

	local function padOf(player: Player): Pad?
		for _, pad in pads do
			if pad.Player == player then
				return pad
			end
		end
		return nil
	end

	local function boxerOf(pad: Pad): Fighters.Fighter?
		return pad.AI or (pad.Player and fighterOf(pad.Player))
	end

	local function center(): Vector3
		return (pads[1].Start.Position + pads[2].Start.Position) / 2
	end

	local function place(f: Fighters.Fighter, part: BasePart, faceTo: Vector3)
		local at = part.Position + Vector3.new(0, 0.5, 0)
		f.Model:PivotTo(CFrame.lookAt(at, Vector3.new(faceTo.X, at.Y, faceTo.Z)))
		if not f.Player then
			AIBoxer.faceNow(f)
		end
	end

	local function tell(text: string, sound: string?)
		for _, player in audience(ring) do
			fx:FireClient(player, "Match", text, sound)
		end
	end

	-- the VS cards fly off this long into the intro (MatchIntro), that's when FIGHT is called
	local INTRO = Config.Intro - 0.6

	local function runMatch(red: Pad, blue: Pad)
		local a, b = boxerOf(red), boxerOf(blue)
		if not (a and b) then
			return
		end
		running = true
		ring:SetAttribute("SkipPhase", nil) -- a QA skip left over from the last match
		ring:SetAttribute("MatchOn", true)
		local fighters = { a, b }
		local vsAI = a.Player == nil or b.Player == nil
		table.clear(recorded)
		local corners = { red, blue }
		local points: { [Fighters.Fighter]: number } = { [a] = 0, [b] = 0 }
		-- what each one did, this round and the whole fight, for the corner and result screens
		type Tally = { Hits: number, Damage: number, Downs: number }
		local function tally(): Tally
			return { Hits = 0, Damage = 0, Downs = 0 }
		end
		local roundTally: { [Fighters.Fighter]: Tally } = { [a] = tally(), [b] = tally() }
		local fightTally: { [Fighters.Fighter]: Tally } = { [a] = tally(), [b] = tally() }
		local function count(f: Fighters.Fighter, key: string, amount: number)
			local r, t = roundTally[f] :: any, fightTally[f] :: any
			r[key] += amount
			t[key] += amount
		end
		for _, f in fighters do
			Fighters.reset(f)
			f.Match = ring:GetFullName()
			f.Model:SetAttribute("InMatch", true)
		end
		local stopHits = Fighters.onHit(function(attacker, target, damage)
			if points[attacker] and points[target] then
				points[attacker] += damage
				count(attacker, "Hits", 1)
				count(attacker, "Damage", damage)
			end
		end)
		local stopDowns = Fighters.onDown(function(target, attacker)
			if points[attacker] and points[target] then
				points[attacker] += Config.KnockdownPoints
				count(attacker, "Downs", 1)
			end
		end)

		local winner: Fighters.Fighter? = nil
		local how = ""
		-- a forfeit before the first bell isn't a win, or an alt could leave on cue for free points
		local fought = false
		local function gone(f: Fighters.Fighter): boolean
			local player = f.Player
			if player and player.Parent ~= Players then
				return true
			end
			return Fighters.get(f.Model) ~= f or f.Model.Parent ~= workspace
		end
		local function over(): boolean
			for i, f in fighters do
				local other = fighters[3 - i]
				if gone(f) then
					winner, how = other, "FORFEIT"
					return true
				elseif f.State == "KO" then
					winner, how = other, "K.O."
					return true
				end
			end
			return false
		end
		local function hold(seconds: number): boolean
			local untilTime = os.clock() + seconds
			while os.clock() < untilTime do
				task.wait(0.1)
				if over() then
					return true
				end
				-- QA: Cheats sets this to jump to the end of the intro, round or break
				if ring:GetAttribute("SkipPhase") then
					ring:SetAttribute("SkipPhase", nil)
					break
				end
			end
			return false
		end

		-- the VS screen: both in their corners, names, ranks and records up, the bell
		local function card(f: Fighters.Fighter): { [string]: any }
			local player = f.Player
			if not player then
				return { Name = f.Model.Name, Rank = "AI BOXER", Wins = 0, Losses = 0, Draws = 0, KOs = 0 }
			end
			return {
				Name = player.DisplayName,
				UserId = player.UserId,
				Rank = player:GetAttribute("Rank") or "ROOKIE",
				Wins = player:GetAttribute("Wins") or 0,
				Losses = player:GetAttribute("Losses") or 0,
				Draws = player:GetAttribute("Draws") or 0,
				KOs = player:GetAttribute("KOs") or 0,
				VIP = player:GetAttribute("VIP") == true,
			}
		end
		for i, f in fighters do
			place(f, corners[i].Start, corners[3 - i].Start.Position)
			Fighters.freeze(f, INTRO)
		end
		for _, player in audience(ring) do
			fx:FireClient(player, "Intro", card(a), card(b))
		end
		hold(INTRO)

		for round = 1, Config.Rounds do
			for _, f in fighters do
				roundTally[f] = tally()
			end
			-- round 1 goes straight from the VS cards to the bell, later rounds get a short countdown
			local countdown = if round == 1 then 0 else Config.Countdown
			for i, f in fighters do
				place(f, corners[i].Start, corners[3 - i].Start.Position)
				Fighters.freeze(f, countdown)
			end
			ring:SetAttribute("MatchRound", round)
			ring:SetAttribute("MatchEndsAt", workspace:GetServerTimeNow() + countdown + Config.RoundTime)
			if countdown > 0 then
				tell(if round == Config.Rounds then "FINAL ROUND" else "ROUND " .. round)
				if hold(countdown) then
					break
				end
			end
			tell("FIGHT!", "Bell")
			fought = true
			if hold(Config.RoundTime) then
				break
			end
			-- someone on the canvas at the bell still has to beat the count
			while (a.State == "Down" or b.State == "Down") and not over() do
				task.wait(0.1)
			end
			if winner then
				break
			end
			if round < Config.Rounds then
				ring:SetAttribute("MatchEndsAt", workspace:GetServerTimeNow() + Config.BreakTime)
				tell("END OF ROUND " .. round, "Bell")
				local standUp: { () -> () } = {}
				for i, f in fighters do
					place(f, corners[i].Start, corners[3 - i].Start.Position)
					Fighters.freeze(f, Config.BreakTime)
					local other = fighters[3 - i]
					table.insert(
						standUp,
						Corner.open(f, {
							Round = round,
							Side = corners[i].Name,
							You = roundTally[f],
							Them = roundTally[other],
							Lead = points[f] - points[other],
							EndsAt = workspace:GetServerTimeNow() + Config.BreakTime,
						})
					)
				end
				local quit = hold(Config.BreakTime)
				-- up off the stool for the bell, or if the other one left mid break
				for _, up in standUp do
					up()
				end
				if quit then
					break
				end
			end
		end

		stopHits()
		stopDowns()
		if not winner and points[a] ~= points[b] then
			winner, how = if points[a] > points[b] then a else b, "DECISION"
		end
		ring:SetAttribute("MatchEndsAt", nil)
		ring:SetAttribute("MatchRound", nil)
		local name = winner and string.upper(if winner.Player then winner.Player.DisplayName else winner.Model.Name)
		local noContest = how == "FORFEIT" and not fought
		tell(if noContest then "OPPONENT LEFT" elseif name then name .. " WINS BY " .. how else "DRAW", "Bell")

		-- record it first so the result screen shows the new record and rank
		local gained: { [Fighters.Fighter]: number } = {}
		for _, f in fighters do
			if f.Player and not recorded[f.Player] and not noContest then
				recorded[f.Player] = true
				gained[f] = Career.matchResult(
					f.Player,
					if winner == nil then "Draw" elseif winner == f then "Win" else "Loss",
					how == "K.O.",
					if vsAI then Config.AIPoints else nil
				)
			end
		end
		for i, f in fighters do
			local other = fighters[3 - i]
			if f.Player and not gone(f) and not noContest then
				fx:FireClient(f.Player, "Result", {
					Outcome = if winner == nil then "Draw" elseif winner == f then "Win" else "Loss",
					How = if winner then how else "DECISION",
					Points = gained[f] or 0,
					You = card(f),
					Them = card(other),
					YouFight = fightTally[f],
					ThemFight = fightTally[other],
				})
			end
		end
		task.wait(Config.EndTime)

		for i, f in fighters do
			f.Match = nil
			f.Model:SetAttribute("InMatch", nil)
			if not f.Player then
				f.Model:Destroy()
			elseif not gone(f) then
				Fighters.reset(f)
				place(f, corners[i].Outside, center())
				PlayerData.foughtMatch(f.Player)
			end
		end
		table.clear(recorded)
		setPad(red, nil)
		setPad(blue, nil)
		ring:SetAttribute("MatchOn", nil)
		running = false
	end

	-- an AI boxer for whoever has been waiting alone on `waiting`, in the `empty` corner
	local function summon(waiting: Pad, empty: Pad)
		local player = waiting.Player
		local them = player and fighterOf(player)
		if not (player and them) then
			return
		end
		summoning = true
		local level = 1
		local rank = CareerData.rankOf((player:GetAttribute("RankPoints") :: number?) or 0)
		for i, r in CareerData.Ranks do
			if r.Name == rank then
				level = i
			end
		end
		local name = AIBoxer.Names[random:NextInteger(1, #AIBoxer.Names)]
		local shirt = AIBoxer.Shirts[random:NextInteger(1, #AIBoxer.Shirts)]
		local ok, model, f = pcall(AIBoxer.make, name, empty.Start.CFrame + Vector3.new(0, 3, 0), shirt)
		summoning = false
		-- they may have stepped off the pad while it loaded
		if not (ok and f) or waiting.Player ~= player or empty.Player or running then
			if ok and model then
				model:Destroy()
			end
			return
		end
		local styles = {}
		for style in CombatConfig.Stances do
			table.insert(styles, style)
		end
		Fighters.setStance(f, styles[random:NextInteger(1, #styles)], true)
		setPad(empty, nil, f)
		task.spawn(AIBoxer.run, f, AIBoxer.ringSkill(level), function()
			return if f.Match then them else nil
		end, nil)
		tell(name .. " STEPS INTO THE RING")
		task.spawn(runMatch, pads[1], pads[2])
	end

	for _, name in { "Red", "Blue" } do
		local folder = padFolder:WaitForChild(name)
		local outside = folder:WaitForChild("CF") :: BasePart
		local pad: Pad = {
			Name = name,
			Start = folder:WaitForChild("Start") :: BasePart,
			Outside = outside,
			Prompt = outside:WaitForChild("Prox") :: ProximityPrompt,
			Occupied = folder:WaitForChild("Occupied") :: BoolValue,
			OccupiedName = folder:WaitForChild("OccupiedName") :: StringValue,
			Player = nil,
			AI = nil,
			Since = 0,
		}
		table.insert(pads, pad)
		setPad(pad, nil)
		pad.Prompt.Triggered:Connect(function(player)
			if running or summoning then
				return
			end
			if pad.Player == player then
				setPad(pad, nil)
				return
			end
			local f = fighterOf(player)
			if pad.Player or pad.AI or padOf(player) or not f or f.State ~= "Idle" or f.Match then
				return
			end
			setPad(pad, player)
			place(f, pad.Start, center())
			local other = pads[if pad == pads[1] then 2 else 1]
			if other.Player then
				task.spawn(runMatch, pads[1], pads[2])
			else
				fx:FireClient(player, "Match", "WAITING FOR AN OPPONENT. AI IN " .. Config.AIWait .. "s")
			end
		end)
	end

	-- give up a pad you walked away from, died on or left the game with. and bring in the AI
	-- for anyone who's been waiting alone long enough
	task.spawn(function()
		while ring.Parent do
			task.wait(0.25)
			if running or summoning then
				continue
			end
			for i, pad in pads do
				local player = pad.Player
				if player then
					local f = fighterOf(player)
					if
						player.Parent ~= Players
						or not f
						or (f.Root.Position - pad.Start.Position).Magnitude > Config.PadLeaveDistance
					then
						setPad(pad, nil)
					else
						local other = pads[3 - i]
						if not other.Player and not other.AI and os.clock() - pad.Since > Config.AIWait then
							task.spawn(summon, pad, other)
						end
					end
				end
			end
		end
	end)

	-- quitting mid match is a loss, written now before the profile closes
	Players.PlayerRemoving:Connect(function(player)
		if running and not recorded[player] and (pads[1].Player == player or pads[2].Player == player) then
			recorded[player] = true
			Career.matchResult(player, "Loss", false, if pads[1].AI or pads[2].AI then Config.AIPoints else nil)
		end
	end)
end

for _, ring in Rings.all() do
	task.spawn(setup, ring)
end
