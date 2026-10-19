--!strict
-- QA commands on the Cheat remote. Only work in Studio, or live for the owner, and the check is
-- here on the server (any client can fire the remote). They go through the same code the game
-- uses, so testing with them tests the real thing.
--   Cheat:FireServer("SkipPhase")              end the ring's intro, round or break now
--   Cheat:FireServer("Stat", "Power", 25)      set a stat
--   Cheat:FireServer("RankPoints", 100)        add rank points (negative takes them away)
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)
local Leaderboard = require(script.Parent.Leaderboard)

local OWNERS: { [number]: boolean } = {
	[1696717053] = true, -- trulyagents
}

local function allowed(player: Player): boolean
	return RunService:IsStudio() or OWNERS[player.UserId] == true
end

local function finite(n: unknown): boolean
	return typeof(n) == "number" and n == n and math.abs(n) < 1e6
end

Remotes.Cheat.OnServerEvent:Connect(function(player, command, a, b)
	if not allowed(player) or typeof(command) ~= "string" then
		return
	end
	if command == "SkipPhase" then
		local ring = workspace:FindFirstChild("Ring")
		if ring and ring:GetAttribute("MatchOn") then
			ring:SetAttribute("SkipPhase", true)
		end
	elseif command == "Stat" and typeof(a) == "string" and finite(b) then
		PlayerData.set(player, a, b :: number)
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
