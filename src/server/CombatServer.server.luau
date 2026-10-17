-- Turns players into boxers and takes their inputs. Clients only ever say what they
-- pressed; Fighters decides what actually happens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Fighters = require(script.Parent.Fighters)
local Gear = require(script.Parent.Gear)

local remotes = ReplicatedStorage:FindFirstChild("BoxingRemotes") or Instance.new("Folder")
remotes.Name = "BoxingRemotes"
remotes.Parent = ReplicatedStorage
local action = remotes:FindFirstChild("Action") or Instance.new("RemoteEvent")
action.Name = "Action"
action.Parent = remotes
local fx = remotes:FindFirstChild("Fx") or Instance.new("RemoteEvent")
fx.Name = "Fx"
fx.Parent = remotes
Fighters.setFxRemote(fx)

-- R6 for everyone so the boxing poses fit every avatar the same way
Players.CharacterAutoLoads = false

local function spawnPoint(): CFrame
	local spawn = workspace:FindFirstChild("SpawnLocation")
	return if spawn and spawn:IsA("BasePart") then spawn.CFrame + Vector3.new(0, 3.5, 0) else CFrame.new(0, 5, 0)
end

local function loadBoxer(player: Player)
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
	end)
	if not ok or not description then
		description = Instance.new("HumanoidDescription")
	end
	local made, character = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not made or not character then
		player:LoadCharacter()
		return
	end
	character.Name = player.Name
	character:PivotTo(spawnPoint())
	player.Character = character
	character.Parent = workspace
	Gear.gloves(character)
	Gear.trunks(character)
	Fighters.register(character, player)
	-- boxing never kills you, so dying means you fell off the map or reset
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			task.wait(2)
			if player.Parent == Players then
				loadBoxer(player)
			end
		end)
	end
end

Players.PlayerAdded:Connect(loadBoxer)
for _, player in Players:GetPlayers() do
	task.spawn(loadBoxer, player)
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
	elseif kind == "GetUp" then
		Fighters.mash(f)
	elseif kind == "Reset" then
		-- back to full after a KO so you can keep practising
		if f.State == "KO" then
			Fighters.reset(f)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated >= 0.1 then
		Fighters.tick(accumulated)
		accumulated = 0
	end
end)
