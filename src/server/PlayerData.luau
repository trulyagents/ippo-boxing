--!strict
-- loads and saves stats with ProfileStore, mirrored as attributes (StatPower...)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.ProfileStore)
local Remotes = require(script.Parent.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)

local template = {
	-- bump this and migrate in load if a field ever gets renamed or reshaped. new fields just
	-- go in the template, Reconcile adds them to old saves
	Version = 1,
	Stats = {} :: { [string]: number },
	Record = { Wins = 0, Losses = 0, Draws = 0, KOs = 0 },
	RankPoints = 0,
	Stance = "Orthodox", -- what you spawn in, your last pick
	Daily = { Last = 0, Streak = 0 }, -- Last is the UTC day number of the last login that counted
	Glove = "Red", -- shop glove color
	FriendBonusDay = 0, -- utc day of the last play-with-a-friend bonus
	StatPool = 0, -- points from a respec, waiting to be spent
	Receipts = {} :: { string }, -- product purchase ids already paid out, newest last
	Quest = { Step = 1, Count = 0 },
}
export type Data = typeof(template)
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

-- the whole saved table, for Career
function PlayerData.data(player: Player): Data?
	local profile = profiles[player]
	return profile and profile.Data
end

function PlayerData.stats(player: Player): { [string]: number }?
	local profile = profiles[player]
	return profile and profile.Data.Stats
end

-- a stance or special that just opened up gets its own card on the client (Fx "Unlocked")
local function unlockedNow(stats: { [string]: number }): { [string]: boolean }
	local open = {}
	for name in Stats.Unlocks do
		open[name] = Stats.unlocked(stats, name)
	end
	return open
end
local function announce(player: Player, before: { [string]: boolean }, stats: { [string]: number })
	for name, open in unlockedNow(stats) do
		if open and not before[name] then
			Remotes.Fx:FireClient(player, "Unlocked", name)
		end
	end
end

-- QA only (Cheats): put a stat at an exact value
function PlayerData.set(player: Player, stat: string, value: number)
	local stats = PlayerData.stats(player)
	if stats and Stats.MaxBonus[stat] then
		local before = unlockedNow(stats)
		stats[stat] = math.clamp(value, 0, Stats.Cap)
		show(player, stats)
		announce(player, before, stats)
	end
end

function PlayerData.setStance(player: Player, stance: string)
	local data = PlayerData.data(player)
	if data then
		data.Stance = stance
	end
end

function PlayerData.add(player: Player, stat: string, amount: number)
	local stats = PlayerData.stats(player)
	if not stats or not Stats.MaxBonus[stat] then
		return
	end
	local before = unlockedNow(stats)
	stats[stat] = math.min(Stats.Cap, (stats[stat] or 0) + amount)
	show(player, stats)
	announce(player, before, stats)
end

-- write it now instead of waiting for the 5 minute autosave, for things that would really hurt
-- to lose if the server crashed (a match result). doesn't yield
function PlayerData.save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

-- for paid purchases: save now and wait until roblox has the version with this receipt in it.
-- false if it didn't land in time (the caller says NotProcessedYet and roblox asks again)
function PlayerData.saveReceipt(player: Player, purchaseId: string, timeout: number): boolean
	local profile = profiles[player]
	if not (profile and profile:IsActive()) then
		return false
	end
	local landed = false
	local conn = profile.OnAfterSave:Connect(function(saved)
		if saved and saved.Receipts and table.find(saved.Receipts, purchaseId) then
			landed = true
		end
	end)
	profile:Save()
	local untilTime = os.clock() + timeout
	while not landed and os.clock() < untilTime do
		task.wait(0.2)
	end
	conn:Disconnect()
	return landed
end

-- training only counts if you've been fighting lately, so standing afk at a bag does nothing
local landed: { [Player]: { count: number, at: number } } = {}
function PlayerData.landed(player: Player)
	local l = landed[player] or { count = 0, at = 0 }
	if os.clock() - l.at > Stats.FightWindow then
		l.count = 0
	end
	l.count += 1
	l.at = os.clock()
	landed[player] = l
end

-- a finished ring match counts as a full spar
function PlayerData.foughtMatch(player: Player)
	landed[player] = { count = Stats.FightHits, at = os.clock() }
end

function PlayerData.foughtRecently(player: Player): boolean
	local l = landed[player]
	return l ~= nil and l.count >= Stats.FightHits and os.clock() - l.at <= Stats.FightWindow
end

Players.PlayerRemoving:Connect(function(player)
	landed[player] = nil
	local profile = profiles[player]
	if profile then
		-- deferred so other leave handlers (a forfeit loss) still get to write first
		task.defer(function()
			profile:EndSession()
		end)
	end
end)

return PlayerData
