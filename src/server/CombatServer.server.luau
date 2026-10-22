--!strict
-- makes players into boxers and takes their inputs, Fighters decides what happens
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Fighters = require(script.Parent.Fighters)
local Gear = require(script.Parent.Gear)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)
local Shop = require(script.Parent.Shop)

local Remotes = require(script.Parent.Remotes)
require(script.Parent.Cheats) -- QA commands, Studio and the owner only
local action = Remotes.Action

-- R6 for everyone so the boxing poses fit every avatar the same way
Players.CharacterAutoLoads = false

-- players start on the sidewalk right outside the gym door
local function spawnPoint(): CFrame
	local map = workspace:FindFirstChild("Map")
	local outside = map and map:FindFirstChild("PlayerSpawn")
	if outside and outside:IsA("BasePart") then
		return outside.CFrame
	end
	local spawn = workspace:FindFirstChild("SpawnLocation")
	return if spawn and spawn:IsA("BasePart") then spawn.CFrame + Vector3.new(0, 3.5, 0) else CFrame.new(0, 5, 0)
end

local function loadBoxer(player: Player)
	local stats = PlayerData.stats(player)
	if not stats then
		return
	end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(math.max(player.UserId, 1))
	end)
	if not ok or not description then
		description = Instance.new("HumanoidDescription")
	end
	local made, character = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	end)
	if not made or not character then
		-- their avatar wouldn't build, a plain one still gets to box
		made, character = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(
				Instance.new("HumanoidDescription"),
				Enum.HumanoidRigType.R6
			)
		end)
	end
	if not made or not character then
		-- roblox's avatar service is down, try again shortly instead of leaving them without a body
		task.delay(5, function()
			if player.Parent == Players and not (player.Character and player.Character.Parent) then
				loadBoxer(player)
			end
		end)
		return
	end
	character.Name = player.Name
	character:PivotTo(spawnPoint())
	player.Character = character
	character.Parent = workspace
	Gear.strip(character)
	Gear.gloves(character, Shop.gloveColor(player))
	Gear.trunks(character)
	local f = Fighters.register(character, player, stats)
	-- back in the stance you last picked
	local data = PlayerData.data(player)
	if f and data then
		Fighters.setStance(f, data.Stance, true)
	end
	-- boxing never kills you, so dying means you fell off the map or reset
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			task.wait(2)
			-- setting player.Character doesn't remove the old body, it would stay a fighter forever
			character:Destroy()
			if player.Parent == Players then
				loadBoxer(player)
			end
		end)
	end
end

local function join(player: Player)
	if PlayerData.load(player) then
		Shop.joined(player)
		Career.joined(player)
		Career.show(player)
		loadBoxer(player)
	end
end
Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do
	task.spawn(join, player)
end

-- token bucket per player so spamming the remote does nothing
local buckets: { [Player]: { tokens: number, time: number } } = {}
local function allow(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = Config.ActionBurst, time = now }
		buckets[player] = b
	end
	b.tokens = math.min(Config.ActionBurst, b.tokens + (now - b.time) * Config.ActionsPerSecond)
	b.time = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

action.OnServerEvent:Connect(function(player, kind, value)
	if typeof(kind) ~= "string" or not allow(player) then
		return
	end
	local f = Fighters.get(player.Character)
	if not f then
		return
	end
	if kind == "Punch" and typeof(value) == "string" and Config.Moves[value] then
		Fighters.punch(f, value)
	elseif kind == "Guard" and (value == "High" or value == "Low" or value == false) then
		Fighters.setGuard(f, if value == false then nil else value)
	elseif kind == "Weave" and typeof(value) == "boolean" then
		Fighters.setWeave(f, value)
	elseif kind == "Slip" and typeof(value) == "string" then
		Fighters.slip(f, value)
	elseif kind == "Stance" then
		Fighters.switchStance(f)
	elseif kind == "SetStance" and typeof(value) == "string" then
		Fighters.setStance(f, value)
	elseif kind == "Special" and (value == 1 or value == 2) then
		Fighters.special(f, value)
	elseif kind == "TestSecondWind" and RunService:IsStudio() then
		Fighters.testSecondWind(f)
	elseif kind == "GetUp" then
		Fighters.mash(f)
	elseif kind == "Reset" then
		-- back to full after a KO so you can keep practising
		if f.State == "KO" and not f.Match then
			Fighters.reset(f)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	-- roblox doesn't always destroy a leaver's body, and Fighters only lets go of it on Destroying
	if player.Character then
		player.Character:Destroy()
	end
end)

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated >= 0.1 then
		Fighters.tick(accumulated)
		accumulated = 0
	end
end)
