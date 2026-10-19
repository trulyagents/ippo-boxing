--!strict
-- Fight record, rank points and the quest line, saved in the player's profile. Everything is
-- also put on the player as attributes (Wins, Rank, QuestStep...) for the menu, and Wins and
-- Rank go in leaderstats so they show in the player list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Career = require(ReplicatedStorage.Shared.Career)
local PlayerData = require(script.Parent.PlayerData)

-- looked up when needed, CombatServer makes the remotes after the modules load
local function tell(player: Player, text: string)
	local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
	fx:FireClient(player, "Match", text)
end

local CareerServer = {}

function CareerServer.show(player: Player)
	local data = PlayerData.data(player)
	if not data then
		return
	end
	local record = data.Record
	local rank = Career.rankOf(data.RankPoints)
	for key, value in record do
		player:SetAttribute(key, value)
	end
	player:SetAttribute("RankPoints", data.RankPoints)
	player:SetAttribute("Rank", rank)
	player:SetAttribute("QuestStep", data.Quest.Step)
	player:SetAttribute("QuestCount", data.Quest.Count)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		Instance.new("StringValue", stats).Name = "Rank"
		Instance.new("IntValue", stats).Name = "Wins"
		stats.Parent = player
	end
	(stats:FindFirstChild("Rank") :: StringValue).Value = rank;
	(stats:FindFirstChild("Wins") :: IntValue).Value = record.Wins
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
		data.Quest.Step += 1
		data.Quest.Count = 0
		PlayerData.add(player, quest.Reward.Stat, quest.Reward.Amount)
		tell(player, "QUEST DONE")
	end
	CareerServer.show(player)
end

-- after a ring match. result is "Win", "Loss" or "Draw". gives back the rank points it changed
function CareerServer.matchResult(player: Player, result: string, ko: boolean): number
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
	local after = Career.rankOf(data.RankPoints)
	if after ~= before then
		task.delay(2, function()
			tell(player, (if points > 0 then "RANK UP: " else "RANK DOWN: ") .. after)
		end)
	end
	return points
end

return CareerServer
