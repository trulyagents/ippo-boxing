--!strict
-- Ring matches. Two players take the pads in the red and blue corners, then it's a few rounds
-- scored on damage and knockdowns, a KO ends it early. Only the two of them can hit each other.
-- The ring carries MatchOn, MatchRound and MatchEndsAt so clients can show the clock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig).Match
local Fighters = require(script.Parent.Fighters)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)

local ring = workspace:WaitForChild("Ring")
local padFolder = workspace:WaitForChild("Map"):WaitForChild("GymRing"):WaitForChild("JoinPads")
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
local stoolTemplate = ReplicatedStorage:WaitForChild("BoxingGear"):WaitForChild("CornerStool") :: Model

-- the corner pick: one per break, only while you're sitting in it
local picking: { [Player]: Fighters.Fighter } = {}
local cornerPick = Instance.new("RemoteEvent")
cornerPick.Name = "CornerPick"
cornerPick.Parent = fx.Parent
cornerPick.OnServerEvent:Connect(function(player, pick)
	local f = picking[player]
	if not f or typeof(pick) ~= "string" or Fighters.get(f.Model) ~= f then
		return
	end
	if Fighters.corner(f, pick) then
		picking[player] = nil
		cornerPick:FireClient(player, pick)
	end
end)

-- a stool on the canvas under where the boxer stands, facing the same way, and sit them on it
local function sitDown(f: Fighters.Fighter): Model
	local stool = stoolTemplate:Clone()
	local look = f.Root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { f.Model }
	local hit = workspace:Raycast(f.Root.Position, Vector3.new(0, -10, 0), params)
	local floor = if hit then hit.Position else f.Root.Position - Vector3.new(0, 3, 0)
	stool:PivotTo(CFrame.lookAt(floor, floor + Vector3.new(look.X, 0, look.Z)))
	stool.Parent = workspace
	f.Model:SetAttribute("Sitting", true)
	return stool
end

type Pad = {
	Name: string,
	Start: BasePart, -- inside the ring, where you stand for the bell
	Outside: BasePart, -- outside the ropes, where the prompt is and where you go after
	Prompt: ProximityPrompt,
	Occupied: BoolValue,
	OccupiedName: StringValue,
	Player: Player?,
}

local pads: { Pad } = {}
local running = false
local recorded: { [Player]: boolean } = {} -- players whose result is already in this match

local function setPad(pad: Pad, player: Player?)
	pad.Player = player
	pad.Occupied.Value = player ~= nil
	pad.OccupiedName.Value = if player then player.DisplayName else "Nil"
	pad.Prompt.ActionText = if player then "Leave" else "Fight"
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

local function fighterOf(player: Player): Fighters.Fighter?
	return Fighters.get(player.Character)
end

local function center(): Vector3
	return (pads[1].Start.Position + pads[2].Start.Position) / 2
end

local function place(f: Fighters.Fighter, part: BasePart, faceTo: Vector3)
	local at = part.Position + Vector3.new(0, 0.5, 0)
	f.Model:PivotTo(CFrame.lookAt(at, Vector3.new(faceTo.X, at.Y, faceTo.Z)))
end

-- shouts go to everyone near the ring, not the whole map
local function tell(text: string, sound: string?)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - center()).Magnitude < 70 then
			fx:FireClient(player, "Match", text, sound)
		end
	end
end

local function runMatch(red: Pad, blue: Pad)
	local redPlayer, bluePlayer = red.Player, blue.Player
	local a, b = redPlayer and fighterOf(redPlayer), bluePlayer and fighterOf(bluePlayer)
	if not (a and b and redPlayer and bluePlayer) then
		return
	end
	running = true
	ring:SetAttribute("MatchOn", true)
	local fighters = { a, b }
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
		f.Match = "Ring"
		f.Model:SetAttribute("InMatch", true)
	end
	Fighters.onHit = function(attacker, target, damage)
		if points[attacker] and points[target] then
			points[attacker] += damage
			count(attacker, "Hits", 1)
			count(attacker, "Damage", damage)
		end
	end
	Fighters.onDown = function(target, attacker)
		if points[attacker] and points[target] then
			points[attacker] += Config.KnockdownPoints
			count(attacker, "Downs", 1)
		end
	end

	local winner: Fighters.Fighter? = nil
	local how = ""
	local function gone(f: Fighters.Fighter): boolean
		local player = f.Player
		return not player or player.Parent ~= Players or Fighters.get(f.Model) ~= f or f.Model.Parent ~= workspace
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
		end
		return false
	end

	-- the VS screen: both in their corners, names, ranks and records up, the bell
	local function card(player: Player)
		return {
			Name = player.DisplayName,
			UserId = player.UserId,
			Rank = player:GetAttribute("Rank") or "ROOKIE",
			Wins = player:GetAttribute("Wins") or 0,
			Losses = player:GetAttribute("Losses") or 0,
			Draws = player:GetAttribute("Draws") or 0,
			KOs = player:GetAttribute("KOs") or 0,
		}
	end
	for i, f in fighters do
		place(f, corners[i].Start, corners[3 - i].Start.Position)
		Fighters.freeze(f, Config.Intro)
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - center()).Magnitude < 70 then
			fx:FireClient(player, "Intro", card(redPlayer), card(bluePlayer))
		end
	end
	hold(Config.Intro)

	for round = 1, Config.Rounds do
		for _, f in fighters do
			roundTally[f] = tally()
		end
		for i, f in fighters do
			place(f, corners[i].Start, corners[3 - i].Start.Position)
			Fighters.freeze(f, Config.Countdown)
		end
		ring:SetAttribute("MatchRound", round)
		ring:SetAttribute("MatchEndsAt", workspace:GetServerTimeNow() + Config.Countdown + Config.RoundTime)
		tell(if round == Config.Rounds then "FINAL ROUND" else "ROUND " .. round)
		if hold(Config.Countdown) then
			break
		end
		tell("FIGHT!", "Bell")
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
			local stools: { Model } = {}
			for i, f in fighters do
				place(f, corners[i].Start, corners[3 - i].Start.Position)
				Fighters.freeze(f, Config.BreakTime)
				table.insert(stools, sitDown(f))
				-- the corner: guard back, how the round went, and one pick (CornerPick remote)
				Fighters.rest(f)
				local other = fighters[3 - i]
				if f.Player then
					picking[f.Player] = f
					fx:FireClient(f.Player, "Corner", {
						Round = round,
						Side = corners[i].Name,
						You = roundTally[f],
						Them = roundTally[other],
						Lead = points[f] - points[other],
						EndsAt = workspace:GetServerTimeNow() + Config.BreakTime,
					})
				end
			end
			local quit = hold(Config.BreakTime)
			table.clear(picking)
			-- up off the stool for the bell, or if the other one left mid break
			for _, stool in stools do
				stool:Destroy()
			end
			for _, f in fighters do
				f.Model:SetAttribute("Sitting", nil)
			end
			if quit then
				break
			end
		end
	end

	Fighters.onHit, Fighters.onDown = nil, nil
	if not winner and points[a] ~= points[b] then
		winner, how = if points[a] > points[b] then a else b, "DECISION"
	end
	ring:SetAttribute("MatchEndsAt", nil)
	ring:SetAttribute("MatchRound", nil)
	local name = winner and winner.Player and string.upper(winner.Player.DisplayName)
	tell(if name then name .. " WINS BY " .. how else "DRAW", "Bell")

	-- record it first so the result screen shows the new record and rank
	local gained: { [Fighters.Fighter]: number } = {}
	for _, f in fighters do
		if f.Player and not recorded[f.Player] then
			recorded[f.Player] = true
			gained[f] = Career.matchResult(
				f.Player,
				if winner == nil then "Draw" elseif winner == f then "Win" else "Loss",
				how == "K.O."
			)
		end
	end
	for i, f in fighters do
		local other = fighters[3 - i]
		if f.Player and not gone(f) then
			fx:FireClient(f.Player, "Result", {
				Outcome = if winner == nil then "Draw" elseif winner == f then "Win" else "Loss",
				How = if winner then how else "DECISION",
				Points = gained[f] or 0,
				You = card(f.Player),
				Them = if other.Player then card(other.Player) else nil,
				YouFight = fightTally[f],
				ThemFight = fightTally[other],
			})
		end
	end
	task.wait(Config.EndTime)

	for i, f in fighters do
		f.Match = nil
		f.Model:SetAttribute("InMatch", nil)
		if not gone(f) then
			Fighters.reset(f)
			place(f, corners[i].Outside, center())
			if f.Player then
				PlayerData.foughtMatch(f.Player)
			end
		end
	end
	table.clear(recorded)
	setPad(red, nil)
	setPad(blue, nil)
	ring:SetAttribute("MatchOn", nil)
	running = false
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
	}
	table.insert(pads, pad)
	setPad(pad, nil)
	pad.Prompt.Triggered:Connect(function(player)
		if running then
			return
		end
		if pad.Player == player then
			setPad(pad, nil)
			return
		end
		local f = fighterOf(player)
		if pad.Player or padOf(player) or not f or f.State ~= "Idle" or f.Match then
			return
		end
		setPad(pad, player)
		place(f, pad.Start, center())
		local other = pads[if pad == pads[1] then 2 else 1]
		if other.Player then
			task.spawn(runMatch, pads[1], pads[2])
		else
			fx:FireClient(player, "Match", "WAITING FOR AN OPPONENT")
		end
	end)
end

-- give up a pad you walked away from, died on or left the game with
task.spawn(function()
	while true do
		task.wait(0.25)
		if running then
			continue
		end
		for _, pad in pads do
			local player = pad.Player
			if player then
				local f = fighterOf(player)
				if
					player.Parent ~= Players
					or not f
					or (f.Root.Position - pad.Start.Position).Magnitude > Config.PadLeaveDistance
				then
					setPad(pad, nil)
				end
			end
		end
	end
end)

-- quitting mid match is a loss, written now before the profile closes
Players.PlayerRemoving:Connect(function(player)
	if running and not recorded[player] and (pads[1].Player == player or pads[2].Player == player) then
		recorded[player] = true
		Career.matchResult(player, "Loss", false)
	end
end)
