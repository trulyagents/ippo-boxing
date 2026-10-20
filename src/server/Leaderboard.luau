--!strict
-- The ranked board on the gym wall (Workspace.Map.Gym.RankBoard, built in studio): the top 10 by
-- rank points from an OrderedDataStore. Points get written after every match and on join (so
-- people who ranked before the board existed show up), the board refreshes every couple of
-- minutes. Studio uses its own store so test points never reach the real board.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Career = require(ReplicatedStorage.Shared.Career)
local ShopData = require(ReplicatedStorage.Shared.Shop)
local MarketplaceService = game:GetService("MarketplaceService")

local SHOWN = 10
local REFRESH = 120
local store = DataStoreService:GetOrderedDataStore(if RunService:IsStudio() then "RankPointsStudio" else "RankPoints")

local Leaderboard = {}

-- display names for the ids on the board, kept so a refresh doesn't look them all up again
local names: { [number]: string } = {}
local function lookUp(ids: { number })
	local missing = {}
	for _, id in ids do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

-- VIPs get a gold name. works for people who aren't in the server, cached like the names
local vips: { [number]: boolean } = {}
local function isVIP(id: number): boolean
	if vips[id] == nil then
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(id, ShopData.Passes.VIP)
		end)
		if not ok then
			return false
		end
		vips[id] = has == true
	end
	return vips[id]
end

local board = workspace:WaitForChild("Map"):WaitForChild("Gym"):WaitForChild("RankBoard")
local list = board:WaitForChild("Gui"):WaitForChild("List")
local template = list:WaitForChild("Row") :: Frame
local empty = list:WaitForChild("Empty") :: TextLabel

local draw: () -> ()
local busy = false
local function refresh()
	-- two refreshes at once would both clear and both draw, doubling every row
	if busy then
		return
	end
	busy = true
	local ok, err = pcall(function()
		draw()
	end)
	busy = false
	if not ok then
		warn("[Leaderboard] refresh failed: " .. tostring(err))
	end
end

draw = function()
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, SHOWN, 1) -- nobody with 0 points
	end)
	if not ok then
		warn("[Leaderboard] couldn't read the board: " .. tostring(pages))
		return
	end
	local entries = (pages :: DataStorePages):GetCurrentPage()
	local ids = {}
	for _, e in entries do
		table.insert(ids, tonumber(e.key) :: number)
	end
	lookUp(ids)
	for _, old in list:GetChildren() do
		if old.Name == "Entry" then
			old:Destroy()
		end
	end
	for i, e in entries do
		local row = template:Clone()
		row.Name = "Entry"
		row.LayoutOrder = i
		row.Visible = true;
		(row:WaitForChild("Place") :: TextLabel).Text = "#" .. i;
		local nameLabel = row:WaitForChild("Name") :: TextLabel
		nameLabel.Text = string.upper(names[ids[i]] or "?")
		if isVIP(ids[i]) then
			nameLabel.TextColor3 = Color3.fromRGB(196, 140, 20)
		end;
		(row:WaitForChild("Rank") :: TextLabel).Text = (Career.rankOf(e.value));
		(row:WaitForChild("Points") :: TextLabel).Text = tostring(e.value)
		row.Parent = list
	end
	empty.Visible = #entries == 0
end

local soon = false
-- doesn't yield the caller. shortcut: one write per call, fine at one per match per player
function Leaderboard.record(player: Player, points: number)
	local key, value = tostring(player.UserId), math.max(0, math.floor(points))
	task.spawn(function()
		local ok, err = pcall(function()
			return store:SetAsync(key, value)
		end)
		if not ok then
			warn("[Leaderboard] couldn't save points: " .. tostring(err))
		elseif not soon then
			-- show it shortly instead of at the next refresh. the sorted list lags a write by a few seconds
			soon = true
			task.delay(10, function()
				soon = false
				refresh()
			end)
		end
	end)
end

task.spawn(function()
	while true do
		refresh()
		task.wait(REFRESH)
	end
end)

return Leaderboard
