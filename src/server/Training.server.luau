--!strict
-- Gym equipment trains stats. Hold the prompt for a rep, the server owns the timing and the gain.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Shared.Stats)
local PlayerData = require(script.Parent.PlayerData)

local nextRep: { [Player]: number } = {}

local function statFor(name: string): string?
	for _, pair in Stats.Equipment do
		if name:sub(1, #pair[1]) == pair[1] then
			return pair[2]
		end
	end
	return nil
end

local function hook(model: Model, stat: string)
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Train " .. stat
	prompt.ObjectText = model.Name
	prompt.HoldDuration = Stats.TrainHold
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if now < (nextRep[player] or 0) then
			return
		end
		nextRep[player] = now + Stats.TrainCooldown
		PlayerData.add(player, stat, Stats.TrainGain)
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
	nextRep[player] = nil
end)
