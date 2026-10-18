--!strict
-- Loads and saves each player's stats with ProfileStore. Stats are also put on the player as
-- attributes (StatPower and so on) so a stats screen can show them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.ProfileStore)
local Stats = require(ReplicatedStorage.Shared.Stats)

local template = { Stats = {} :: { [string]: number } }
local store = ProfileStore.New(if RunService:IsStudio() then "BoxersStudio" else "Boxers", template)
local profiles: { [Player]: any } = {}

local PlayerData = {}

local function show(player: Player, stats: { [string]: number })
	for _, name in Stats.Names do
		player:SetAttribute("Stat" .. name, math.floor((stats[name] or 0) * 10) / 10)
	end
end

-- yields. nil if the data couldn't load, the player gets kicked then so nothing unsaved happens
function PlayerData.load(player: Player): { [string]: number }?
	local ok, profile = pcall(function()
		return store:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})
	end)
	if not ok or not profile then
		if player.Parent == Players then
			player:Kick("Couldn't load your data, please rejoin")
		end
		return nil
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was loaded somewhere else, please rejoin")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end
	profiles[player] = profile
	show(player, profile.Data.Stats)
	return profile.Data.Stats
end

function PlayerData.stats(player: Player): { [string]: number }?
	local profile = profiles[player]
	return profile and profile.Data.Stats
end

function PlayerData.add(player: Player, stat: string, amount: number)
	local stats = PlayerData.stats(player)
	if not stats or not Stats.MaxBonus[stat] then
		return
	end
	stats[stat] = math.min(Stats.Cap, (stats[stat] or 0) + amount)
	show(player, stats)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end)

return PlayerData
