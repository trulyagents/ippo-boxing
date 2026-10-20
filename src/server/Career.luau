--!strict
-- Fight record, rank points and the quest line, saved in the player's profile. Everything is
-- also put on the player as attributes (Wins, Rank, QuestStep...) for the menu, and Wins and
-- Rank go in leaderstats so they show in the player list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Career = require(ReplicatedStorage.Shared.Career)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Stats = require(ReplicatedStorage.Shared.Stats)
local PlayerData = require(script.Parent.PlayerData)
local Leaderboard = require(script.Parent.Leaderboard)
local Shop = require(script.Parent.Shop)
local ShopData = require(ReplicatedStorage.Shared.Shop)

local fx = require(script.Parent.Remotes).Fx
local function tell(player: Player, text: string)
	fx:FireClient(player, "Match", text)
end

local CareerServer = {}

-- the new player funnel in the creator hub (Analytics > Funnels): step 1 is joining for the first
-- time, step n+1 is finishing quest n, so the drop between two steps is where new players quit
local AnalyticsService = game:GetService("AnalyticsService")
local function funnel(player: Player, step: number, name: string)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

-- playing with a friend: when you land in a server a friend is in, you both get a small boost on
-- your weakest stat, once a day each. that's the whole reward for the invite button
local FRIEND_BONUS = 1
local function weakestStat(data: any): string
	local weakest, lowest = Stats.Names[1], math.huge
	for _, name in Stats.Names do
		local v = data.Stats[name] or 0
		if v < lowest then
			weakest, lowest = name, v
		end
	end
	return weakest
end
local function friendBonus(player: Player)
	local data = PlayerData.data(player)
	local today = Daily.today(os.time())
	if not data or data.FriendBonusDay == today then
		return
	end
	data.FriendBonusDay = today
	local stat = weakestStat(data)
	PlayerData.add(player, stat, FRIEND_BONUS)
	fx:FireClient(player, "Match", "PLAYING WITH A FRIEND: +" .. FRIEND_BONUS .. " " .. string.upper(stat))
end
local function checkFriends(player: Player)
	for _, other in game:GetService("Players"):GetPlayers() do
		if other ~= player then
			local ok, friends = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and friends then
				friendBonus(player)
				friendBonus(other)
				return
			end
		end
	end
end

function CareerServer.joined(player: Player)
	task.delay(6, checkFriends, player)
	local data = PlayerData.data(player)
	if not data then
		return
	end
	if data.Quest.Step == 1 and data.Quest.Count == 0 then
		funnel(player, 1, "Joined")
	end
	-- the daily streak: first login of the (utc) day pays out on your weakest stat
	local today = Daily.today(os.time())
	local streak = Daily.next(data.Daily.Last, data.Daily.Streak, today)
	if streak then
		data.Daily.Last, data.Daily.Streak = today, streak
		local weakest = weakestStat(data)
		local amount = Daily.reward(streak) + (if Shop.owns(player, "VIP") then ShopData.VIPDailyBonus else 0)
		PlayerData.add(player, weakest, amount)
		-- a beat late so the client's listening by then
		task.delay(4, function()
			if player.Parent then
				fx:FireClient(player, "Daily", streak, weakest, amount, amount - Daily.reward(streak) + Daily.reward(streak + 1))
			end
		end)
	end
	player:SetAttribute("DailyStreak", data.Daily.Streak)
	if data.RankPoints > 0 then
		Leaderboard.record(player, data.RankPoints)
	end
end

function CareerServer.show(player: Player)
	local data = PlayerData.data(player)
	if not data then
		return
	end
	local record = data.Record
	local rank = Career.rankOf(data.RankPoints)
	for key, value in record :: { [string]: number } do
		player:SetAttribute(key, value)
	end
	player:SetAttribute("RankPoints", data.RankPoints)
	player:SetAttribute("Rank", rank)
	player:SetAttribute("QuestStep", data.Quest.Step)
	player:SetAttribute("QuestCount", data.Quest.Count)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		stats = folder
		local rankValue = Instance.new("StringValue")
		rankValue.Name = "Rank"
		rankValue.Parent = folder
		local winsValue = Instance.new("IntValue")
		winsValue.Name = "Wins"
		winsValue.Parent = folder
		folder.Parent = player
	end
	if stats then
		(stats:FindFirstChild("Rank") :: StringValue).Value = rank;
		(stats:FindFirstChild("Wins") :: IntValue).Value = record.Wins
	end
end

-- still working through the quest line
function CareerServer.onQuests(player: Player): boolean
	local data = PlayerData.data(player)
	return data ~= nil and Career.Quests[data.Quest.Step] ~= nil
end

-- something happened that might count toward the current quest
function CareerServer.event(player: Player, event: string, detail: string?)
	local data = PlayerData.data(player)
	local quest = data and Career.Quests[data.Quest.Step]
	if not (data and quest) or quest.Event ~= event or (quest.For and quest.For ~= detail) then
		return
	end
	data.Quest.Count += 1
	if data.Quest.Count >= quest.Need then
		funnel(player, data.Quest.Step + 1, "Quest " .. data.Quest.Step .. ": " .. quest.Text)
		data.Quest.Step += 1
		data.Quest.Count = 0
		PlayerData.add(player, quest.Reward.Stat, quest.Reward.Amount)
		tell(player, "QUEST DONE")
	end
	CareerServer.show(player)
end

-- after a ring match. result is "Win", "Loss" or "Draw". share scales the rank points (a fight
-- against the AI is worth less). gives back the rank points it changed
function CareerServer.matchResult(player: Player, result: string, ko: boolean, share: number?): number
	local data = PlayerData.data(player)
	if not data then
		return 0
	end
	local record = data.Record
	local before = Career.rankOf(data.RankPoints)
	local points = 0
	if result == "Win" then
		record.Wins += 1
		points = Career.Points.Win + (if ko then Career.Points.KO else 0)
		if ko then
			record.KOs += 1
		end
	elseif result == "Loss" then
		record.Losses += 1
		points = Career.Points.Loss
	else
		record.Draws += 1
		points = Career.Points.Draw
	end
	points = math.round(points * (share or 1))
	data.RankPoints = math.max(0, data.RankPoints + points)
	CareerServer.show(player)
	CareerServer.event(player, "Match")
	if result == "Win" then
		CareerServer.event(player, "Win")
		if ko then
			CareerServer.event(player, "KO")
		end
	end
	PlayerData.save(player)
	Leaderboard.record(player, data.RankPoints)
	local after = Career.rankOf(data.RankPoints)
	if after ~= before then
		task.delay(2, function()
			tell(player, (if points > 0 then "RANK UP: " else "RANK DOWN: ") .. after)
		end)
	end
	return points
end

return CareerServer
