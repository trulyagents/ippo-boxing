--!strict
-- Every gym station runs its own short minigame (see Stats.Drills). The server picks the beats
-- and cue times and grades every press, the client only says what was pressed and when.
-- Better grades, bigger gain.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Fighters = require(script.Parent.Fighters)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)

local Remotes = require(script.Parent.Remotes)
local fx = Remotes.Fx
local training = Remotes.Training

type Session = {
	Stat: string,
	Kind: string,
	Part: BasePart,
	Start: number, -- server time of the first beat (Combo, Rhythm)
	Times: { number }, -- one entry per beat or rep, grades are indexed the same way
	Graded: { [number]: string },
	Presses: number,
	Rep: number, -- the rep being played (Charge, Reaction)
	DownAt: number?, -- Charge: when the hold started
	CueAt: number?, -- Reaction: when the mitt came up
}
local sessions: { [Player]: Session } = {}
local nextDrill: { [Player]: number } = {}

local function statFor(name: string): string?
	for _, pair in Stats.Equipment do
		if name:sub(1, #pair[1]) == pair[1] then
			return pair[2]
		end
	end
	return nil
end

local function near(player: Player, part: BasePart, range: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - part.Position).Magnitude <= range
end

-- the press left the client about half a round trip ago
local function pressTime(player: Player): number
	return workspace:GetServerTimeNow() - math.clamp(player:GetNetworkPing(), 0, 0.25)
end

local function finish(player: Player, s: Session)
	if sessions[player] ~= s then
		return
	end
	sessions[player] = nil
	local score = 0
	for i in s.Times do
		local g = s.Graded[i]
		score += if g == "Perfect" then 1 elseif g == "Good" then 0.5 else 0
	end
	-- one decimal so the menu shows clean numbers
	local gain = math.floor(Stats.DrillGain * score / #s.Times * 10 + 0.5) / 10
	if gain > 0 then
		PlayerData.add(player, s.Stat, gain)
		Career.event(player, "Drill", s.Stat)
	end
	if score == #s.Times then
		Career.event(player, "PerfectDrill")
	end
	training:FireClient(player, "Done", gain)
	local f = Fighters.get(player.Character)
	if f then
		Fighters.setDrilling(f, false)
		f.Model:SetAttribute("Skipping", nil)
		Fighters.freeze(f, 0)
	end
end

-- a graded beat or rep: tell the client, and on a landed one throw the punch and swing the bag
local function grade(player: Player, s: Session, i: number, g: string)
	s.Graded[i] = g
	training:FireClient(player, "Grade", i, g)
	local drill = Stats.Drills[s.Stat]
	local punches = drill.Punches or drill.Keys
	local f = Fighters.get(player.Character)
	if not (punches and f) or g == "Miss" then
		return
	end
	local punch = punches[(i - 1) % #punches + 1]
	Fighters.show(f, punch)
	-- bags hang on a rope and swing for real, the mitts are just a target
	local push = Stats.DrillPush[g]
	local away = (s.Part.Position - f.Root.Position) * Vector3.new(1, 0, 1)
	if push and not s.Part.Anchored and away.Magnitude > 0.1 then
		task.delay(Config.Moves[punch].Startup, function()
			s.Part:ApplyImpulse(away.Unit * push * s.Part.AssemblyMass)
		end)
	end
end

-- the open sides of each piece of equipment (not into the wall or the bag next to it), worked
-- out once. a drill stands you square in front of one of them
local fronts: { [BasePart]: { Vector3 } } = {}
local AXES = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
local function findFronts(part: BasePart, ignore: Instance): { Vector3 }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	local open = {}
	for _, axis in AXES do
		-- out past where you'd stand, at chest height
		if not workspace:Raycast(part.Position, axis * (Stats.DrillStandOff + 2), params) then
			table.insert(open, axis)
		end
	end
	return open
end

-- the mitt comes up at random moments, the server sends the cue the moment it happens
local function runReaction(player: Player, s: Session)
	local random = Random.new()
	task.wait(Stats.DrillLeadIn)
	for rep in s.Times do
		task.wait(random:NextNumber(Stats.ReactDelay[1], Stats.ReactDelay[2]))
		if sessions[player] ~= s then
			return
		end
		s.Rep, s.CueAt = rep, workspace:GetServerTimeNow()
		training:FireClient(player, "Cue", rep)
		task.wait(Stats.ReactWindow)
		if sessions[player] ~= s then
			return
		end
		s.CueAt = nil
		if not s.Graded[rep] then
			grade(player, s, rep, "Miss")
		end
	end
	task.wait(0.5)
	finish(player, s)
end

local function begin(player: Player, stat: string, part: BasePart)
	local now = os.clock()
	if sessions[player] or now < (nextDrill[player] or 0) or not near(player, part, 10) then
		return
	end
	local f = Fighters.get(player.Character)
	if not f or f.State ~= "Idle" or f.Match then
		return
	end
	-- the quests walk you through the drills, so the spar rule only kicks in after them
	if not PlayerData.foughtRecently(player) and not Career.onQuests(player) then
		fx:FireClient(player, "Match", "SPAR FIRST")
		return
	end
	local drill = Stats.Drills[stat]
	local times = {}
	if drill.Kind == "Combo" or drill.Kind == "Rhythm" then
		times = Stats.beatTimes(drill)
	else
		for i = 1, drill.Reps :: number do
			times[i] = 0
		end
	end
	local s: Session = {
		Stat = stat,
		Kind = drill.Kind,
		Part = part,
		Start = workspace:GetServerTimeNow() + Stats.DrillLeadIn,
		Times = times,
		Graded = {},
		Presses = 0,
		Rep = 1,
		DownAt = nil,
		CueAt = nil,
	}
	sessions[player] = s
	-- how long it can run at most
	local length = Stats.DrillLeadIn
		+ if drill.Kind == "Charge"
			then #times * (Stats.ChargeMax + 1.5)
			elseif drill.Kind == "Reaction" then #times * (Stats.ReactDelay[2] + Stats.ReactWindow) + 1
			else times[#times] + Stats.DrillGood + 0.3
	nextDrill[player] = now + Stats.DrillCooldown
	-- stand still and don't throw real punches while drilling. on the bags and mitts you get
	-- stood a punch away facing them, the jump rope just keeps you where you are
	Fighters.freeze(f, length)
	local stand = f.Root.CFrame
	local flat = (f.Root.Position - part.Position) * Vector3.new(1, 0, 1)
	if drill.Kind ~= "Rhythm" and flat.Magnitude > 0.1 then
		-- the open side closest to where you walked up from, square on, never at an angle
		local side, best = nil, -math.huge
		for _, axis in fronts[part] or {} do
			local d = axis:Dot(flat.Unit)
			if d > best then
				side, best = axis, d
			end
		end
		side = side or flat.Unit
		local at = Vector3.new(part.Position.X, f.Root.Position.Y, part.Position.Z) + side * Stats.DrillStandOff
		stand = CFrame.lookAt(at, Vector3.new(part.Position.X, at.Y, part.Position.Z))
	end
	Fighters.setDrilling(f, true)
	-- everyone around draws a rope in your hands for the jump rope drill (JumpRopeProp)
	if drill.Kind == "Rhythm" then
		f.Model:SetAttribute("Skipping", true)
	end
	-- the client owns its character, so it does the move into place
	training:FireClient(player, "Start", stat, s.Start, times, stand)
	if drill.Kind == "Reaction" then
		task.spawn(runReaction, player, s)
	else
		task.delay(length, finish, player, s)
	end
end

-- Combo and Rhythm: the first press near each beat counts, Combo also wants the right punch
local function onBeat(player: Player, s: Session, key: string?)
	local at = pressTime(player) - s.Start
	local best, bestOff = nil, math.huge
	for i, t in s.Times do
		local off = at - t
		if not s.Graded[i] and math.abs(off) < math.abs(bestOff) then
			best, bestOff = i, off
		end
	end
	if not best or math.abs(bestOff) > Stats.DrillGood + 0.13 then
		return
	end
	local keys = Stats.Drills[s.Stat].Keys
	local wrong = keys ~= nil and keys[(best - 1) % #keys + 1] ~= key
	grade(player, s, best, if wrong then "Miss" else Stats.grade(bestOff))
end

training.OnServerEvent:Connect(function(player, kind, key)
	local s = sessions[player]
	if not s or (kind ~= "Hit" and kind ~= "Down" and kind ~= "Up") or (key ~= nil and typeof(key) ~= "string") then
		return
	end
	-- more presses than this is mashing, it gets nothing
	s.Presses += 1
	if s.Presses > #s.Times * 3 then
		return
	end
	if not near(player, s.Part, 10) then
		finish(player, s)
		return
	end
	if (s.Kind == "Combo" or s.Kind == "Rhythm") and kind == "Hit" then
		onBeat(player, s, key)
	elseif s.Kind == "Charge" then
		if s.Rep > #s.Times then
			return
		end
		if kind == "Down" and not s.DownAt and workspace:GetServerTimeNow() >= s.Start then
			s.DownAt = pressTime(player)
		elseif kind == "Up" and s.DownAt then
			local held = pressTime(player) - s.DownAt
			s.DownAt = nil
			grade(player, s, s.Rep, Stats.chargeGrade(held))
			s.Rep += 1
			if s.Rep > #s.Times then
				task.delay(0.8, finish, player, s)
			end
		end
	elseif s.Kind == "Reaction" and kind == "Hit" then
		local cue = s.CueAt
		if cue and not s.Graded[s.Rep] then
			-- the cue took half a round trip to get there and the press half a round trip back
			local seconds = workspace:GetServerTimeNow() - cue - 2 * math.clamp(player:GetNetworkPing(), 0, 0.25)
			s.CueAt = nil
			grade(player, s, s.Rep, Stats.reactGrade(math.max(0, seconds)))
		end
	end
end)

local function hook(model: Model, stat: string)
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Train " .. stat
	prompt.ObjectText = model.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	fronts[part] = findFronts(part, model.Parent or model)
	-- the server swings the bags, so it has to own them
	if part:CanSetNetworkOwnership() then
		part:SetNetworkOwner(nil)
	end
	prompt.Triggered:Connect(function(player)
		begin(player, stat, part)
	end)
end

local gym = workspace:WaitForChild("Map"):WaitForChild("Gym")
for _, d in gym:GetDescendants() do
	local stat = d:IsA("Model") and statFor(d.Name)
	-- skip models nested in another piece of the same equipment
	if stat and not (d.Parent and d.Parent:IsA("Model") and statFor(d.Parent.Name)) then
		hook(d :: Model, stat)
	end
end

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	nextDrill[player] = nil
end)
