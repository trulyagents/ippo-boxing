--!strict
-- The corner between rounds (StarterGui.MatchCorner, built in studio): how the round went,
-- who's ahead, what the cutman patched up, and the clock to the next bell.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchCorner") :: ScreenGui
local root = gui:WaitForChild("Root") :: Frame
local card = root:WaitForChild("Card") :: ImageLabel
local clock = card:WaitForChild("Clock") :: TextLabel

local SIDE = { Red = Color3.fromRGB(220, 30, 30), Blue = Color3.fromRGB(30, 110, 230) }
local IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HOME = card.Position
local AWAY = HOME - UDim2.fromScale(0.5, 0)

local function text(parent: Instance, name: string): TextLabel
	return parent:WaitForChild(name) :: TextLabel
end

local token = 0
fx.OnClientEvent:Connect(function(kind, info)
	if kind ~= "Corner" or typeof(info) ~= "table" then
		return
	end
	token += 1
	local mine = token
	text(card, "Title").Text = "END OF ROUND " .. tostring(info.Round)
	local color = SIDE[info.Side] or SIDE.Red;
	(card:WaitForChild("Stripe") :: Frame).BackgroundColor3 = color
	clock.TextColor3 = color
	for _, key in { "Hits", "Damage", "Downs" } do
		local row = card:WaitForChild(key)
		text(row, "You").Text = tostring(math.floor((info.You and info.You[key] or 0) + 0.5))
		text(row, "Them").Text = tostring(math.floor((info.Them and info.Them[key] or 0) + 0.5))
	end
	local lead = tonumber(info.Lead) or 0
	text(card:WaitForChild("Verdict"), "Text").Text = if lead > 0
		then "YOU'RE AHEAD ON THE CARDS"
		elseif lead < 0 then "YOU'RE BEHIND, GO GET IT BACK"
		else "DEAD EVEN"
	local healed = tonumber(info.Healed) or 0
	text(card, "Heal").Text = (if healed > 0 then "CUTMAN: +" .. healed .. " HEALTH   " else "") .. "WIND AND GUARD BACK"

	card.Position = AWAY
	root.Visible = true
	TweenService:Create(card, IN, { Position = HOME }):Play()
	local endsAt = tonumber(info.EndsAt) or 0
	while mine == token do
		local left = endsAt - workspace:GetServerTimeNow()
		clock.Text = tostring(math.max(0, math.ceil(left)))
		if left <= 0.4 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if mine ~= token then
		return
	end
	TweenService:Create(card, OUT, { Position = AWAY }):Play()
	task.delay(0.3, function()
		if mine == token then
			root.Visible = false
		end
	end)
end)
