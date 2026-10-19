--!strict
-- Gym equipment runs a short rhythm drill. The server picks the beat times, the client only says
-- when you pressed, and the server grades each press against the beat. Better timing, bigger gain.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Fighters = require(script.Parent.Fighters)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)

local remotes = ReplicatedStorage:WaitForChild("BoxingRemotes")
local fx = remotes:WaitForChild("Fx") :: RemoteEvent
local training = remotes:FindFirstChild("Training") or Instance.new("RemoteEvent")
training.Name = "Training"
training.Parent = remotes

type Session = {
	Stat: string,
	Part: BasePart,
	Start: number, -- server time of the first beat
	Times: { number },
	Graded: { [number]: string },
	Presses: number,
	Token: number,
}
local sessions: { [Player]: Session } = {}
local nextDrill: { [Player]: number } = {}
local token = 0

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
		f.Humanoid.AutoRotate = true
		Fighters.freeze(f, 0)
	end
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
	token += 1
	local s: Session = {
		Stat = stat,
		Part = part,
		Start = workspace:GetServerTimeNow() + Stats.DrillLeadIn,
		Times = Stats.beatTimes(drill),
		Graded = {},
		Presses = 0,
		Token = token,
	}
	sessions[player] = s
	local length = Stats.DrillLeadIn + s.Times[#s.Times] + Stats.DrillGood + 0.3
	nextDrill[player] = now + length + Stats.DrillCooldown
	-- stand still and don't throw real punches while drilling. on the bags and mitts you get
	-- stood a punch away facing them, the jump rope just keeps you where you are
	Fighters.freeze(f, length)
	local stand = f.Root.CFrame
	local flat = (f.Root.Position - part.Position) * Vector3.new(1, 0, 1)
	if Stats.Drills[stat].Punches and flat.Magnitude > 0.1 then
		local at = Vector3.new(part.Position.X, f.Root.Position.Y, part.Position.Z) + flat.Unit * Stats.DrillStandOff
		stand = CFrame.lookAt(at, Vector3.new(part.Position.X, at.Y, part.Position.Z))
	end
	f.Humanoid.WalkSpeed = 0
	f.Humanoid.AutoRotate = false
	-- the client owns its character, so it does the move into place
	training:FireClient(player, "Start", stat, s.Start, s.Times, stand)
	task.delay(length, finish, player, s)
end

training.OnServerEvent:Connect(function(player, kind)
	local s = sessions[player]
	if kind ~= "Hit" or not s then
		return
	end
	-- more presses than this is mashing, it gets nothing
	s.Presses += 1
	if s.Presses > #s.Times * 2 then
		return
	end
	if not near(player, s.Part, 10) then
		finish(player, s)
		return
	end
	-- the press left the client about half a round trip ago
	local at = workspace:GetServerTimeNow() - math.clamp(player:GetNetworkPing(), 0, 0.25) - s.Start
	-- first press near each beat is the one that counts
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
	local grade = Stats.grade(bestOff)
	s.Graded[best] = grade
	training:FireClient(player, "Grade", best, grade)
	local punches = Stats.Drills[s.Stat].Punches
	local f = Fighters.get(player.Character)
	if punches and f and grade ~= "Miss" then
		Fighters.show(f, punches[(best - 1) % #punches + 1])
		-- bags hang on a rope and swing for real, the mitts are just a target
		local push = Stats.DrillPush[grade]
		local away = (s.Part.Position - f.Root.Position) * Vector3.new(1, 0, 1)
		if push and not s.Part.Anchored and away.Magnitude > 0.1 then
			task.delay(Config.Moves[punches[(best - 1) % #punches + 1]].Startup, function()
				s.Part:ApplyImpulse(away.Unit * push * s.Part.AssemblyMass)
			end)
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
