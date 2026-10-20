--!strict
-- Passes and products (ids in Shared.Shop). Ownership is asked from roblox and cached per player,
-- and put on the player as attributes (VIP, KOEffect, GloveColors) for clients to show. The Stat
-- Respec product goes through ProcessReceipt: receipt ids are kept in the profile so a retried
-- receipt never pays out twice. The Shop remote does the rest:
--   Shop:FireServer("Glove", "Blue")     wear a glove color (needs the pass, Red is free)
--   Shop:FireServer("Spend", "Power")    put 1 point from the respec pool into a stat
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopData = require(ReplicatedStorage.Shared.Shop)
local Stats = require(ReplicatedStorage.Shared.Stats)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Gear = require(script.Parent.Gear)

local Shop = {}

local owned: { [Player]: { [string]: boolean } } = {}

-- yields the first time for each pass, cached after that
function Shop.owns(player: Player, pass: string): boolean
	local mine = owned[player]
	if not mine then
		mine = {}
		owned[player] = mine
	end
	if mine[pass] == nil then
		local id = ShopData.Passes[pass]
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		-- a failed check isn't cached, so the next ask tries again. someone who left while it
		-- was checking doesn't get put back in the cache (that would hold on to them)
		if not ok or player.Parent ~= Players then
			return ok and has == true
		end
		mine[pass] = has == true
		player:SetAttribute(pass, mine[pass])
	end
	return mine[pass] == true
end

-- the glove color you'll box in: yours if you own the pass, red otherwise
function Shop.gloveColor(player: Player): Color3?
	local data = PlayerData.data(player)
	local pick = data and ShopData.glove(data.Glove)
	if pick and (pick.Name == "Red" or Shop.owns(player, "GloveColors")) then
		return pick.Color
	end
	return nil
end

local function wearGloves(player: Player)
	local character = player.Character
	if character then
		Gear.gloves(character, Shop.gloveColor(player))
	end
end

-- check every pass on join so the attributes are there for the ui
function Shop.joined(player: Player)
	local data = PlayerData.data(player)
	player:SetAttribute("StatPool", data and data.StatPool or 0)
	player:SetAttribute("Glove", data and data.Glove or "Red")
	for pass in ShopData.Passes do
		task.spawn(Shop.owns, player, pass)
	end
end

-- what a finished purchase does (and the QA Pass cheat)
function Shop.grant(player: Player, pass: string)
	if not ShopData.Passes[pass] then
		return
	end
	local mine = owned[player] or {}
	owned[player] = mine
	mine[pass] = true
	player:SetAttribute(pass, true)
	if pass == "GloveColors" then
		wearGloves(player)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, bought)
	if not bought then
		return
	end
	for pass, passId in ShopData.Passes do
		if passId == id then
			Shop.grant(player, pass)
		end
	end
end)

-- the respec: every trained point goes into a pool you spend again on the stats tab
local MAX_RECEIPTS = 50
function Shop.receipt(info: { PlayerId: number, ProductId: number, PurchaseId: string }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and PlayerData.data(player)
	-- not loaded (or not here): roblox asks again later, nothing is lost
	if not (player and data) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.Receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if info.ProductId == ShopData.Products.StatRespec then
		local pool = 0
		for _, name in Stats.Names do
			pool += data.Stats[name] or 0
			PlayerData.set(player, name, 0)
		end
		data.StatPool += pool
		player:SetAttribute("StatPool", data.StatPool)
	else
		warn("[Shop] no handler for product " .. tostring(info.ProductId) .. ", roblox will keep retrying it")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, info.PurchaseId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	-- only tell roblox it's done once the save with this receipt has really landed. if it hasn't,
	-- roblox asks again later and the receipt id above stops it paying out twice
	if not PlayerData.saveReceipt(player, info.PurchaseId, 20) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
MarketplaceService.ProcessReceipt = function(info)
	return Shop.receipt(info)
end

-- a few shop clicks a second is plenty, and a glove swap rebuilds the gloves on the server
local RATE, BURST = 4, 6
local buckets: { [Player]: { tokens: number, time: number } } = {}
local function allow(player: Player): boolean
	local now = os.clock()
	local b = buckets[player] or { tokens = BURST, time = now }
	buckets[player] = b
	b.tokens = math.min(BURST, b.tokens + (now - b.time) * RATE)
	b.time = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

Remotes.Shop.OnServerEvent:Connect(function(player, kind, value)
	if not allow(player) then
		return
	end
	local data = PlayerData.data(player)
	if not data or typeof(value) ~= "string" then
		return
	end
	if kind == "Glove" then
		local pick = ShopData.glove(value)
		if pick and (pick.Name == "Red" or Shop.owns(player, "GloveColors")) then
			data.Glove = pick.Name
			player:SetAttribute("Glove", pick.Name)
			wearGloves(player)
		end
	elseif kind == "Spend" and Stats.MaxBonus[value] and data.StatPool > 0 then
		local have = data.Stats[value] or 0
		local amount = math.min(1, data.StatPool, Stats.Cap - have)
		if amount > 0 then
			data.StatPool -= amount
			PlayerData.set(player, value, have + amount)
			player:SetAttribute("StatPool", data.StatPool)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	owned[player] = nil
	buckets[player] = nil
end)

return Shop
