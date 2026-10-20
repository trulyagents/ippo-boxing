--!strict
-- QA commands on the Cheat remote. Only work in Studio, or live for the owner, and the check is
-- here on the server (any client can fire the remote). They go through the same code the game
-- uses, so testing with them tests the real thing.
--   Cheat:FireServer("SkipPhase")              end the nearest ring's intro, round or break now
--   Cheat:FireServer("Stat", "Power", 25)      set a stat
--   Cheat:FireServer("RankPoints", 100)        add rank points (negative takes them away)
--   Cheat:FireServer("Pass", "VIP")             act as if you own a pass (this session only)
--   Cheat:FireServer("StreakDays", 3)           pretend you last logged in yesterday on a 3 day streak (rejoin to see day 4)
--   Cheat:FireServer("Receipt", "StatRespec", "id")  run a product receipt through the real handler
--   Cheat:FireServer("Style", "Slugger")        switch to any style, unlocked or not (the admin menu)
--   Cheat:FireServer("MaxStats")                every stat to the cap
-- players who can use these get an Admin attribute, which shows the admin menu
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)
local Leaderboard = require(script.Parent.Leaderboard)
local Shop = require(script.Parent.Shop)
local ShopData = require(game:GetService("ReplicatedStorage").Shared.Shop)
local Daily = require(game:GetService("ReplicatedStorage").Shared.Daily)
local Stats = require(game:GetService("ReplicatedStorage").Shared.Stats)
local Rings = require(game:GetService("ReplicatedStorage").Shared.Rings)
local Fighters = require(script.Parent.Fighters)
local Players = game:GetService("Players")

local OWNERS: { [number]: boolean } = {
	[1696717053] = true, -- trulyagents
}

local function allowed(player: Player): boolean
	return RunService:IsStudio() or OWNERS[player.UserId] == true
end

local function finite(n: unknown): boolean
	return typeof(n) == "number" and n == n and math.abs(n) < 1e6
end

local function admin(player: Player)
	if allowed(player) then
		player:SetAttribute("Admin", true)
	end
end
Players.PlayerAdded:Connect(admin)
for _, player in Players:GetPlayers() do
	admin(player)
end

Remotes.Cheat.OnServerEvent:Connect(function(player, command, a, b)
	if not allowed(player) or typeof(command) ~= "string" then
		return
	end
	if command == "SkipPhase" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local ring = root and root:IsA("BasePart") and Rings.nearest(root.Position)
		if ring and ring:GetAttribute("MatchOn") then
			ring:SetAttribute("SkipPhase", true)
		end
	elseif command == "Stat" and typeof(a) == "string" and finite(b) then
		PlayerData.set(player, a, b :: number)
	elseif command == "Receipt" and typeof(a) == "string" and typeof(b) == "string" and RunService:IsStudio() then
		local id = ShopData.Products[a]
		if id then
			print("[Cheats] receipt", a, b, Shop.receipt({ PlayerId = player.UserId, ProductId = id, PurchaseId = b }))
		end
	elseif command == "StreakDays" and finite(a) then
		local data = PlayerData.data(player)
		if data then
			data.Daily.Last = Daily.today(os.time()) - 1
			data.Daily.Streak = math.clamp(math.floor(a :: number), 0, 1000)
		end
	elseif command == "Style" and typeof(a) == "string" then
		local f = Fighters.get(player.Character)
		if f then
			Fighters.setStance(f, a, false, true)
		end
	elseif command == "MaxStats" then
		for _, name in Stats.Names do
			PlayerData.set(player, name, Stats.Cap)
		end
	elseif command == "Pass" and typeof(a) == "string" then
		Shop.grant(player, a)
	elseif command == "RankPoints" and finite(a) then
		local data = PlayerData.data(player)
		if data then
			data.RankPoints = math.max(0, data.RankPoints + math.floor(a :: number))
			Career.show(player)
			Leaderboard.record(player, data.RankPoints)
		end
	end
end)

return {}
